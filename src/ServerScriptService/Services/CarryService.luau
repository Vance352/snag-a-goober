--[[
	CarryService - a player carrying a Goober above their head.

	carry = { uid, id, source = "belt" | "steal", model, price, victim?, ... }

	* Belt Goobers are already paid for. Walking into your own base places
	  them. If you die or leave while carrying one, it is placed at home for you
	  (a stand was reserved when you snagged it).
	* Stolen Goobers are handled by StealService (catch / timeout / success).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)

local CarryService = {}
local S

function CarryService.Init(registry)
	S = registry
end

function CarryService.Begin(player: Player, carry)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	local hrp0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	carry.startT = os.clock()
	carry.startPos = if hrp0 then hrp0.Position else Vector3.zero
	-- the real start, kept even when a shortcut restarts the walk clock: a
	-- carry can never finish sooner than walking from here
	carry.origT, carry.origPos = carry.startT, carry.startPos
	st.carry = carry
	S.Model.SetMode(carry.model, "carried")
	carry.model:SetAttribute("CarriedBy", player.UserId)
	local char = player.Character
	if not char or not S.Model.AttachTo(carry.model, char) then
		-- no character: settle immediately so nothing is lost
		CarryService.Settle(player, "nocharacter")
		return
	end
	player:SetAttribute("Carrying", carry.id)
	player:SetAttribute("CarryingStolen", carry.source == "steal")
	S.Character.ApplySpeed(player)
	S.Character.RefreshTag(player)
	S.Session.MarkDirty(player)
end

local function clear(player: Player)
	local st = S.Session.Get(player)
	if st then
		st.carry = nil
	end
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryingStolen", nil)
	if player.Parent then
		S.Character.ApplySpeed(player)
		S.Character.RefreshTag(player)
	end
	S.Session.MarkDirty(player)
end
CarryService._clear = clear

-- Put a carried belt Goober on a stand at home.
function CarryService.PlaceHome(player: Player)
	local st = S.Session.Get(player)
	local carry = st and st.carry
	if not carry or carry.source ~= "belt" then
		return false
	end
	carry.model:Destroy()
	clear(player)
	local uid = S.Base.Place(player, carry.id, { uid = carry.uid, paid = carry.price })
	if not uid then
		-- should not happen (slot reserved at snag); refund rather than lose it
		S.Session.AddCoins(player, carry.price)
		S.Session.Toast(player, "No free stand - refunded your coins.", "red")
		return false
	end
	local def = GooberData.ById[carry.id]
	-- snag XP is paid when the Goober actually lands at home (not on snag, so
	-- snag-and-drop can't farm XP)
	S.Session.AddXP(player, Config.Rarities[def.rarity].xp)
	S.Session.Effect("PlaceFx", { id = carry.id, rarity = def.rarity }, player)
	S.Hooks.Fire("placed", player, { id = carry.id, source = "belt" })
	return true
end

-- Something interrupted the carry (death, leaving, no character).
function CarryService.Settle(player: Player, reason: string)
	local st = S.Session.Get(player)
	local carry = st and st.carry
	if not carry then
		return
	end
	if carry.source == "belt" then
		local plot = S.Plot.Get(player)
		local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart
		local walk = if spawn and carry.startPos
			then (Vector3.new(carry.startPos.X, 0, carry.startPos.Z) - Vector3.new(spawn.Position.X, 0, spawn.Position.Z)).Magnitude / S.MoveGuard.MaxSpeed(player)
			else 0
		local remaining = walk - (os.clock() - carry.startT)
		if reason ~= "left" and remaining > 0.5 then
			-- resetting must not skip the walk: the Goober walks home on its own,
			-- arriving no sooner than you could have carried it (its stand stays reserved)
			st.pendingHome = st.pendingHome or {}
			table.insert(st.pendingHome, { uid = carry.uid, id = carry.id, price = carry.price, at = os.clock() + remaining })
			carry.model:Destroy()
			clear(player)
			S.Session.Toast(player, ("Your Goober is waddling home on its own (%ds)"):format(math.ceil(remaining)), "green")
		else
			CarryService.PlaceHome(player)
		end
	else
		S.Steal.Fail(player, reason)
	end
end

function CarryService.Drop(player: Player)
	if not S.Session.RateOk(player, "Drop", 2, 1) then
		return
	end
	local st = S.Session.Get(player)
	local carry = st and st.carry
	if not carry then
		return
	end
	if carry.source == "belt" then
		-- dropping a paid Goober sells it back at the usual refund
		local refund = math.floor(carry.price * Config.SellRefund)
		carry.model:Destroy()
		clear(player)
		S.Session.AddCoins(player, refund)
		S.Session.Toast(player, ("Released it back into the wild (+$%s)"):format(Util.Short(refund)), "gold")
	else
		S.Steal.Fail(player, "dropped")
	end
end

function CarryService.Start()
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, st in pairs(S.Session.All()) do
				local carry = st.carry
				if carry and carry.source == "belt" then
					local plot = S.Plot.Get(player)
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
					local ok, from = S.MoveGuard.CarryStep(player, carry)
					if not ok then
						-- shortcut detected: the walking clock restarts from the
						-- last trusted spot, so a teleport home is never faster
						-- than walking
						if from then
							carry.startPos = from.pos
							carry.startT = from.t
						else
							carry.startT = os.clock()
						end
						carry.trail = nil
						if os.clock() - (carry.warnedAt or -100) > 5 then
							carry.warnedAt = os.clock()
							S.Session.Toast(player, "No shortcuts! Walk your Goober home.", "red")
						end
					end
					if
						plot
						and hrp
						and S.Plot.Inside(plot, hrp.Position)
						and not S.MoveGuard.Settling(player)
						-- you can't get home faster than you can walk there
						and os.clock() - carry.startT >= S.MoveGuard.MinTravelTime(player, carry.startPos, hrp.Position)
						and os.clock() - carry.origT >= S.MoveGuard.MinTravelTime(player, carry.origPos, hrp.Position)
					then
						CarryService.PlaceHome(player)
					elseif carry.model.Parent == nil then
						-- the model vanished (character reset mid-frame etc.)
						CarryService.Settle(player, "lost")
					end
				end
				-- Goobers walking home on their own
				if st.pendingHome and #st.pendingHome > 0 then
					for i = #st.pendingHome, 1, -1 do
						local p = st.pendingHome[i]
						if os.clock() >= p.at then
							table.remove(st.pendingHome, i)
							CarryService.LandPending(player, p)
						end
					end
				end
			end
		end
	end)
end

function CarryService.LandPending(player: Player, p)
	local uid = S.Base.Place(player, p.id, { uid = p.uid, paid = p.price })
	if not uid then
		S.Session.AddCoins(player, p.price)
		S.Session.Toast(player, "No free stand - refunded your coins.", "red")
		return
	end
	local def = GooberData.ById[p.id]
	S.Session.AddXP(player, Config.Rarities[def.rarity].xp)
	S.Session.Toast(player, def.name .. " made it home!", "green")
	-- it was a belt snag that waddled home: same Event XP / quest credit as walking it
	S.Hooks.Fire("placed", player, { id = p.id, source = "belt" })
end

-- called by DataService right before the final save
function CarryService.OnRemoving(player: Player)
	local st = S.Session.Get(player)
	if st and st.carry then
		CarryService.Settle(player, "left")
	end
	-- anything still walking home lands now so it is saved
	if st and st.pendingHome then
		for _, p in ipairs(st.pendingHome) do
			CarryService.LandPending(player, p)
		end
		st.pendingHome = nil
	end
end

return CarryService

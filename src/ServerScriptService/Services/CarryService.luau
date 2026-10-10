--[[
	CarryService - a player carrying a Goober above their head.

	carry = { uid, id, source = "belt" | "steal", model, price, line?, victim?,
	          takenFrom? (knocked loose from that player), recovered?, ... }

	* "belt" = a Goober from the Goober Breach (the source name predates the
	  Breach). It's already paid for; walking into your own base places it.
	  If you're blasted or your character dies, it drops where you were and
	  anyone can grab it (BreachService). If you leave, it lands at home.
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
	carry.lastPos = carry.startPos
	-- a moment's grace right after the snag (nobody can blast it out of your hands instantly)
	carry.protectUntil = os.clock() + Config.Combat.snagGrace
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

-- Put a carried belt Goober on a stand at home. (credit = false: it was put
-- there for safekeeping, not delivered, so no stats/XP)
function CarryService.PlaceHome(player: Player, credit: boolean?)
	credit = credit ~= false
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
		S.Session.AddCoins(player, carry.price, true)
		S.Session.Toast(player, "No free stand - refunded your coins.", "red")
		return false
	end
	local def = GooberData.ById[carry.id]
	if not credit then
		return true
	end
	-- snag XP is paid when the Goober actually lands at home (not on snag, so
	-- snag-and-drop can't farm XP)
	S.Session.AddXP(player, Config.Rarities[def.rarity].xp)
	S.Session.Effect("PlaceFx", { id = carry.id, rarity = def.rarity, delivered = true }, player)
	st.data.stats.delivered += 1
	if carry.takenFrom then
		-- knocked loose from someone else and brought home: a real combat steal.
		-- It only counts once per Config.Combat.stealCredit per pair of players,
		-- so two friends can't farm Master Thieves by passing a Blorp back and
		-- forth (kept in the thief's save, so switching servers doesn't reset it)
		local credit = st.data.stealCredit
		local key = tostring(carry.takenFrom)
		if os.time() >= (credit[key] or 0) then
			credit[key] = os.time() + Config.Combat.stealCredit
			st.data.stats.combatSteals += 1
			S.Hooks.Fire("stolen", player, { id = carry.id, combat = true })
		end
		local from = Players:GetPlayerByUserId(carry.takenFrom)
		if from then
			S.Session.Notify(from, "GooberLost", { id = carry.id, by = player.DisplayName })
		end
	elseif carry.recovered then
		st.data.stats.recovered += 1
	end
	S.Hooks.Fire("placed", player, { id = carry.id, source = "belt" })
	S.Leaderboard.MarkDirty(player)
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
		-- (a real disconnect removes the character before this runs: use the
		-- last position the carry loop saw)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
		local pos = if hrp then hrp.Position else carry.lastPos
		local plot = S.Plot.Get(player)
		local atHome = pos ~= nil and plot ~= nil and S.Plot.Inside(plot, pos)
		if reason == "died" or reason == "lost" or (reason == "left" and not atHome and pos) then
			-- falling over (or resetting) drops it where you were: anyone can grab it,
			-- and if nobody does it waddles home to you (so a reset never escapes a chase).
			-- Leaving drops it too (for anyone to grab; nothing is refunded).
			S.Breach.DropFromCarry(player, nil, reason)
		else
			-- shutting down / no character / already standing at home
			CarryService.PlaceHome(player, reason ~= "left" and reason ~= "shutdown")
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
		S.Session.AddCoins(player, refund, true)
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
					if hrp then
						carry.lastPos = hrp.Position
					end
					local ok, from, excess = S.MoveGuard.CarryStep(player, carry)
					if not ok then
						-- shortcut detected. A real jump (well beyond lag) is pulled
						-- back to the last trusted spot - a teleport home must never
						-- skip the chase (your own base is blast-proof). Either way
						-- the walking clock restarts from there, so a shortcut home
						-- is never faster than walking.
						if from and (excess or 0) > 8 and hrp then
							local origPos, origT = carry.origPos, carry.origT
							S.MoveGuard.ServerMove(player, CFrame.new(from.pos) * hrp.CFrame.Rotation)
							carry.origPos, carry.origT = origPos, origT -- (ServerMove shifts it; this is the real start)
							carry.lastPos = from.pos
						end
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
		S.Session.AddCoins(player, p.price, true)
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
	local shuttingDown = S.Data.ShuttingDown == true
	if st and st.carry then
		CarryService.Settle(player, if shuttingDown then "shutdown" else "left")
	end
	-- Goobers you dropped (including the one just dropped above) stay in the field
	-- for anyone to grab - or come home if the server is closing
	S.Breach.OnRemoving(player, shuttingDown)

	-- anything still walking home lands now so it is saved
	if st and st.pendingHome then
		for _, p in ipairs(st.pendingHome) do
			CarryService.LandPending(player, p)
		end
		st.pendingHome = nil
	end
end

return CarryService

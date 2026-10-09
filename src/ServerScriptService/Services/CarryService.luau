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
	local uid = S.Base.Place(player, carry.id, { uid = carry.uid })
	if not uid then
		-- should not happen (slot reserved at snag); refund rather than lose it
		S.Session.AddCoins(player, carry.price)
		S.Session.Toast(player, "No free stand - refunded your coins.", "red")
		return false
	end
	local def = GooberData.ById[carry.id]
	S.Session.Effect("PlaceFx", { id = carry.id, rarity = def.rarity }, player)
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
		CarryService.PlaceHome(player)
		if reason == "died" then
			S.Session.Toast(player, "Your Goober ran home without you!", "green")
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
					if plot and hrp and S.Plot.Inside(plot, hrp.Position) then
						CarryService.PlaceHome(player)
					elseif carry.model.Parent == nil then
						-- the model vanished (character reset mid-frame etc.)
						CarryService.Settle(player, "lost")
					end
				end
			end
		end
	end)
end

-- called by DataService right before the final save
function CarryService.OnRemoving(player: Player)
	local st = S.Session.Get(player)
	if st and st.carry then
		CarryService.Settle(player, "left")
	end
end

return CarryService

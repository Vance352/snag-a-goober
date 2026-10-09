--[[
	ProgressService - upgrades, rebirth, the Goober-dex and tutorial progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

local ProgressService = {}
local S

function ProgressService.Init(registry)
	S = registry
end

-- ------------------------------------------------------------- tutorial
function ProgressService.TutorialEvent(player: Player, event: string)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	local step = st.data.tutorial
	if Tutorial.Advance[step] == event then
		st.data.tutorial = step + 1
		S.Session.MarkDirty(player)
		S.Session.Notify(player, "TutorialStep", { step = st.data.tutorial })
	end
end

function ProgressService.TutorialAck(player: Player, step: any)
	local st = S.Session.Get(player)
	if st and st.data.tutorial == Tutorial.Tips and step == Tutorial.Tips then
		st.data.tutorial = Tutorial.DONE
		S.Session.MarkDirty(player)
	end
end

function ProgressService.TutorialSkip(player: Player)
	local st = S.Session.Get(player)
	if st and st.data.tutorial ~= Tutorial.DONE then
		st.data.tutorial = Tutorial.DONE
		S.Session.MarkDirty(player)
	end
end

-- ----------------------------------------------------------------- dex
-- Goobers discovered in one pool ("Classic" by default: the Classic Index
-- milestones; the Halloween collection has its own rewards)
local function discoveredCount(dex, pool: string?): number
	local n = 0
	for gid in pairs(dex) do
		local def = GooberData.ById[gid]
		if def and (def.pool or "Classic") == (pool or "Classic") then
			n += 1
		end
	end
	return n
end
ProgressService.DiscoveredCount = discoveredCount

function ProgressService.Discover(player: Player, gid: string)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	local dex = st.data.dex
	local first = dex[gid] == nil
	dex[gid] = (dex[gid] or 0) + 1
	if not first then
		return
	end
	S.Session.AddXP(player, Config.XP.discovery)
	local pool = GooberData.ById[gid] and GooberData.ById[gid].pool or "Classic"
	S.Session.Notify(player, "Discovered", { id = gid, count = discoveredCount(dex, pool), total = #GooberData.PoolList[pool], pool = pool })
	if pool ~= "Classic" then
		S.Session.MarkDirty(player)
		return
	end
	local count = discoveredCount(dex)
	for _, m in ipairs(Config.DexMilestones) do
		local key = tostring(m.count)
		if count >= m.count and not st.data.dexClaimed[key] then
			st.data.dexClaimed[key] = true
			S.Session.AddCoins(player, m.coins)
			st.data.title = m.title
			player:SetAttribute("Title", m.title)
			S.Session.Notify(player, "DexMilestone", { count = m.count, coins = m.coins, title = m.title })
			if S.Character then
				S.Character.RefreshTag(player)
			end
		end
	end
	S.Session.MarkDirty(player)
end

-- ------------------------------------------------------------- upgrades
function ProgressService.BuyUpgrade(player: Player, key: any)
	if type(key) ~= "string" or not S.Session.RateOk(player, "Upgrade", 6, 1) then
		return
	end
	local st = S.Session.Get(player)
	local def = Util.UpgradeByKey(key)
	if not st or not st.ready or not def then
		return
	end
	local lvl = st.data.upgrades[key]
	if lvl >= def.max then
		return S.Session.Notify(player, "Error", { text = def.name .. " is maxed out!" })
	end
	if key == "Lock" and st.data.level < Config.LockLevel then
		return S.Session.Notify(player, "Error", { text = ("Base Lock upgrades unlock at Level %d."):format(Config.LockLevel) })
	end
	local cost = Util.UpgradeCost(def, lvl)
	if not S.Session.Spend(player, cost) then
		return S.Session.Notify(player, "Error", { text = ("You need $%s for %s."):format(Util.Short(cost), def.name) })
	end
	st.data.upgrades[key] = lvl + 1
	if key == "Speed" then
		S.Character.ApplySpeed(player)
	elseif key == "Slots" then
		S.Base.RefreshStands(player)
	elseif key == "Income" then
		S.Session.ComputeRate(player)
	end
	S.Session.AddXP(player, Config.XP.upgrade)
	S.Session.Notify(player, "Upgraded", { key = key, level = lvl + 1, name = def.name })
	S.Session.MarkDirty(player)
	ProgressService.TutorialEvent(player, "Upgraded")
end

-- -------------------------------------------------------------- rebirth
function ProgressService.CanRebirth(player: Player): (boolean, string?)
	local st = S.Session.Get(player)
	if not st then
		return false
	end
	local d = st.data
	if d.rebirths >= Config.Rebirth.max then
		return false, "You've reached max rebirths!"
	end
	if d.level < Config.RebirthLevel(d.rebirths) then
		return false, ("Reach Level %d to rebirth."):format(Config.RebirthLevel(d.rebirths))
	end
	local cost = Config.RebirthCost(d.rebirths)
	if d.coins < cost then
		return false, ("You need $%s to rebirth."):format(Util.Short(cost))
	end
	if st.carry then
		return false, "Put down your Goober first."
	end
	return true
end

function ProgressService.Rebirth(player: Player, confirmed: any)
	-- the client sends `true` only after the player tapped the button twice
	if confirmed ~= true or not S.Session.RateOk(player, "Rebirth", 1, 2) then
		return
	end
	local ok, reason = ProgressService.CanRebirth(player)
	if not ok then
		if reason then
			S.Session.Notify(player, "Error", { text = reason })
		end
		return
	end
	local st = S.Session.Get(player)
	local d = st.data
	d.rebirths += 1
	d.coins = Config.Rebirth.startCoins
	d.bank = 0
	for _, def in ipairs(Config.Upgrades) do
		if def.resetsOnRebirth then
			d.upgrades[def.key] = 0
		end
	end
	player:SetAttribute("Rebirths", d.rebirths)
	S.Character.ApplySpeed(player)
	S.Character.RefreshTag(player)
	S.Session.ComputeRate(player)
	S.Base.RefreshStands(player)
	S.Session.MarkDirty(player)
	S.Session.Notify(player, "Reborn", { rebirths = d.rebirths, multiplier = 1 + Config.Rebirth.incomeBonus * d.rebirths })
	S.Session.Effect("RebirthFx", { player = player.UserId })
	task.spawn(S.Data.Save, player, false)
end

return ProgressService

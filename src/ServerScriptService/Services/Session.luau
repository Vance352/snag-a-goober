--[[
	Session - runtime state for each player on this server plus the shared
	economy helpers (spend, earn, XP, income rate) and the State snapshot that is
	pushed to the owning client. Persistent fields live in st.data (DataService);
	everything else here is per-server and resets on rejoin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Session = {}
local S -- service registry

export type State = {
	data: any,
	passes: { [string]: boolean },
	carry: any?,
	lockUntil: number,
	lockReadyAt: number,
	stealCooldownUntil: number,
	pairCooldown: { [number]: number },
	joinGraceUntil: number,
	stunnedUntil: number,
	lastQuote: { [string]: { value: number, t: number } },
	nextDropAt: number,
	rate: number,
	dirty: boolean,
	restrictedRandom: boolean,
	rateLimits: { [string]: { n: number, t: number } },
	ready: boolean,
	inTransit: { [string]: boolean },
}

local states: { [Player]: State } = {}

local StateRemote = Net.Event("State")
local NotifyRemote = Net.Event("Notify")
local EffectRemote = Net.Event("Effect")

function Session.Init(registry)
	S = registry
end

function Session.Create(player: Player, data): State
	local now = os.clock()
	local st: State = {
		data = data,
		passes = {},
		carry = nil,
		lockUntil = 0,
		lockReadyAt = 0,
		stealCooldownUntil = 0,
		pairCooldown = {},
		joinGraceUntil = now + Config.Steal.joinGrace,
		stunnedUntil = 0,
		lastQuote = {},
		nextDropAt = now + 3,
		rate = 0,
		dirty = true,
		restrictedRandom = false,
		rateLimits = {},
		ready = false,
		inTransit = {},
	}
	states[player] = st
	return st
end

function Session.Remove(player: Player)
	states[player] = nil
end

function Session.Get(player: Player): State?
	return states[player]
end

function Session.All(): { [Player]: State }
	return states
end

-- Simple token bucket per action: at most `max` calls per `per` seconds.
function Session.RateOk(player: Player, action: string, max: number, per: number): boolean
	local st = states[player]
	if not st then
		return false
	end
	local now = os.clock()
	local rl = st.rateLimits[action]
	if not rl or now - rl.t >= per then
		st.rateLimits[action] = { n = 1, t = now }
		return true
	end
	if rl.n >= max then
		return false
	end
	rl.n += 1
	return true
end

function Session.HasPass(player: Player, key: string): boolean
	local st = states[player]
	return st ~= nil and st.passes[key] == true
end

function Session.Boosted(st: State): boolean
	return st.data.boostUntil > os.time()
end

function Session.Multiplier(player: Player): number
	local st = states[player]
	if not st then
		return 1
	end
	local d = st.data
	return Util.IncomeMultiplier(d.upgrades.Income, d.rebirths, st.passes.DoubleCoins == true, Session.Boosted(st))
end

-- Coins per second from every placed Goober, with all multipliers.
function Session.ComputeRate(player: Player): number
	local st = states[player]
	if not st then
		return 0
	end
	local base = 0
	for uid, g in pairs(st.data.goobers) do
		if not (st.inTransit and st.inTransit[uid]) then
			local def = GooberData.ById[g.id]
			if def then
				base += def.income
			end
		end
	end
	st.rate = base * Session.Multiplier(player)
	return st.rate
end

function Session.Capacity(player: Player): number
	local st = states[player]
	if not st then
		return 0
	end
	return Util.Capacity(st.data.upgrades.Slots, st.data.rebirths, st.passes.ExtraSlots == true)
end

function Session.Used(player: Player): number
	local st = states[player]
	if not st then
		return 0
	end
	local n = 0
	for _ in pairs(st.data.goobers) do
		n += 1
	end
	if st.carry and st.carry.source == "belt" then
		n += 1
	end
	if st.pendingHome then
		n += #st.pendingHome
	end
	return n
end

function Session.HasFreeSlot(player: Player): boolean
	return Session.Used(player) < Session.Capacity(player)
end

function Session.Spend(player: Player, amount: number): boolean
	local st = states[player]
	if not st or amount < 0 or amount ~= amount then
		return false
	end
	if st.data.coins < amount then
		return false
	end
	st.data.coins -= amount
	st.dirty = true
	return true
end

function Session.AddCoins(player: Player, amount: number)
	local st = states[player]
	if not st or amount <= 0 or amount ~= amount or amount == math.huge then
		return
	end
	st.data.coins += amount
	st.data.totalEarned += amount
	st.dirty = true
end

function Session.XPNeeded(level: number): number
	return Config.XPForLevel(level)
end

function Session.AddXP(player: Player, amount: number)
	local st = states[player]
	if not st or amount <= 0 then
		return
	end
	local d = st.data
	d.xp += amount
	local leveled = false
	while d.xp >= Config.XPForLevel(d.level) do
		d.xp -= Config.XPForLevel(d.level)
		d.level += 1
		leveled = true
		local reward = Config.LevelReward(d.level)
		d.coins += reward
		Session.Notify(player, "LevelUp", {
			level = d.level,
			reward = reward,
			unlock = Config.LevelUnlocks[d.level],
		})
	end
	if leveled then
		player:SetAttribute("Level", d.level)
		if S.Character then
			S.Character.RefreshTag(player)
		end
	end
	st.dirty = true
end

function Session.Notify(player: Player, kind: string, payload: any?)
	NotifyRemote:FireClient(player, kind, payload or {})
end

function Session.Toast(player: Player, text: string, color: string?)
	NotifyRemote:FireClient(player, "Toast", { text = text, color = color })
end

function Session.Effect(kind: string, payload: any, only: Player?)
	if only then
		EffectRemote:FireClient(only, kind, payload)
	else
		EffectRemote:FireAllClients(kind, payload)
	end
end

function Session.MarkDirty(player: Player)
	local st = states[player]
	if st then
		st.dirty = true
	end
end

function Session.Snapshot(player: Player)
	local st = states[player]
	if not st then
		return nil
	end
	local d = st.data
	local now = os.clock()
	local carry = nil
	if st.carry then
		carry = { id = st.carry.id, source = st.carry.source, victim = st.carry.victimName }
	end
	return {
		coins = d.coins,
		bank = d.bank,
		rate = st.rate,
		level = d.level,
		xp = d.xp,
		xpNeeded = Config.XPForLevel(d.level),
		rebirths = d.rebirths,
		rebirthCost = Config.RebirthCost(d.rebirths),
		rebirthLevel = Config.RebirthLevel(d.rebirths),
		upgrades = d.upgrades,
		capacity = Session.Capacity(player),
		used = Session.Used(player),
		dex = d.dex,
		dexClaimed = d.dexClaimed,
		tutorial = d.tutorial,
		passes = st.passes,
		boostLeft = math.max(0, d.boostUntil - os.time()),
		lockLeft = math.max(0, st.lockUntil - now),
		lockReadyIn = math.max(0, st.lockReadyAt - now),
		graceLeft = math.max(0, st.joinGraceUntil - now),
		stealCooldown = math.max(0, st.stealCooldownUntil - now),
		carry = carry,
		pairCooldowns = (function()
			local out = {}
			for victimId, untilT in pairs(st.pairCooldown) do
				if untilT > now then
					out[tostring(victimId)] = math.ceil(untilT - now)
				end
			end
			return out
		end)(),
		multiplier = Session.Multiplier(player),
		personalLuck = Session.PersonalLuck(player),
		nextDropIn = math.max(0, st.nextDropAt - now),
		restrictedRandom = st.restrictedRandom,
		title = d.title,
		settings = d.settings,
		temporary = S.Data.IsTemporary(player),
		stats = d.stats,
	}
end

function Session.PersonalLuck(player: Player): number
	local st = states[player]
	if not st then
		return 1
	end
	local lucky = st.passes.Lucky == true and not st.restrictedRandom
	return Util.PersonalLuck(st.data.rebirths, lucky)
end

function Session.Push(player: Player)
	local snap = Session.Snapshot(player)
	if snap then
		StateRemote:FireClient(player, snap)
	end
end

function Session.Start()
	-- push dirty state ~6 times a second, and everyone once a second (timers)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1 / 6)
			tick += 1
			for player, st in pairs(states) do
				if st.ready and (st.dirty or tick % 6 == 0) then
					st.dirty = false
					Session.Push(player)
				end
			end
		end
	end)
end

return Session

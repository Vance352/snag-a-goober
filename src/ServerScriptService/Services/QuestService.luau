--[[
	QuestService - the Halloween quest chain, daily quests and player-level
	milestone rewards.

	Progress comes only from server Hooks (validated gameplay), never from the
	client. Quests are claimed with a button; a claimed quest/milestone is
	stored in the save, so rejoining can't claim it twice.

	Counting rules:
	  * "candy", "eventlevel" and "area" goals read live saved state (found
	    candies, event level, areas visited), so doing them early still counts.
	  * everything else counts only while the quest is active.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Halloween = require(ReplicatedStorage.Shared.Halloween)

local QuestService = {}
local S

local RANK = {}
for i, r in ipairs(Config.RarityOrder) do
	RANK[r] = i
end

function QuestService.Init(registry)
	S = registry
end

local function today(): number
	return os.time() // 86400
end

local function candyCount(data): number
	local n = 0
	for _ in pairs(data.candyFound) do
		n += 1
	end
	return n
end

-- the day's three dailies: the same for everyone on a UTC day
local function dailyFor(day: number)
	local rng = Random.new(day * 7919 + 17)
	local pool = table.clone(Halloween.DailyPool)
	local out = {}
	for _ = 1, math.min(Halloween.DailyCount, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(out, table.remove(pool, i))
	end
	return out
end

local function dailyDef(id: string)
	for _, q in ipairs(Halloween.DailyPool) do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- make sure today's dailies exist (rolls over at 00:00 UTC)
local function ensureDaily(player: Player)
	local st = S.Session.Get(player)
	local daily = st.data.quests.daily
	local d = today()
	if daily.day ~= d then
		daily.day = d
		daily.list = {}
		for _, q in ipairs(dailyFor(d)) do
			local target = q.n
			if q.scale then -- "collect N minutes of income": fixed when the day starts
				target = math.max(200, math.floor(S.Session.BaseRate(player) * q.scale))
			end
			table.insert(daily.list, { id = q.id, progress = 0, target = target, claimed = false })
		end
		st.dirty = true
	end
	return daily
end

-- does event (kind, payload) advance quest q? returns the amount
local function advance(q, kind: string, p): number
	if q.type == "snag" and kind == "placed" and (p.source == "belt" or p.source == "steal") then
		return 1
	elseif q.type == "halloween" and kind == "placed" and p.source == "belt" then
		local def = GooberData.ById[p.id]
		if def and def.pool == "Halloween" and (not q.rarity or RANK[def.rarity] >= RANK[q.rarity]) then
			return 1
		end
	elseif q.type == "bucket" and kind == "bucket" then
		return 1
	elseif q.type == "collect" and kind == "collected" then
		return p.amount or 0
	elseif q.type == "steal" and kind == "stolen" then
		return 1
	elseif q.type == "area" and kind == "area" and p.key == q.area then
		return 1
	elseif q.type == "visit" and kind == "visit" then
		return 1
	end
	return 0
end

-- current progress of the chain quest (live totals for candy / eventlevel)
local LIVE = { candy = true, eventlevel = true, area = true }

local function chainProgress(st, q): number
	if q.type == "candy" then
		return candyCount(st.data)
	elseif q.type == "eventlevel" then
		return st.data.event.level
	elseif q.type == "area" then
		return if st.data.areasVisited[q.area] then 1 else 0
	end
	return st.data.quests.chainProgress
end

local function onEvent(kind: string)
	return function(player: Player, p)
		local st = S.Session.Get(player)
		if not st then
			return
		end
		local quests = st.data.quests
		local q = Halloween.QuestChain[quests.chain]
		if q then
			local before = chainProgress(st, q)
			if not LIVE[q.type] then
				local n = advance(q, kind, p)
				if n > 0 then
					quests.chainProgress = math.min(q.n, quests.chainProgress + n)
				end
			end
			if before < q.n and chainProgress(st, q) >= q.n then
				S.Session.Notify(player, "QuestDone", { text = q.text })
			end
		end
		local daily = ensureDaily(player)
		for _, entry in ipairs(daily.list) do
			local def = dailyDef(entry.id)
			if def and not entry.claimed and entry.progress < entry.target then
				local n = advance(def, kind, p)
				if n > 0 then
					entry.progress = math.min(entry.target, entry.progress + n)
					if entry.progress >= entry.target then
						S.Session.Notify(player, "QuestDone", { text = def.text })
					end
				end
			end
		end
		st.dirty = true
	end
end

-- kind = "chain" | "daily", index = daily slot (1-3)
function QuestService.Claim(player: Player, kind: any, index: any)
	if not S.Session.RateOk(player, "QuestClaim", 6, 2) then
		return
	end
	local st = S.Session.Get(player)
	local quests = st.data.quests
	if kind == "chain" then
		local q = Halloween.QuestChain[quests.chain]
		if not q or chainProgress(st, q) < q.n then
			return
		end
		quests.chain += 1
		quests.chainProgress = 0
		local lines = S.Event.Grant(player, q.reward, "reward")
		S.Session.Notify(player, "Reward", { title = "QUEST COMPLETE", lines = lines })
		-- the next quest may already be done (e.g. candy found earlier)
		local nq = Halloween.QuestChain[quests.chain]
		if nq and chainProgress(st, nq) >= nq.n then
			S.Session.Notify(player, "QuestDone", { text = nq.text })
		end
	elseif kind == "daily" and type(index) == "number" then
		local daily = ensureDaily(player)
		local entry = daily.list[index]
		local def = entry and dailyDef(entry.id)
		if not entry or not def or entry.claimed or entry.progress < entry.target then
			return
		end
		entry.claimed = true
		local lines = S.Event.Grant(player, def.reward, "reward")
		S.Session.Notify(player, "Reward", { title = "DAILY QUEST", lines = lines })
	end
	st.dirty = true
end

-- --------------------------------------------------- level milestones
function QuestService.ClaimLevel(player: Player, level: any)
	if type(level) ~= "number" or not S.Session.RateOk(player, "LevelClaim", 6, 2) then
		return
	end
	local st = S.Session.Get(player)
	local key = tostring(level)
	for _, m in ipairs(Halloween.LevelMilestones) do
		if m.level == level and st.data.level >= level and not st.data.levelClaimed[key] then
			st.data.levelClaimed[key] = true
			local lines = S.Event.Grant(player, m.reward, "reward")
			S.Session.Notify(player, "Reward", { title = ("LEVEL %d REWARD"):format(level), lines = lines })
			return
		end
	end
end

function QuestService.Snapshot(player: Player)
	local st = S.Session.Get(player)
	local quests = st.data.quests
	local q = Halloween.QuestChain[quests.chain]
	local daily = ensureDaily(player)
	local list = {}
	for i, entry in ipairs(daily.list) do
		local def = dailyDef(entry.id)
		if def then
			list[i] = { text = def.text, progress = entry.progress, target = entry.target, claimed = entry.claimed, reward = def.reward }
		end
	end
	return {
		chainIndex = quests.chain,
		chainTotal = #Halloween.QuestChain,
		chain = if q then { text = q.text, hint = q.hint, progress = math.min(q.n, chainProgress(st, q)), target = q.n, reward = q.reward } else nil,
		daily = list,
		dailyResetIn = 86400 - (os.time() % 86400),
	}
end

function QuestService.Start()
	for _, kind in ipairs({ "placed", "collected", "stolen", "candy", "bucket", "area", "visit", "eventlevel" }) do
		S.Hooks.On(kind, onEvent(kind))
	end
end

return QuestService

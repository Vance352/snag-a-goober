--[[
	LeaderboardService - real global rankings (OrderedDataStores) plus the
	current-server view, shown on the boards in Champions Plaza and in the
	Leaderboard panel.

	* Scores come only from saved, server-side stats (see score()).
	* Writes: a player's scores are written when they change, at most every
	  Leaderboards.WriteEvery seconds, and once more when they leave. UpdateAsync
	  keeps the higher value, so a stale server can never lower a score, and a
	  zero is never written over a real score.
	* Reads: each category's top 10 is fetched every RefreshEvery seconds and
	  cached; clients and boards read the cache (never the data store directly).
	* Failures are logged and shown as "Rankings unavailable" with the last good
	  data kept; nothing is ever replaced with zeros because a request failed.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local LeaderboardService = {}
local S

local PREFIX = if RunService:IsStudio() then "SAG_LB_Studio_v1_" else "SAG_LB_v1_"
local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { entries: { any }, updatedAt: number?, error: string? } } = {}
local written: { [Player]: { [string]: number } } = {}
local lastWrite: { [Player]: number } = {}
local dirty: { [Player]: boolean } = {}
local names: { [number]: { display: string, user: string } } = {}

local RARE = { Epic = true, Legendary = true, Secret = true }

function LeaderboardService.Init(registry)
	S = registry
	for _, c in ipairs(Leaderboards.Categories) do
		cache[c.key] = { entries = {}, updatedAt = nil, error = nil }
	end
end

-- a player's score in a category, from their saved data
local function score(data, key: string): number
	if key == "Earners" then
		return math.floor(data.totalEarned or 0)
	elseif key == "Collected" then
		return data.stats.delivered or 0
	elseif key == "Thieves" then
		return (data.stats.steals or 0) + (data.stats.combatSteals or 0)
	elseif key == "Level" then
		return data.level or 1
	elseif key == "Rare" then
		local n = 0
		for gid in pairs(data.dex) do
			local def = GooberData.ById[gid]
			if def and RARE[def.rarity] then
				n += 1
			end
		end
		return n
	end
	return 0
end
LeaderboardService.Score = score

local function store(key: string): OrderedDataStore?
	if stores[key] then
		return stores[key]
	end
	local ok, ds = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, PREFIX .. key)
	if ok then
		stores[key] = ds
		return ds
	end
	return nil
end

function LeaderboardService.MarkDirty(player: Player)
	dirty[player] = true
end

-- write one player's changed scores (keeps the higher value)
local function writePlayer(player: Player)
	local st = S.Session.Get(player)
	if not st or player.UserId <= 0 or S.Data.IsTemporary(player) then
		return -- test players / unsaved sessions never rank
	end
	written[player] = written[player] or {}
	for _, c in ipairs(Leaderboards.Categories) do
		local v = score(st.data, c.key)
		if v > 0 and v ~= written[player][c.key] then
			local ds = store(c.key)
			if ds then
				local ok, err = pcall(function()
					ds:UpdateAsync(tostring(player.UserId), function(old)
						old = tonumber(old) or 0
						if v <= old then
							return nil -- keep the higher score already there
						end
						return v
					end)
				end)
				if ok then
					written[player][c.key] = v
				else
					warn("[Leaderboard] write failed:", c.key, err)
				end
			end
		end
	end
	lastWrite[player] = os.clock()
	dirty[player] = false
end

local function resolveNames(ids: { number })
	local need = {}
	for _, id in ipairs(ids) do
		if not names[id] then
			table.insert(need, id)
		end
	end
	if #need == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, need)
	if ok and infos then
		for _, info in ipairs(infos) do
			names[info.Id] = { display = info.DisplayName, user = info.Username }
		end
	end
	for _, id in ipairs(need) do
		if not names[id] then
			local ok2, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
			names[id] = { display = if ok2 then n else ("Player " .. id), user = if ok2 then n else "" }
		end
	end
end

local function refresh(key: string)
	local ds = store(key)
	local c = cache[key]
	if not ds then
		c.error = "Rankings unavailable right now"
		return
	end
	local ok, pages = pcall(ds.GetSortedAsync, ds, false, Leaderboards.Size)
	if not ok then
		c.error = "Rankings unavailable right now"
		warn("[Leaderboard] read failed:", key, pages)
		return -- keep the last good entries
	end
	local page = pages:GetCurrentPage()
	local ids = {}
	for _, row in ipairs(page) do
		table.insert(ids, tonumber(row.key))
	end
	resolveNames(ids)
	local entries = {}
	for i, row in ipairs(page) do
		local id = tonumber(row.key)
		local n = names[id] or { display = "?", user = "" }
		entries[i] = { rank = i, userId = id, name = n.display, user = n.user, value = row.value }
	end
	c.entries = entries
	c.updatedAt = os.time()
	c.error = nil
end

-- current-server ranking (live, from loaded sessions)
local function serverBoard(key: string)
	local rows = {}
	for player, st in pairs(S.Session.All()) do
		if st.ready then
			table.insert(rows, { userId = player.UserId, name = player.DisplayName, user = player.Name, value = score(st.data, key) })
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	for i, r in ipairs(rows) do
		r.rank = i
	end
	return rows
end

function LeaderboardService.Get(key: string, scope: string)
	local c = cache[key]
	if not c then
		return nil
	end
	if scope == "server" then
		return { key = key, scope = "server", entries = serverBoard(key), updatedAt = os.time() }
	end
	return { key = key, scope = "global", entries = c.entries, updatedAt = c.updatedAt, error = c.error }
end

-- ------------------------------------------------------- physical boards
local function fmt(key: string, v: number): string
	if Leaderboards.ByKey[key].money then
		return "$" .. Util.Short(v)
	end
	return Util.Comma(v)
end

local function drawBoard(board: Instance)
	local key = board:GetAttribute("Category")
	local gui = board:FindFirstChild("BoardGui", true)
	local c = key and cache[key]
	if not gui or not c then
		return
	end
	local list = gui:FindFirstChild("Rows")
	local status = gui:FindFirstChild("Status", true)
	if status then
		status.Text = if c.error and not c.updatedAt
			then c.error
			elseif c.updatedAt then ("Global top %d  •  updated %s UTC"):format(Leaderboards.Size, os.date("!%H:%M", c.updatedAt))
			else "Loading rankings..."
	end
	if not list then
		return
	end
	for i = 1, Leaderboards.Size do
		local row = list:FindFirstChild("Row" .. i)
		local e = c.entries[i]
		if row then
			row.Visible = e ~= nil
			if e then
				row.Name_.Text = e.name
				row.Value.Text = fmt(key, e.value)
				row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(e.userId)
			end
		end
	end
	local empty = gui:FindFirstChild("Empty", true)
	if empty then
		empty.Visible = #c.entries == 0 and c.updatedAt ~= nil
	end
end

local function drawAll()
	for _, b in ipairs(CollectionService:GetTagged("LeaderboardBoard")) do
		pcall(drawBoard, b)
	end
end

function LeaderboardService.Start()
	-- remote: the panel asks for a category (global or this server)
	local fn = Net.Function("GetLeaderboard")
	fn.OnServerInvoke = function(player, key, scope)
		if type(key) ~= "string" or not Leaderboards.ByKey[key] then
			return nil
		end
		if not S.Session.RateOk(player, "Leaderboard", 6, 2) then
			return nil
		end
		local res = LeaderboardService.Get(key, if scope == "server" then "server" else "global")
		local st = S.Session.Get(player)
		if res and st then
			res.you = score(st.data, key) -- your own score (from your saved stats)
		end
		return res
	end
	-- reads: one category every RefreshEvery / #categories seconds (spread out)
	task.spawn(function()
		task.wait(5)
		for _, c in ipairs(Leaderboards.Categories) do
			refresh(c.key)
		end
		drawAll()
		local i = 0
		local gap = Leaderboards.RefreshEvery / #Leaderboards.Categories
		while true do
			task.wait(gap)
			i = i % #Leaderboards.Categories + 1
			refresh(Leaderboards.Categories[i].key)
			drawAll()
		end
	end)
	-- writes: changed scores, throttled
	task.spawn(function()
		while true do
			task.wait(15)
			for player, st in pairs(S.Session.All()) do
				if st.ready and (dirty[player] or os.clock() - (lastWrite[player] or 0) > Leaderboards.WriteEvery) and os.clock() - (lastWrite[player] or -1e9) > 30 then
					writePlayer(player)
				end
			end
		end
	end)
	-- leaving: write the final scores. DataService calls this before the save, so
	-- it runs in its own thread (it reads the session up to its first yield) and
	-- the save never waits on the OrderedDataStore budget
	S.Data.OnRemoving(function(player)
		task.spawn(function()
			pcall(writePlayer, player)
			written[player] = nil
			lastWrite[player] = nil
			dirty[player] = nil
		end)
	end)
end

return LeaderboardService

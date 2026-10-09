--[[
	DataService - session-locked, versioned player saves.

	* Every save goes through UpdateAsync and carries a lock { job, t }.
	  A server only writes when it owns the lock, so two servers can never
	  overwrite each other (e.g. a fast rejoin while the old server is still
	  saving).
	* A failed load never falls back to blank defaults that could be saved over
	  real progress: the player is kicked with a friendly message instead.
	  (Studio without API access gets a non-saving session for testing.)
	* Data is versioned; MIGRATIONS upgrade old saves step by step and
	  Reconcile() fills keys added later with defaults.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)

local STORE_NAME = if RunService:IsStudio() then "SAG_Player_Studio_v1" else "SAG_Player_v1"
local LOCK_EXPIRE = 150 -- seconds; locks are refreshed by every autosave
local AUTOSAVE = 60
local LOCK_RETRIES = 6
local LOCK_RETRY_WAIT = 5

local DataService = {}
DataService.StoreName = STORE_NAME

-- Callbacks (not a BindableEvent: Bindables deep-copy tables, and every
-- service must mutate the *same* data table that gets saved).
local loadedHooks: { (Player, any) -> () } = {}

function DataService.OnLoaded(fn: (Player, any) -> ())
	table.insert(loadedHooks, fn)
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
end

type Profile = {
	data: any,
	key: string,
	saving: boolean,
	noSave: boolean,
	released: boolean,
	lastSave: number,
}

local profiles: { [Player]: Profile } = {}

local function defaults()
	return {
		version = Config.DataVersion,
		coins = Config.StartingCoins,
		totalEarned = 0,
		level = 1,
		xp = 0,
		rebirths = 0,
		upgrades = { Speed = 0, Slots = 0, Income = 0, Lock = 0 },
		goobers = {}, -- [uid] = { id = gooberId, stand = n }
		bank = 0, -- uncollected income waiting on the Cash Pad
		dex = {}, -- [gooberId] = times collected
		dexClaimed = {}, -- [milestone count as string] = true
		tutorial = 0, -- step index; Tutorial.DONE when finished
		receipts = {}, -- [purchaseId] = os.time()
		boostUntil = 0,
		lastOnline = 0,
		title = "",
		stats = { snags = 0, steals = 0, stolenFrom = 0, sold = 0, caught = 0 },
		settings = { music = true, sfx = true },
		-- Halloween update (added in v2; old saves get these from reconcile)
		candy = 0,
		event = { xp = 0, level = 0, claimed = {} }, -- claimed[tostring(level)] = true
		candyFound = {}, -- [candyId] = true
		quests = {
			chain = 1, -- index of the current Halloween quest (beyond the end = all done)
			chainProgress = 0,
			daily = { day = -1, list = {} }, -- list = { { id, progress, claimed } }
		},
		levelClaimed = {}, -- [tostring(level)] = true (progression milestones)
		hdexClaimed = {}, -- [tostring(count)] = true (Halloween collection rewards)
		flags = { islandIntro = false },
		bucketReady = {}, -- [bucketId] = os.time() it refills (saved, so rejoining can't refill)
	}
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

-- Fill missing keys (added in later versions) without touching existing values.
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

-- MIGRATIONS[n] upgrades a version-n save to version n+1.
local MIGRATIONS: { [number]: (any) -> () } = {}

local function migrate(data)
	data.version = data.version or 1
	while data.version < Config.DataVersion do
		local step = MIGRATIONS[data.version]
		if step then
			step(data)
		end
		data.version += 1
	end
	return data
end

-- Repair anything malformed so one bad value can't break the session.
local function sanitize(data)
	-- Halloween update fields
	local function tbl(v)
		return if type(v) == "table" then v else {}
	end
	data.event = tbl(data.event)
	data.event.claimed = tbl(data.event.claimed)
	data.candyFound = tbl(data.candyFound)
	data.quests = tbl(data.quests)
	data.quests.daily = tbl(data.quests.daily)
	data.quests.daily.list = tbl(data.quests.daily.list)
	data.levelClaimed = tbl(data.levelClaimed)
	data.hdexClaimed = tbl(data.hdexClaimed)
	data.flags = tbl(data.flags)
	data.bucketReady = tbl(data.bucketReady)
	for id, t in pairs(data.bucketReady) do
		if type(t) ~= "number" or t ~= t then
			data.bucketReady[id] = nil
		end
	end
	local function num(v, default, min)
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			return default
		end
		return math.max(min or 0, v)
	end
	data.coins = num(data.coins, 0)
	data.bank = num(data.bank, 0)
	data.totalEarned = num(data.totalEarned, 0)
	data.level = math.floor(num(data.level, 1, 1))
	data.xp = num(data.xp, 0)
	data.rebirths = math.floor(math.min(num(data.rebirths, 0), Config.Rebirth.max))
	data.candy = math.floor(num(data.candy, 0))
	data.event.xp = num(data.event.xp, 0)
	data.event.level = math.floor(math.min(num(data.event.level, 0), 25))
	data.quests.chain = math.floor(num(data.quests.chain, 1, 1))
	data.quests.chainProgress = num(data.quests.chainProgress, 0)
	data.quests.daily.day = math.floor(tonumber(data.quests.daily.day) or -1)
	for _, def in ipairs(Config.Upgrades) do
		data.upgrades[def.key] = math.floor(math.min(num(data.upgrades[def.key], 0), def.max))
	end
	-- goobers: unique stand indices inside the plot
	local used = {}
	local fixed = {}
	for uid, g in pairs(data.goobers) do
		if type(g) == "table" and type(g.id) == "string" and GooberData.ById[g.id] then
			local stand = tonumber(g.stand)
			if not stand or stand < 1 or stand > Config.MaxStands or used[stand] then
				stand = nil
			end
			fixed[tostring(uid)] = { id = g.id, stand = stand, paid = if type(g.paid) == "number" and g.paid >= 0 then g.paid else nil }
			if stand then
				used[stand] = true
			end
		end
	end
	for _, g in pairs(fixed) do
		if not g.stand then
			for i = 1, Config.MaxStands do
				if not used[i] then
					g.stand = i
					used[i] = true
					break
				end
			end
		end
	end
	data.goobers = fixed
	-- receipts: keep the 100 most recent
	local list = {}
	for id, t in pairs(data.receipts) do
		table.insert(list, { id = id, t = tonumber(t) or 0 })
	end
	if #list > 100 then
		table.sort(list, function(a, b)
			return a.t > b.t
		end)
		local keep = {}
		for i = 1, 100 do
			keep[list[i].id] = list[i].t
		end
		data.receipts = keep
	end
	return data
end

-- Hooks run synchronously right before a leaving player's final save, so other
-- services can settle in-flight state (carried Goobers, bank) into the data.
local removingHooks: { (Player, any) -> () } = {}

function DataService.OnRemoving(fn: (Player, any) -> ())
	table.insert(removingHooks, fn)
end

-- Hooks run after the final save of a leaving player (runtime cleanup).
local removedHooks: { (Player) -> () } = {}

function DataService.AfterRemove(fn: (Player) -> ())
	table.insert(removedHooks, fn)
end

local function runRemovedHooks(player: Player)
	for _, fn in ipairs(removedHooks) do
		local ok, err = pcall(fn, player)
		if not ok then
			warn("[DataService] removed hook error:", err)
		end
	end
end

local function runRemovingHooks(player: Player, data)
	for _, fn in ipairs(removingHooks) do
		local ok, err = pcall(fn, player, data)
		if not ok then
			warn("[DataService] removing hook error:", err)
		end
	end
end

local function keyFor(player: Player)
	return "P_" .. player.UserId
end

local function loadData(player: Player): (boolean, any, boolean)
	if not store then
		return false, nil, false
	end
	local key = keyFor(player)
	for attempt = 1, LOCK_RETRIES do
		local lockedElsewhere = false
		local result
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				local now = os.time()
				if type(old) == "table" and old.lock and old.lock.job ~= game.JobId and now - (old.lock.t or 0) < LOCK_EXPIRE then
					lockedElsewhere = true
					return nil -- cancel the write, leave the save untouched
				end
				local data
				if type(old) == "table" and type(old.data) == "table" then
					data = old.data
				else
					data = defaults()
				end
				data = migrate(data)
				reconcile(data, defaults())
				sanitize(data)
				result = data
				return { data = data, lock = { job = game.JobId, t = now } }
			end)
		end)
		if ok and result and not lockedElsewhere then
			return true, result, false
		end
		if not ok then
			warn(("[DataService] load attempt %d for %s failed: %s"):format(attempt, player.Name, tostring(err)))
		end
		if not player.Parent then
			return false, nil, false
		end
		task.wait(if lockedElsewhere then LOCK_RETRY_WAIT else 2 ^ attempt)
		if attempt == LOCK_RETRIES and lockedElsewhere then
			return false, nil, true
		end
	end
	return false, nil, false
end

function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.noSave or profile.released then
		return profile ~= nil and profile.noSave
	end
	if not store then
		return false
	end
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	local lostLock = false
	profile.data.lastOnline = os.time()
	-- the final save (release) retries with backoff; autosaves just try again next cycle
	local attempts = if release then 4 else 1
	local ok, err
	for attempt = 1, attempts do
		ok, err = pcall(function()
			store:UpdateAsync(profile.key, function(old)
				if type(old) == "table" and old.lock and old.lock.job ~= game.JobId then
					lostLock = true
					return nil
				end
				return {
					data = profile.data,
					lock = if release then nil else { job = game.JobId, t = os.time() },
				}
			end)
		end)
		if ok or lostLock then
			break
		end
		warn(("[DataService] save attempt %d/%d failed for %s: %s"):format(attempt, attempts, player.Name, tostring(err)))
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
	end
	profile.saving = false
	if ok and not lostLock then
		profile.lastSave = os.clock()
		if release then
			profile.released = true
		end
		return true
	end
	if lostLock then
		warn("[DataService] lock lost for", player.Name, "- not overwriting")
		profile.released = true
		player:Kick("Your Snag A Goober save was opened on another server. Please rejoin.")
	else
		warn("[DataService] save failed for", player.Name, err)
	end
	return false
end

function DataService.Get(player: Player)
	local p = profiles[player]
	return p and p.data
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.IsTemporary(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.noSave
end

function DataService.NewUid(): string
	return HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 16)
end

function DataService.Defaults()
	return defaults()
end

-- exposed for the test harness
DataService._sanitize = sanitize
DataService._migrate = migrate
DataService._reconcile = reconcile

local function onPlayerAdded(player: Player)
	local ok, data, locked = loadData(player)
	if not player.Parent then
		if ok and store then
			-- they left while we were loading: give the lock back right away
			pcall(function()
				store:UpdateAsync(keyFor(player), function(old)
					if type(old) == "table" and old.lock and old.lock.job == game.JobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end
	if not ok then
		if RunService:IsStudio() and not locked then
			warn("[DataService] Studio session without saving (enable Studio API access to test saves)")
			profiles[player] = {
				data = defaults(),
				key = keyFor(player),
				saving = false,
				noSave = true,
				released = false,
				lastSave = 0,
			}
		else
			player:Kick(
				if locked
					then "Your save is still closing on another server. Please rejoin in a minute."
					else "Roblox saves are having trouble right now, so we stopped before anything could be lost. Please rejoin soon!"
			)
			return
		end
	else
		profiles[player] = {
			data = data,
			key = keyFor(player),
			saving = false,
			noSave = false,
			released = false,
			lastSave = os.clock(),
		}
	end
	for _, fn in ipairs(loadedHooks) do
		task.spawn(fn, player, profiles[player].data)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			runRemovingHooks(player, profiles[player].data)
			DataService.Save(player, true)
			profiles[player] = nil
			runRemovedHooks(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				runRemovingHooks(player, profiles[player].data)
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService

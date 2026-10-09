--[[
	EventService - the Halloween event, server side.

	  * Candy: hidden candies (each once per player) and refilling buckets.
	    The server checks the player is really standing next to it.
	  * Event track: event XP -> event levels 1-25, each with a claimable
	    reward (candy, coins, 2x boosts, titles, exclusive Goobers).
	  * Candy Shop: spend candy on boosts, coins and Halloween Goobers.
	  * Halloween collection rewards (4 / 8 / 12 / 16 discovered).
	  * Travel: the Spooky Portal pair (works while carrying - you walked to
	    it) and the top-bar shortcuts Island / Base / Belt (not while carrying).
	  * Area gates: under-level players are moved back out of locked areas.

	Every grant is decided here from server state; clients only ask.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Util = require(ReplicatedStorage.Shared.Util)

local EventService = {}
local S

-- per-session (not saved): travel cooldown, areas entered (bucket cooldowns are saved)
local sessionState: { [Player]: { travelAt: number, areasSeen: { [string]: boolean }, zone: string?, lastArea: string? } } = {}

function EventService.Init(registry)
	S = registry
end

local function ss(player: Player)
	local t = sessionState[player]
	if not t then
		t = { travelAt = -100, areasSeen = {}, zone = nil }
		sessionState[player] = t
	end
	return t
end

local function fail(player: Player, msg: string)
	S.Session.Notify(player, "Error", { text = msg })
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- ------------------------------------------------------------ zones
function EventService.OnIsland(pos: Vector3): boolean
	local o, size = Halloween.Origin, Halloween.Size
	return math.abs(pos.X - o.X) <= size.X / 2 + 10 and math.abs(pos.Z - o.Z) <= size.Y / 2 + 10
end

-- can this player enter the area? (player level AND event level)
function EventService.AreaOpen(st, area): boolean
	local evOk = st.data.event.level >= (area.eventLevel or 0) or not Halloween.Active()
	return st.data.level >= area.level and evOk
end

function EventService.LockText(area): string
	if (area.eventLevel or 0) > 0 then
		return ("%s needs Level %d and Event Level %d."):format(area.name, area.level, area.eventLevel)
	end
	return ("%s unlocks at Level %d."):format(area.name, area.level)
end

function EventService.AreaAt(pos: Vector3)
	if not EventService.OnIsland(pos) then
		return nil
	end
	-- side areas first (the Village rectangle spans the middle strip)
	for _, a in ipairs(Halloween.Areas) do
		if a.key ~= "Village" and pos.X >= a.min.X and pos.X <= a.max.X and pos.Z >= a.min.Z and pos.Z <= a.max.Z then
			return a
		end
	end
	return Halloween.AreaByKey.Village
end

-- --------------------------------------------------------- rewards
-- coins rewards are "seconds of your current income" with a floor so new
-- players still get something worthwhile
local function coinsFor(player: Player, seconds: number): number
	local rate = S.Session.BaseRate(player) -- not doubled by an active boost
	return math.max(math.floor(rate * seconds), seconds * 2)
end
EventService.CoinsFor = coinsFor

function EventService.AddCandy(player: Player, n: number)
	local st = S.Session.Get(player)
	if not st or n <= 0 then
		return
	end
	st.data.candy += math.floor(n)
	st.dirty = true
end

local function setTitle(player: Player, title: string)
	local st = S.Session.Get(player)
	st.data.title = title
	player:SetAttribute("Title", title)
	if S.Character then
		S.Character.RefreshTag(player)
	end
end

local function addBoost(player: Player, seconds: number)
	local st = S.Session.Get(player)
	local d = st.data
	d.boostUntil = math.max(d.boostUntil, os.time()) + seconds
	S.Session.ComputeRate(player)
	st.dirty = true
end

-- Give a Halloween (or any) Goober to the player's base. Returns false if full.
local function grantGoober(player: Player, gid: string, source: string): boolean
	if not GooberData.ById[gid] or not S.Session.HasFreeSlot(player) then
		return false
	end
	local uid = S.Base.Place(player, gid, { paid = 0 })
	if not uid then
		return false
	end
	-- (Base.Place already records the discovery)
	S.Session.ComputeRate(player)
	S.Hooks.Fire("placed", player, { id = gid, source = source })
	return true
end

-- Apply a reward table { candy, coins (seconds), xp, exp, boost (seconds), title, goober }.
-- Goober rewards are checked by the caller (base space) before anything is granted.
function EventService.Grant(player: Player, reward, source: string): { string }
	local lines = {}
	if reward.candy then
		EventService.AddCandy(player, reward.candy)
		table.insert(lines, ("+%d Candy"):format(reward.candy))
	end
	if reward.coins then
		local c = coinsFor(player, reward.coins)
		S.Session.AddCoins(player, c)
		table.insert(lines, "+$" .. Util.Short(c))
	end
	if reward.boost then
		addBoost(player, reward.boost)
		table.insert(lines, ("2x income for %s"):format(Util.Time(reward.boost)))
	end
	if reward.xp then
		S.Session.AddXP(player, reward.xp)
		table.insert(lines, ("+%d XP"):format(reward.xp))
	end
	if reward.exp then
		EventService.AddEventXP(player, reward.exp)
		table.insert(lines, ("+%d Event XP"):format(reward.exp))
	end
	if reward.goober then
		grantGoober(player, reward.goober, source)
		table.insert(lines, GooberData.ById[reward.goober].name .. " (in your base)")
	end
	if reward.title then
		setTitle(player, reward.title)
		table.insert(lines, ('Title "%s"'):format(reward.title))
	end
	S.Session.MarkDirty(player)
	return lines
end

-- ------------------------------------------------------- event track
function EventService.AddEventXP(player: Player, n: number)
	local st = S.Session.Get(player)
	if not st or n <= 0 or not Halloween.Active() then
		return
	end
	local ev = st.data.event
	local function chests()
		-- track done: Event XP keeps filling Bonus Chests
		local c = ev.bonusXp // Halloween.BonusEvery
		if c > 0 then
			ev.bonusXp -= c * Halloween.BonusEvery
			EventService.AddCandy(player, c * Halloween.BonusCandy)
			S.Session.Notify(player, "Reward", { title = "BONUS CHEST", lines = { ("+%d Candy"):format(c * Halloween.BonusCandy) } })
		end
	end
	if ev.level >= Halloween.MaxEventLevel then
		ev.bonusXp += n
		chests()
		st.dirty = true
		return
	end
	local from = ev.level
	ev.xp += n
	while ev.level < Halloween.MaxEventLevel and ev.xp >= Halloween.EventXPFor(ev.level) do
		ev.xp -= Halloween.EventXPFor(ev.level)
		ev.level += 1
		S.Hooks.Fire("eventlevel", player, { level = ev.level })
	end
	if ev.level >= Halloween.MaxEventLevel then
		ev.bonusXp += ev.xp
		ev.xp = 0
		chests()
	end
	if ev.level > from then
		-- one banner even when a big reward jumps several levels
		S.Session.Notify(player, "EventLevel", { level = ev.level, from = from })
	end
	st.dirty = true
end

local function trackReward(level: number)
	local t = Halloween.Track[level]
	if not t then
		return nil
	end
	local reward = {}
	if t.kind == "candy" then
		reward.candy = t.n
	elseif t.kind == "coins" then
		reward.coins = t.n
	elseif t.kind == "boost" then
		reward.boost = t.n
	elseif t.kind == "goober" then
		reward.goober = t.id
	elseif t.kind == "title" then
		reward.title = t.text
	end
	if t.title then
		reward.title = t.title
	end
	return reward
end
EventService.TrackReward = trackReward

function EventService.ClaimTrack(player: Player, level: any)
	if type(level) ~= "number" or level ~= math.floor(level) or not S.Session.RateOk(player, "EventClaim", 6, 2) then
		return
	end
	local st = S.Session.Get(player)
	local ev = st.data.event
	local key = tostring(level)
	local reward = trackReward(level)
	if not reward or ev.level < level or ev.claimed[key] then
		return
	end
	if reward.goober and not S.Session.HasFreeSlot(player) then
		return fail(player, "Your base is full! Make room for your new Goober first.")
	end
	ev.claimed[key] = true
	local lines = EventService.Grant(player, reward, "reward")
	S.Session.Notify(player, "Reward", { title = ("EVENT LEVEL %d"):format(level), lines = lines })
end

-- ------------------------------------------------------------ candy
function EventService.CollectCandy(player: Player, id: any)
	if type(id) ~= "string" or not S.Session.RateOk(player, "Candy", 8, 2) then
		return
	end
	local c = Halloween.CandyById[id]
	local st = S.Session.Get(player)
	local hrp = hrpOf(player)
	if not c or not hrp or st.data.candyFound[id] or not Halloween.Active() then
		return
	end
	if (hrp.Position - c.pos).Magnitude > Halloween.CandyRadius or not S.MoveGuard.Plausible(player) then
		return
	end
	st.data.candyFound[id] = true
	EventService.AddCandy(player, Halloween.CandyValue)
	EventService.AddEventXP(player, Halloween.CandyXP)
	local found = 0
	for _ in pairs(st.data.candyFound) do
		found += 1
	end
	S.Session.Notify(player, "CandyFound", { id = id, found = found, total = #Halloween.Candies, candy = Halloween.CandyValue })
	S.Hooks.Fire("candy", player, { id = id })
	S.Session.MarkDirty(player)
end

function EventService.Bucket(player: Player, id: any)
	if type(id) ~= "string" or not S.Session.RateOk(player, "Bucket", 4, 2) then
		return
	end
	local b = Halloween.BucketById[id]
	local hrp = hrpOf(player)
	if not b or not hrp then
		return
	end
	if not Halloween.Active() then
		return fail(player, "The Halloween event is over - the buckets are empty!")
	end
	local st = S.Session.Get(player)
	local ready = st.data.bucketReady
	local now = os.time()
	-- clamp so a clock jump can't lock a bucket for longer than one cooldown
	if (ready[id] or 0) > now + Halloween.BucketCooldown then
		ready[id] = now + Halloween.BucketCooldown
	end
	if now < (ready[id] or 0) then
		return fail(player, ("This bucket refills in %s."):format(Util.Time(ready[id] - now)))
	end
	if flatDist(hrp.Position, b.pos) > 12 or not S.MoveGuard.Plausible(player) then
		return
	end
	ready[id] = now + Halloween.BucketCooldown
	st.dirty = true
	EventService.AddCandy(player, Halloween.BucketCandy)
	EventService.AddEventXP(player, Halloween.BucketXP)
	S.Session.Notify(player, "Bucket", { id = id, candy = Halloween.BucketCandy, refill = Halloween.BucketCooldown })
	S.Hooks.Fire("bucket", player, { id = id })
end

function EventService.BucketCooldowns(player: Player)
	local out = {}
	local now = os.time()
	for id, t in pairs(S.Session.Get(player).data.bucketReady) do
		if t > now then
			out[id] = math.ceil(t - now)
		end
	end
	return out
end

-- ------------------------------------------------------------- shop
function EventService.Buy(player: Player, key: any)
	if type(key) ~= "string" or not S.Session.RateOk(player, "EventBuy", 4, 2) then
		return
	end
	local item = Halloween.ShopByKey[key]
	local st = S.Session.Get(player)
	if not item then
		return
	end
	if st.data.candy < item.price then
		return fail(player, ("You need %d Candy for %s."):format(item.price, item.name))
	end
	if item.kind == "goober" and not S.Session.HasFreeSlot(player) then
		return fail(player, "Your base is full! Sell a Goober or buy More Stands.")
	end
	st.data.candy -= item.price
	local reward = {}
	if item.kind == "boost" then
		reward.boost = item.n
	elseif item.kind == "coins" then
		reward.coins = item.n
	elseif item.kind == "goober" then
		reward.goober = item.id
	end
	local lines = EventService.Grant(player, reward, "shop")
	S.Session.Notify(player, "Reward", { title = "CANDY SHOP", lines = lines })
end

-- ------------------------------------------------ halloween collection
function EventService.HalloweenDiscovered(player: Player): number
	local st = S.Session.Get(player)
	local n = 0
	for _, g in ipairs(GooberData.PoolList.Halloween) do
		if st.data.dex[g.id] then
			n += 1
		end
	end
	return n
end

function EventService.ClaimHDex(player: Player, count: any)
	if type(count) ~= "number" or not S.Session.RateOk(player, "HDex", 4, 2) then
		return
	end
	local st = S.Session.Get(player)
	local key = tostring(count)
	for _, m in ipairs(Halloween.DexRewards) do
		if m.count == count and not st.data.hdexClaimed[key] and EventService.HalloweenDiscovered(player) >= count then
			st.data.hdexClaimed[key] = true
			local lines = EventService.Grant(player, { candy = m.candy, boost = m.boost, title = m.title }, "reward")
			S.Session.Notify(player, "Reward", { title = ("HALLOWEEN COLLECTION %d/%d"):format(count, GooberData.HalloweenCount), lines = lines })
			return
		end
	end
end

-- ----------------------------------------------------------- travel
local function destCFrame(player: Player, dest: string): CFrame?
	if dest == "Island" then
		local p = Halloween.IslandArrival
		return CFrame.lookAt(p, p + Halloween.IslandPortal.facing)
	elseif dest == "Main" then
		local p = Halloween.MainArrival
		return CFrame.lookAt(p, p + Halloween.MainPortal.facing)
	elseif dest == "Plaza" then
		local p = Halloween.PlazaArrival
		return CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
	elseif dest == "Base" then
		return S.Plot.SpawnCFrame(player)
	end
	return nil
end

-- dest: "PortalIn" / "PortalOut" (walking through a physical portal) or the
-- top-bar shortcuts "Island" / "Base" / "Plaza".
function EventService.Travel(player: Player, dest: any)
	if type(dest) ~= "string" or not S.Session.RateOk(player, "Travel", 3, 2) then
		return
	end
	local st = S.Session.Get(player)
	local hrp = hrpOf(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if not Halloween.Enabled and dest ~= "Base" and dest ~= "Plaza" and dest ~= "PortalOut" then
		return fail(player, "Halloween Island is closed.")
	end
	local t = ss(player)
	local now = os.clock()
	if now - t.travelAt < Halloween.TravelCooldown then
		if dest ~= "PortalIn" and dest ~= "PortalOut" then
			fail(player, "Travel is recharging - try again in a moment.")
		end
		return
	end
	local target
	if dest == "PortalIn" or dest == "PortalOut" then
		-- you walked to the portal: allowed while carrying a belt Goober, but
		-- not a stolen one (the owner must still be able to chase the thief)
		if st.carry and st.carry.source == "steal" then
			return fail(player, "You can't escape through the portal with a stolen Goober!")
		end
		local portal = if dest == "PortalIn" then Halloween.MainPortal else Halloween.IslandPortal
		if flatDist(hrp.Position, portal.pos) > 16 or not S.MoveGuard.Plausible(player) then
			return
		end
		target = if dest == "PortalIn" then "Island" else "Main"
	else
		if dest ~= "Island" and dest ~= "Base" and dest ~= "Plaza" then
			return
		end
		if st.carry then
			return fail(player, "Bring your Goober home first - shortcuts only work with empty hands!")
		end
		target = dest
	end
	local cf = destCFrame(player, target)
	if not cf then
		return
	end
	t.travelAt = now
	-- load the destination first (streaming) so nobody lands in the void
	pcall(player.RequestStreamAroundAsync, player, cf.Position, 3)
	if not player.Parent or not hrpOf(player) or (st.carry and (st.carry.source == "steal" or (dest ~= "PortalIn" and dest ~= "PortalOut"))) then
		return -- left, died, or picked something up while the area loaded
	end
	S.MoveGuard.ServerMove(player, cf)
	S.Session.Effect("Travel", { to = target }, player)
	if target == "Island" then
		S.Hooks.Fire("visit", player, {})
		if not st.data.flags.islandIntro then
			S.Session.Notify(player, "IslandIntro", {})
		end
	end
end

function EventService.IntroSeen(player: Player)
	local st = S.Session.Get(player)
	if st and not st.data.flags.islandIntro then
		st.data.flags.islandIntro = true
		st.dirty = true
	end
end

-- ------------------------------------------------------------ snapshot
function EventService.Snapshot(player: Player)
	local st = S.Session.Get(player)
	local d = st.data
	local found = {}
	for id in pairs(d.candyFound) do
		table.insert(found, id)
	end
	return {
		candy = d.candy,
		eventLevel = d.event.level,
		eventXp = d.event.xp,
		eventNeed = if d.event.level < Halloween.MaxEventLevel then Halloween.EventXPFor(d.event.level) else 0,
		bonusXp = d.event.bonusXp,
		bonusEvery = Halloween.BonusEvery,
		placeLeft = math.max(0, Halloween.PlaceDailyFull - (if d.event.placeDay == os.time() // 86400 then d.event.placeCount else 0)),
		areasVisited = d.areasVisited,
		active = Halloween.Active(),
		eventClaimed = d.event.claimed,
		candyFound = found,
		bucketCooldowns = EventService.BucketCooldowns(player),
		hdexClaimed = d.hdexClaimed,
		hdexCount = EventService.HalloweenDiscovered(player),
		levelClaimed = d.levelClaimed,
		islandIntro = d.flags.islandIntro == true,
		eventEndsIn = math.max(0, Halloween.EndsAt - os.time()),
	}
end

-- -------------------------------------------------------------- loops
function EventService.Start()
	-- event XP for every Halloween Goober brought home from a belt
	S.Hooks.On("placed", function(player, p)
		local def = GooberData.ById[p.id]
		local st = S.Session.Get(player)
		if def and st and def.pool == "Halloween" and p.source == "belt" then
			local ev = st.data.event
			local day = os.time() // 86400
			if ev.placeDay ~= day then
				ev.placeDay = day
				ev.placeCount = 0
			end
			ev.placeCount += 1
			local mult = if ev.placeCount <= Halloween.PlaceDailyFull then 1 else Halloween.PlaceTiredMult
			EventService.AddEventXP(player, math.max(1, math.floor((Halloween.PlaceXP[def.rarity] or 0) * mult)))
		end
	end)
	-- area gates + area-entered events, twice a second
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, st in pairs(S.Session.All()) do
				local hrp = hrpOf(player)
				if st.ready and hrp then
					local t = ss(player)
					local area = EventService.AreaAt(hrp.Position)
					t.zone = if area then "Island" else "Main"
					if area then
						-- Personal Drops wait while you're on the island (they spawn on the Slop Line)
						st.nextDropAt = math.max(st.nextDropAt, os.clock() + 6)
					end
					if area and area.gate and not EventService.AreaOpen(st, area) then
						-- short of the player level or the event level: back out through the gate (hub side)
						local out = area.gate + Vector3.new(if area.gate.X > Halloween.Origin.X then -8 else 8, 3, 0)
						S.MoveGuard.ServerMove(player, CFrame.lookAt(out, out + Vector3.new(if area.gate.X > Halloween.Origin.X then -1 else 1, 0, 0)))
						fail(player, EventService.LockText(area))
						t.lastArea = nil
					elseif area and t.lastArea ~= area.key then
						t.lastArea = area.key
						local first = not st.data.areasVisited[area.key]
						st.data.areasVisited[area.key] = true
						S.Hooks.Fire("area", player, { key = area.key })
						if not t.areasSeen[area.key] then
							t.areasSeen[area.key] = true
							S.Session.Notify(player, "AreaEnter", { key = area.key, first = first })
						end
					elseif not area then
						t.lastArea = nil
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionState[player] = nil
	end)
end

return EventService

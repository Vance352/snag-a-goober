--[[
	BreachService - the Goober Breach (replaces the old conveyor belts).

	Every site (the main Breach in the plaza, plus one cauldron per Halloween
	area) runs a cycle:  Cooldown -> Charging -> Unstable -> BLAST.
	A blast flings a burst of Goobers across the site's field. Each loose
	Goober carries its whole flight/hop plan, so its position is a pure
	function of time (Shared/Breach.PositionAt): clients animate it, the server
	validates snags with the same maths. Unsnagged Goobers dive back in when
	their time is up.

	Lifecycle of a Goober that isn't on a stand yet:
	   loose (from a blast)  --snag-->  carried  --deliver-->  on a stand
	                                       |  (blasted / died)
	                                       v
	                              dropped (grabbable, 20 s) --grab--> carried
	                                       |  (nobody grabs it)
	                                       v
	                       waddles home to whoever dropped it (or vanishes)
	A Goober entry is removed from `loose` before anything else happens to it,
	so two players grabbing at once can't both get it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Breach = require(ReplicatedStorage.Shared.Breach)
local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)

local BreachService = {}
local S

type Loose = {
	uid: string,
	id: string,
	line: string,
	site: string,
	path: any,
	price: number,
	paid: number?, -- dropped Goobers keep what the first carrier paid (sell value)
	paidBy: number?, -- ...and who paid it
	reservedFor: number?,
	dropped: boolean?,
	dropBy: number?,
	locks: { [number]: number }?, -- userId -> can't grab before this (the dropper and the blaster)
	refundedTo: number?, -- the dropper left and was refunded: they pay that back to re-grab it
	refundAmt: number?,
	model: Model,
}

local loose: { [string]: Loose } = {}
local claimed: { [string]: { name: string, by: number, t: number } } = {} -- recent snags (for "too slow!")
local folder: Folder
local stateFolder: Folder
local candidates: { [string]: { Vector3 } } = {}
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

function BreachService.Init(registry)
	S = registry
	folder = Instance.new("Folder")
	folder.Name = "LooseGoobers"
	folder.Parent = workspace
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "BreachState"
	stateFolder.Parent = ReplicatedStorage
end

-- ------------------------------------------------------- landing spots
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(x: number, z: number, baseY: number): Vector3?
	rayParams.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(Vector3.new(x, baseY + 60, z), Vector3.new(0, -90, 0), rayParams)
	if not hit or hit.Normal.Y < 0.8 then
		return nil
	end
	local inst = hit.Instance
	if inst:IsDescendantOf(workspace:FindFirstChild("Plots") or folder) then
		return nil
	end
	-- only open floor: not on top of props, walls, the Breach itself
	if hit.Position.Y > baseY + 1.6 or hit.Position.Y < baseY - 2 then
		return nil
	end
	return hit.Position
end

local function sampleSite(name: string)
	local site = Breach.Sites[name]
	local f = site.field
	local pts = {}
	local step = 4
	local x = f[1]
	while x <= f[2] do
		local z = f[3]
		while z <= f[4] do
			local px, pz = x + rng:NextNumber(-1.2, 1.2), z + rng:NextNumber(-1.2, 1.2)
			if Vector2.new(px - site.center.X, pz - site.center.Z).Magnitude > site.avoid then
				local g = groundAt(px, pz, site.center.Y)
				if g then
					table.insert(pts, g)
				end
			end
			z += step
		end
		x += step
	end
	candidates[name] = pts
	return #pts
end

local function randomSpot(name: string): Vector3
	local pts = candidates[name]
	if not pts or #pts == 0 then
		local site = Breach.Sites[name]
		return site.center + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20))
	end
	return pts[rng:NextInteger(1, #pts)]
end

-- a spot near `target` (personal drops land on your side of the plaza)
local function spotNear(name: string, target: Vector3): Vector3
	local best, bestD = nil, math.huge
	for _ = 1, 40 do
		local p = randomSpot(name)
		local d = Vector2.new(p.X - target.X, p.Z - target.Z).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best or randomSpot(name)
end

-- next hop: a spot 7-12 studs away (or stay put if none is free)
local function hopFrom(name: string, from: Vector3): Vector3?
	local d0, d1 = Breach.HopDistance[1], Breach.HopDistance[2]
	for _ = 1, 16 do
		local p = randomSpot(name)
		local d = Vector2.new(p.X - from.X, p.Z - from.Z).Magnitude
		if d >= d0 and d <= d1 then
			return p
		end
	end
	return nil
end

-- --------------------------------------------------------------- rolls
function BreachService.Roll(lineName: string, luck: number, chaos): string
	local line = Config.Lines[lineName]
	local poolName = line.pool or "Classic"
	local odds = Util.Odds(lineName, luck, chaos and chaos.secretMult)
	if poolName == "Classic" and chaos and chaos.chaosGoobChance and rng:NextNumber() < chaos.chaosGoobChance then
		return "G25_ChaosGoob"
	end
	local r = rng:NextNumber() * 100
	local acc = 0
	local picked = "Common"
	for _, rarity in ipairs(Config.RarityOrder) do
		acc += odds[rarity]
		if r <= acc and odds[rarity] > 0 then
			picked = rarity
			break
		end
	end
	local byRarity = GooberData.ByPool[poolName]
	local pool = byRarity[picked]
	if not pool or #pool == 0 then
		for _, rarity in ipairs(Config.RarityOrder) do
			if byRarity[rarity] and #byRarity[rarity] > 0 then
				pool = byRarity[rarity]
				break
			end
		end
	end
	return pool[rng:NextInteger(1, #pool)].id
end

-- --------------------------------------------------------------- spawn
local function setPathAttributes(model: Model, path)
	model:SetAttribute("LaunchT", path.t0)
	model:SetAttribute("LaunchFrom", path.from)
	model:SetAttribute("Flight", path.flight)
	model:SetAttribute("Apex", path.apex)
	model:SetAttribute("GroundY", path.y)
	model:SetAttribute("Expire", path.expire)
	model:SetAttribute("PathPts", Breach.EncodePts(path.pts))
end

local function makePath(from: Vector3, land: Vector3, t0: number, life: number, hopEvery, siteName: string?)
	local dist = (Vector3.new(land.X, from.Y, land.Z) - from).Magnitude
	local flight = Breach.FlightMin + dist / 55
	local path = { t0 = t0, from = from, flight = flight, apex = 5 + dist * 0.22, y = land.Y, pts = {} }
	local tLand = t0 + flight
	table.insert(path.pts, { land.X, land.Z, tLand })
	path.expire = tLand + life
	if hopEvery and siteName then
		local t = tLand
		local here = land
		while true do
			t += rng:NextNumber(hopEvery[1], hopEvery[2])
			if t > path.expire - 2 then
				break
			end
			local nxt = hopFrom(siteName, here)
			if nxt then
				table.insert(path.pts, { nxt.X, nxt.Z, t })
				here = nxt
			end
		end
	end
	return path
end

function BreachService.Spawn(gid: string, lineName: string, siteName: string, reservedFor: Player?, opts): Loose
	opts = opts or {}
	local site = Breach.Sites[siteName]
	local def = GooberData.ById[gid]
	local uid = S.Data.NewUid()
	local model = S.Model.Build(gid, uid, "loose")
	local mouth = site.center + site.mouth
	local land
	if opts.near then
		land = spotNear(siteName, opts.near)
	else
		land = randomSpot(siteName)
	end
	local life = (Breach.Life[def.rarity] or 40) + (if reservedFor then 25 else 0)
	local path = makePath(mouth, land, now() + (opts.delay or 0), life, Breach.HopEvery[def.rarity], siteName)
	local e: Loose = {
		uid = uid,
		id = gid,
		line = lineName,
		site = siteName,
		path = path,
		reservedFor = reservedFor and reservedFor.UserId,
		-- Personal Drops are half price for their owner
		price = if reservedFor then math.floor(def.price * Config.PersonalDrop.discount) else def.price,
		model = model,
	}
	setPathAttributes(model, path)
	model:SetAttribute("Line", lineName)
	model:SetAttribute("Site", siteName)
	model:SetAttribute("Price", e.price)
	if reservedFor then
		model:SetAttribute("ReservedFor", reservedFor.UserId)
		model:SetAttribute("ReservedName", reservedFor.DisplayName)
		local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
		local info = tag and tag:FindFirstChild("Info")
		if info then
			info.Text = ("$%s (50%% OFF)  •  +%s/s"):format(Util.Short(e.price), Util.Short(def.income))
		end
	end
	-- the server copy sits where it lands; clients animate the flight and hops
	S.Model.PlaceAt(model, CFrame.lookAt(land, Vector3.new(site.center.X, land.Y, site.center.Z)))
	model.Parent = folder
	loose[uid] = e
	if not opts.quiet and (def.rarity == "Legendary" or def.rarity == "Secret" or def.rarity == "Epic") then
		S.Session.Effect("RareSpawn", { uid = uid, id = gid, rarity = def.rarity, line = lineName, site = siteName })
	end
	return e
end

-- ------------------------------------------------------------- queries
function BreachService.Get(uid: string): Loose?
	return loose[uid]
end

function BreachService.All()
	return loose
end

-- dropped Goobers of this player still lying in a field (they keep a stand reserved)
function BreachService.DroppedCount(player: Player): number
	local n = 0
	for _, e in pairs(loose) do
		if e.dropped and e.dropBy == player.UserId then
			n += 1
		end
	end
	return n
end

function BreachService.PositionOf(e: Loose, t: number?): Vector3
	return (Breach.PositionAt(e.path, t or now()))
end

local function vanish(e: Loose)
	loose[e.uid] = nil
	local pos = Breach.PositionAt(e.path, now())
	S.Session.Effect("Vanish", { pos = pos, rarity = GooberData.ById[e.id].rarity })
	e.model:Destroy()
end

-- ---------------------------------------------------------------- snag
local function fail(player: Player, msg: string)
	S.Session.Notify(player, "Error", { text = msg })
end

function BreachService.Snag(player: Player, uid: any)
	if type(uid) ~= "string" or #uid > 40 then
		return
	end
	if not S.Session.RateOk(player, "Snag", 5, 1) then
		return
	end
	local st = S.Session.Get(player)
	local e = loose[uid]
	if not st or not st.ready then
		return
	end
	if not e then
		-- lost the race (or it just dove back in): say so instead of nothing
		local c = claimed[uid]
		if c and c.by ~= player.UserId and os.clock() - c.t < 5 then
			return fail(player, ("Too slow - %s grabbed it!"):format(c.name))
		end
		return
	end
	if st.carry then
		return fail(player, "Your hands are full! Bring that Goober home first.")
	end
	if e.reservedFor and e.reservedFor ~= player.UserId then
		return fail(player, "That Goober is someone's Personal Drop!")
	end
	local t = now()
	if e.dropped and e.locks and t < (e.locks[player.UserId] or 0) then
		return fail(player, if e.dropBy == player.UserId then "You're still dizzy - grab it in a moment!" else "Your Blaster is still recoiling - grab it in a moment!")
	end
	local line = Config.Lines[e.line]
	if st.data.level < line.levelRequired then
		return fail(player, ("%s need Level %d."):format(line.displayName or "These Goobers", line.levelRequired))
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if line.area then
		-- island cauldrons: the area's gate rules (even for a dropped one), and a
		-- fresh one can only be snagged from inside the area
		local Halloween = require(ReplicatedStorage.Shared.Halloween)
		local area = Halloween.AreaByKey[line.area]
		if not S.Event.AreaOpen(st, area) then
			return fail(player, S.Event.LockText(area))
		end
		local here = S.Event.AreaAt(hrp.Position)
		if not e.dropped and (not here or here.key ~= area.key) then
			return fail(player, ("Step into the %s to snag its Goobers!"):format(area.name))
		end
	end
	if not S.MoveGuard.Plausible(player) then
		return fail(player, "Whoa, slow down!")
	end
	-- a little latency allowance: also check where it was 0.4 s ago
	local p0, grounded0 = Breach.PositionAt(e.path, t)
	local p1, grounded1 = Breach.PositionAt(e.path, t - 0.4)
	if not grounded0 and not grounded1 then
		return fail(player, "Wait for it to land!")
	end
	local dist = math.min((hrp.Position - p0).Magnitude, (hrp.Position - p1).Magnitude)
	if dist > (if e.dropped then Breach.DropSnagRange else Config.SnagRange) then
		return fail(player, "Get closer to snag it!")
	end
	-- (your own drop already holds a stand for you)
	local own = e.dropped and e.dropBy == player.UserId
	if not own and not S.Session.HasFreeSlot(player) then
		return fail(player, "Your base is full! Sell a Goober or buy More Stands.")
	end
	local def = GooberData.ById[e.id]
	local cost = if e.dropped then 0 else e.price
	if e.dropped and e.refundedTo == player.UserId then
		cost = e.refundAmt or 0 -- refunded when they left: rejoining is no free Goober
	end
	if cost > 0 and not S.Session.Spend(player, cost) then
		return fail(player, ("You need $%s to snag %s."):format(Util.Short(cost), def.name))
	end
	-- commit: removed from the field first, so nobody else can have it
	loose[uid] = nil
	claimed[uid] = { name = player.DisplayName, by = player.UserId, t = os.clock() }
	local paidBy = if e.dropped then e.paidBy else player.UserId
	if e.dropped and e.refundedTo == player.UserId then
		paidBy = player.UserId
	end
	local carry = { uid = uid, id = e.id, source = "belt", model = e.model, price = e.paid or e.price, paidBy = paidBy, line = e.line }
	if e.dropped then
		if e.dropBy and e.dropBy ~= player.UserId then
			carry.takenFrom = e.dropBy -- counts as a combat steal when it gets home
		else
			carry.recovered = true
		end
	end
	S.Carry.Begin(player, carry)
	if not e.dropped then
		st.data.stats.snags += 1
	end
	S.Session.Effect("Snagged", { id = e.id, rarity = def.rarity, by = player.UserId, pos = p0, dropped = e.dropped })
	if e.dropped and e.dropBy and e.dropBy ~= player.UserId then
		local from = Players:GetPlayerByUserId(e.dropBy)
		if from then
			S.Session.Notify(from, "GooberTaken", { id = e.id, by = player.DisplayName })
		end
	end
	S.Progress.TutorialEvent(player, "Snagged")
end

-- ------------------------------------------------------------- dropping
-- The carrier lost their Goober (blasted, died, or left). It flies a few studs
-- and lands where anyone can grab it. The dropper - and the blaster, if any -
-- must wait Breach.DropLockout first, so it's a fair race.
local function inAnyPlot(inst: Instance): boolean
	local plots = workspace:FindFirstChild("Plots")
	return plots ~= nil and inst:IsDescendantOf(plots)
end

function BreachService.DropFromCarry(player: Player, dir: Vector3?, reason: string, blaster: Player?)
	local st = S.Session.Get(player)
	local carry = st and st.carry
	if not carry or carry.source ~= "belt" then
		return nil
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	local origin = if hrp then hrp.Position else (carry.lastPos or Vector3.zero)
	S.Carry._clear(player)
	local model = carry.model
	if not model or not model.Parent or not model.PrimaryPart then
		if model then
			model:Destroy()
		end
		model = S.Model.Build(carry.id, carry.uid, "dropped")
	else
		S.Model.SetMode(model, "dropped")
	end
	model:SetAttribute("CarriedBy", nil)
	-- land a few studs away on open ground (straight down if blocked)
	local flat = if dir and dir.Magnitude > 0.01 then Vector3.new(dir.X, 0, dir.Z).Unit else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local land
	local far = Breach.DropDistance
	for _, d in ipairs({ far, far * 0.66, far * 0.33, 0 }) do
		local p = origin + flat * d
		rayParams.FilterDescendantsInstances = { folder, char, (blaster and blaster.Character) or folder }
		local blocked = d > 0 and workspace:Raycast(origin, flat * d, rayParams)
		local g = not blocked and workspace:Raycast(Vector3.new(p.X, origin.Y + 4, p.Z), Vector3.new(0, -40, 0), rayParams)
		-- never into someone's base (it would be safe from everyone but the owner)
		if g and (d == 0 or not inAnyPlot(g.Instance)) then
			land = g.Position
			break
		end
	end
	land = land or (origin - Vector3.new(0, 3, 0))
	local t = now()
	local path = {
		t0 = t,
		from = origin + Vector3.new(0, 3.1, 0),
		flight = 0.55,
		apex = 3.5,
		y = land.Y,
		pts = { { land.X, land.Z, t + 0.55 } },
		expire = t + 0.55 + Breach.DropLife,
	}
	setPathAttributes(model, path)
	model:SetAttribute("Line", carry.line or "Main")
	model:SetAttribute("Site", "")
	model:SetAttribute("Price", 0)
	model:SetAttribute("DroppedBy", player.UserId)
	model:SetAttribute("DropLockUntil", t + Breach.DropLockout)
	model:SetAttribute("BlastedBy", if blaster then blaster.UserId else nil)
	local locks = { [player.UserId] = t + Breach.DropLockout }
	if blaster then
		locks[blaster.UserId] = t + Breach.DropLockout
	end
	S.Model.PlaceAt(model, CFrame.new(land))
	model.Parent = folder
	local e: Loose = {
		uid = carry.uid,
		id = carry.id,
		line = carry.line or "Main",
		site = "",
		path = path,
		price = 0,
		paid = carry.price,
		paidBy = carry.paidBy,
		dropped = true,
		dropBy = player.UserId,
		locks = locks,
		model = model,
	}
	loose[e.uid] = e
	S.Session.Effect("GooberDropped", { uid = e.uid, id = e.id, pos = land, by = player.UserId, reason = reason })
	return e
end

-- nobody grabbed a dropped Goober: it waddles home to whoever dropped it
local function settleDropped(e: Loose)
	loose[e.uid] = nil
	local owner = e.dropBy and Players:GetPlayerByUserId(e.dropBy)
	local st = owner and S.Session.Get(owner)
	-- (its stand was held for it: Session.Used counted it until the line above)
	if st and st.ready and S.Session.HasFreeSlot(owner) then
		st.pendingHome = st.pendingHome or {}
		table.insert(st.pendingHome, { uid = e.uid, id = e.id, price = e.paid or 0, at = os.clock() + 6 })
		S.Session.Toast(owner, ("Nobody grabbed your %s - it's waddling home!"):format(GooberData.ById[e.id].name), "green")
		S.Session.Effect("Vanish", { pos = Breach.PositionAt(e.path, now()), rarity = GooberData.ById[e.id].rarity })
		e.model:Destroy()
	else
		vanish(e)
		-- no stand after all (their stands changed): never lose a paid Goober silently
		if st and st.ready and e.paidBy == owner.UserId and (e.paid or 0) > 0 then
			S.Session.AddCoins(owner, e.paid, true)
			S.Session.Toast(owner, ("No free stand for your %s - refunded $%s."):format(GooberData.ById[e.id].name, Util.Short(e.paid)), "red")
		end
	end
end

-- ---------------------------------------------------------------- cycle
local siteState: { [string]: { stage: number, endsAt: number, typ: string?, folder: Folder } } = {}

local function pickType(): string
	local total = 0
	for _, k in ipairs(Breach.TypeOrder) do
		total += Breach.Types[k].weight
	end
	local r = rng:NextNumber() * total
	for _, k in ipairs(Breach.TypeOrder) do
		r -= Breach.Types[k].weight
		if r <= 0 then
			return k
		end
	end
	return "Slop"
end

local function publish(name: string)
	local s = siteState[name]
	local f = s.folder
	f:SetAttribute("Stage", Breach.Stages[s.stage].key)
	f:SetAttribute("StageEndsAt", s.endsAt)
	f:SetAttribute("Type", s.typ or "")
end

local function blast(name: string)
	local site = Breach.Sites[name]
	local chaos = S.Chaos.Active()
	local baseLuck = if chaos then chaos.luck else 1
	local spawns
	local luck = baseLuck
	if site.types then
		local typ = Breach.Types[siteState[name].typ or "Slop"]
		spawns = typ.spawns
		luck *= typ.luck or 1
	else
		spawns = { [site.line] = site.count or 3 }
	end
	local i = 0
	local best, bestRank = nil, 0
	local RANK = { Epic = 1, Legendary = 2, Secret = 3 }
	for lineName, count in pairs(spawns) do
		for _ = 1, count do
			i += 1
			local e = BreachService.Spawn(BreachService.Roll(lineName, luck, chaos), lineName, name, nil, { delay = i * 0.12, quiet = true })
			local rank = RANK[GooberData.ById[e.id].rarity] or 0
			if rank > bestRank then
				best, bestRank = e, rank
			end
		end
	end
	S.Session.Effect("BreachBlast", { site = name, typ = siteState[name].typ, count = i })
	-- one announcement per blast: its rarest Goober (Epic or better)
	if best then
		S.Session.Effect("RareSpawn", { uid = best.uid, id = best.id, rarity = GooberData.ById[best.id].rarity, line = best.line, site = name })
	end
end

local function anyoneNear(site): boolean
	local f = site.field
	for player in pairs(S.Session.All()) do
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart
		if hrp then
			local p = hrp.Position
			if p.X > f[1] - 40 and p.X < f[2] + 40 and p.Z > f[3] - 40 and p.Z < f[4] + 40 then
				return true
			end
		end
	end
	return false
end

local function stepSite(name: string, t: number)
	local s = siteState[name]
	if t < s.endsAt then
		return
	end
	s.stage = s.stage % #Breach.Stages + 1
	local stage = Breach.Stages[s.stage]
	local seconds = stage.seconds
	local chaos = S.Chaos.Active()
	if chaos and stage.key ~= "Blast" then
		seconds *= chaos.intervalMult -- chaos events erupt more often
	end
	-- island cauldrons rest while nobody is near them (no Goobers for nobody)
	local site = Breach.Sites[name]
	if site.spooky and stage.key == "Charging" and not anyoneNear(site) then
		s.stage = 1
		s.endsAt = t + 2
		s.typ = nil
		publish(name)
		return
	end
	s.endsAt = t + seconds * (Breach.Sites[name].cycleMult or 1)
	if stage.key == "Charging" and Breach.Sites[name].types then
		s.typ = pickType()
	elseif stage.key == "Unstable" then
		local typ = s.typ and Breach.Types[s.typ]
		if typ and typ.announce then
			S.Session.Effect("BreachAnnounce", { site = name, typ = s.typ })
		end
	elseif stage.key == "Blast" then
		blast(name)
	end
	publish(name)
end

-- leaving: Goobers you dropped stay in the field for anyone to grab (leaving is
-- never a safe way out of a chase). You get the usual release refund for the
-- ones you paid for. When the server is shutting down they go home instead.
function BreachService.OnRemoving(player: Player, shuttingDown: boolean?)
	local st = S.Session.Get(player)
	for _, e in pairs(loose) do
		if e.dropped and e.dropBy == player.UserId then
			if shuttingDown then
				loose[e.uid] = nil
				e.model:Destroy()
				if st then
					st.pendingHome = st.pendingHome or {}
					table.insert(st.pendingHome, { uid = e.uid, id = e.id, price = e.paid or 0, at = 0 })
				end
			else
				e.dropBy = nil -- nobody to waddle home to now
				e.model:SetAttribute("DroppedBy", nil)
				if st and e.paidBy == player.UserId and (e.paid or 0) > 0 then
					local refund = math.floor(e.paid * Config.SellRefund)
					S.Session.AddCoins(player, refund, true)
					e.refundedTo, e.refundAmt = player.UserId, refund
				end
			end
		end
	end
end

-- personal drops: the Breach spits one at you, landing on your side of the plaza
local function personalDrops()
	local chaos = S.Chaos.Active()
	for player, st in pairs(S.Session.All()) do
		if st.ready and os.clock() >= st.nextDropAt then
			local tutorial = st.data.tutorial == 0
			st.nextDropAt = os.clock() + (if tutorial then 12 else Config.PersonalDrop.interval)
			local gid
			if tutorial then
				gid = "G01_Blorp" -- guaranteed affordable first Goober
			else
				local luck = S.Session.PersonalLuck(player) * (if chaos then chaos.luck else 1)
				gid = BreachService.Roll("Main", luck, chaos)
			end
			local plot = S.Plot.Get(player)
			local near = plot and plot:GetPivot().Position or nil
			BreachService.Spawn(gid, "Main", "Central", player, { near = near })
			S.Session.Notify(player, "PersonalDrop", { id = gid })
		end
	end
end

function BreachService.Start()
	-- landing spots need the map: sample once it's there
	local total = 0
	for name in pairs(Breach.Sites) do
		total += sampleSite(name)
	end
	print(("[Breach] %d landing spots across %d sites"):format(total, (function()
		local n = 0
		for _ in pairs(Breach.Sites) do
			n += 1
		end
		return n
	end)()))
	local t0 = now()
	local k = 0
	for name in pairs(Breach.Sites) do
		k += 1
		local f = Instance.new("Folder")
		f.Name = name
		f:SetAttribute("Center", Breach.Sites[name].center)
		f.Parent = stateFolder
		-- stagger the sites so the island cauldrons don't all erupt together
		siteState[name] = { stage = 1, endsAt = t0 + 2 + k * 1.7, typ = nil, folder = f }
		publish(name)
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = now()
			for name in pairs(siteState) do
				stepSite(name, t)
			end
			personalDrops()
			for uid, c in pairs(claimed) do
				if os.clock() - c.t > 5 then
					claimed[uid] = nil
				end
			end
			for _, e in pairs(loose) do
				if t >= e.path.expire then
					if e.dropped then
						settleDropped(e)
					else
						vanish(e)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, e in pairs(loose) do
			if e.reservedFor == player.UserId then
				loose[e.uid] = nil
				e.model:Destroy()
			end
		end
	end)
end

return BreachService

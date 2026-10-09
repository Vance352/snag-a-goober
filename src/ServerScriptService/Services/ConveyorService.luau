--[[
	ConveyorService - spawns Goobers onto the Main and Gold lines and handles
	snag requests.

	The server never moves belt Goobers. Each one stores its spawn time and
	speed; its position is a pure function of time (positionOf), which clients
	use to animate it and the server uses to validate snags. That keeps the
	network quiet no matter how many Goobers are riding.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)

local ConveyorService = {}
local S

type BeltGoober = {
	uid: string,
	id: string,
	line: string,
	spawnT: number,
	speed: number,
	startX: number,
	dir: number,
	z: number,
	reservedFor: number?,
	price: number,
	model: Model,
}

local belt: { [string]: BeltGoober } = {}
local folder: Folder
local M = Config.Map
local LENGTH = M.beltEndX - M.beltStartX

local rng = Random.new()

function ConveyorService.Init(registry)
	S = registry
	folder = Instance.new("Folder")
	folder.Name = "BeltGoobers"
	folder.Parent = workspace
end

local function now()
	return workspace:GetServerTimeNow()
end

function ConveyorService.PositionOf(b: BeltGoober, t: number?): Vector3
	local dt = (t or now()) - b.spawnT
	return Vector3.new(b.startX + b.dir * b.speed * dt, M.beltY, b.z)
end

-- Weighted rarity roll, then a uniform pick inside that rarity.
function ConveyorService.Roll(lineName: string, luck: number, chaos): string
	local odds = Util.Odds(lineName, luck, chaos and chaos.secretMult)
	if chaos and chaos.chaosGoobChance and rng:NextNumber() < chaos.chaosGoobChance then
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
	local pool = GooberData.ByRarity[picked]
	if not pool or #pool == 0 then
		pool = GooberData.ByRarity.Common
	end
	return pool[rng:NextInteger(1, #pool)].id
end

function ConveyorService.Spawn(gid: string, lineName: string, reservedFor: Player?): BeltGoober
	local line = Config.Lines[lineName]
	local dir = if lineName == "Main" then 1 else -1
	local startX = if dir == 1 then M.beltStartX else M.beltEndX
	local z = if lineName == "Main" then M.mainZ else M.goldZ
	local uid = S.Data.NewUid()
	local model = S.Model.Build(gid, uid, "belt")
	local b: BeltGoober = {
		uid = uid,
		id = gid,
		line = lineName,
		spawnT = now(),
		speed = line.speed,
		startX = startX,
		dir = dir,
		z = z,
		reservedFor = reservedFor and reservedFor.UserId,
		-- Personal Drops are half price for their owner
		price = if reservedFor then math.floor(GooberData.ById[gid].price * Config.PersonalDrop.discount) else GooberData.ById[gid].price,
		model = model,
	}
	model:SetAttribute("SpawnT", b.spawnT)
	model:SetAttribute("Speed", b.speed)
	model:SetAttribute("StartX", startX)
	model:SetAttribute("Dir", dir)
	model:SetAttribute("BeltZ", z)
	model:SetAttribute("BeltY", M.beltY)
	model:SetAttribute("Line", lineName)
	model:SetAttribute("Price", b.price)
	-- half the Goobers face each row of bases, so every base sees faces
	local face = if rng:NextNumber() < 0.5 then 1 else -1
	model:SetAttribute("Face", face)
	if reservedFor then
		model:SetAttribute("ReservedFor", reservedFor.UserId)
		model:SetAttribute("ReservedName", reservedFor.DisplayName)
		local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
		local info = tag and tag:FindFirstChild("Info")
		if info then
			info.Text = ("$%s (50%% OFF)  •  +%s/s"):format(Util.Short(b.price), Util.Short(GooberData.ById[gid].income))
		end
	end
	local pos = ConveyorService.PositionOf(b)
	S.Model.PlaceAt(model, CFrame.lookAt(pos, pos + Vector3.new(0, 0, face)))
	model.Parent = folder
	belt[uid] = b
	local rarity = GooberData.ById[gid].rarity
	if rarity == "Legendary" or rarity == "Secret" or rarity == "Epic" then
		S.Session.Effect("RareSpawn", { uid = uid, id = gid, rarity = rarity, line = lineName })
	end
	return b
end

function ConveyorService.Get(uid: string): BeltGoober?
	return belt[uid]
end

function ConveyorService.Remove(uid: string)
	local b = belt[uid]
	if b then
		belt[uid] = nil
	end
end

function ConveyorService.All()
	return belt
end

-- ---------------------------------------------------------------- snag
local function fail(player: Player, msg: string)
	S.Session.Notify(player, "Error", { text = msg })
end

function ConveyorService.Snag(player: Player, uid: any)
	if type(uid) ~= "string" or #uid > 40 then
		return
	end
	if not S.Session.RateOk(player, "Snag", 5, 1) then
		return
	end
	local st = S.Session.Get(player)
	local b = belt[uid]
	if not st or not st.ready or not b then
		return
	end
	if st.carry then
		return fail(player, "Your hands are full! Bring that Goober home first.")
	end
	if b.reservedFor and b.reservedFor ~= player.UserId then
		return fail(player, "That Goober is someone's Personal Drop!")
	end
	local line = Config.Lines[b.line]
	if st.data.level < line.levelRequired then
		return fail(player, ("The Gold Line unlocks at Level %d."):format(line.levelRequired))
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if not S.MoveGuard.Plausible(player) then
		return fail(player, "Whoa, slow down!")
	end
	-- allow for a little latency: check against the position slightly in the past
	local p0 = ConveyorService.PositionOf(b)
	local p1 = ConveyorService.PositionOf(b, now() - 0.4)
	local dist = math.min((hrp.Position - p0).Magnitude, (hrp.Position - p1).Magnitude)
	if dist > Config.SnagRange then
		return fail(player, "Get closer to snag it!")
	end
	if not S.Session.HasFreeSlot(player) then
		return fail(player, "Your base is full! Sell a Goober or buy More Stands.")
	end
	local def = GooberData.ById[b.id]
	if not S.Session.Spend(player, b.price) then
		return fail(player, ("You need $%s to snag %s."):format(Util.Short(b.price), def.name))
	end
	-- commit: the belt Goober becomes the player's carried Goober
	belt[uid] = nil
	S.Carry.Begin(player, { uid = uid, id = b.id, source = "belt", model = b.model, price = b.price })
	st.data.stats.snags += 1
	S.Session.Effect("Snagged", { id = b.id, rarity = def.rarity, by = player.UserId, pos = p0 })
	S.Progress.TutorialEvent(player, "Snagged")
end

-- --------------------------------------------------------------- loops
function ConveyorService.Start()
	local acc = { Main = 0, Gold = 0 }
	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = os.clock()
			local dt = t - last
			last = t
			local chaos = S.Chaos.Active()
			for lineName, line in pairs(Config.Lines) do
				acc[lineName] += dt
				local interval = line.interval * (if chaos then chaos.intervalMult else 1)
				if acc[lineName] >= interval then
					acc[lineName] = 0
					local luck = if chaos then chaos.luck else 1
					ConveyorService.Spawn(ConveyorService.Roll(lineName, luck, chaos), lineName, nil)
				end
			end
			-- personal drops
			for player, st in pairs(S.Session.All()) do
				if st.ready and t >= st.nextDropAt then
					local tutorial = st.data.tutorial == 0
					st.nextDropAt = t + (if tutorial then 12 else Config.PersonalDrop.interval)
					local gid
					if tutorial then
						gid = "G01_Blorp" -- guaranteed affordable first Goober
					else
						local luck = S.Session.PersonalLuck(player) * (if chaos then chaos.luck else 1)
						gid = ConveyorService.Roll("Main", luck, chaos)
					end
					ConveyorService.Spawn(gid, "Main", player)
					S.Session.Notify(player, "PersonalDrop", { id = gid })
				end
			end
			-- despawn at the end of the line
			local nowT = now()
			for uid, b in pairs(belt) do
				if nowT - b.spawnT > LENGTH / b.speed then
					belt[uid] = nil
					b.model:Destroy()
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for uid, b in pairs(belt) do
			if b.reservedFor == player.UserId then
				belt[uid] = nil
				b.model:Destroy()
			end
		end
	end)
end

return ConveyorService

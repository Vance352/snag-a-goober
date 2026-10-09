--[[
	CombatService - the Goober Blaster.

	Players splat a Goober CARRIER to knock the Goober loose. The client only
	says "I fired, aiming this way"; the server picks the target and decides
	everything (range, aim cone, line of sight, cooldowns, protections).

	A hit:
	  * staggers the carrier briefly and pushes them a few studs (server-side
	    move, so it can't be faked or abused to fling people);
	  * a Breach Goober drops to the ground where ANYONE can race to grab it
	    (the attacker doesn't get it automatically - see BreachService);
	  * a Goober being stolen from a base goes straight back to its owner
	    (a hit can never move a Goober that's stored on a stand).

	Only carriers can be hit. Protections: your own base, spawning, right
	after a snag, right after being hit, the same attacker repeating on you,
	and new players (below Config.Combat.minLevel / mid-tutorial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

local CombatService = {}
local S
local C = Config.Combat

-- per-player combat state (not saved)
local state: { [Player]: { nextAt: number, immuneUntil: number, spawnSafeUntil: number, lastHitOn: { [number]: number } } } = {}

function CombatService.Init(registry)
	S = registry
end

local function cs(player: Player)
	local t = state[player]
	if not t then
		t = { nextAt = 0, immuneUntil = 0, spawnSafeUntil = 0, lastHitOn = {} }
		state[player] = t
	end
	return t
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function veteran(st): boolean
	return st.data.level >= C.minLevel and st.data.tutorial == Tutorial.DONE
end

-- can `attacker` hit `target` right now? (reason for the attacker's feedback)
function CombatService.CanHit(attacker: Player, target: Player): (boolean, string?)
	if attacker == target then
		return false, nil
	end
	local tst = S.Session.Get(target)
	if not tst or not tst.ready or not tst.carry then
		return false, nil -- only carriers
	end
	local tc = cs(target)
	local t = os.clock()
	if not veteran(tst) then
		return false, "New players are protected."
	end
	if t < tc.spawnSafeUntil then
		return false, "They just spawned - spawn protection!"
	end
	if t < tc.immuneUntil then
		return false, "They were just hit - give them a second!"
	end
	if t < (tst.carry.protectUntil or 0) then
		return false, "They only just grabbed it!"
	end
	if t < (cs(attacker).lastHitOn[target.UserId] or 0) then
		return false, "You just hit them - go after someone else!"
	end
	local hrp = hrpOf(target)
	local plot = S.Plot.Get(target)
	if not hrp then
		return false, nil
	end
	if plot and S.Plot.Inside(plot, hrp.Position, 2) then
		return false, "Safe inside their own base!"
	end
	return true, nil
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearShot(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	losParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, losParams)
	return hit == nil
end

local function fail(player: Player, msg: string)
	S.Session.Notify(player, "Error", { text = msg })
end

-- the attacker fired; aim = the direction they were aiming (unit vector)
function CombatService.Blast(attacker: Player, aim: any)
	if not S.Session.RateOk(attacker, "Blast", 4, 1) then
		return
	end
	local ast = S.Session.Get(attacker)
	if not ast or not ast.ready then
		return
	end
	local ahrp = hrpOf(attacker)
	if not ahrp then
		return
	end
	if ast.carry then
		return -- your hands are full
	end
	if not veteran(ast) then
		return fail(attacker, ("Reach Level %d to use the Goober Blaster!"):format(C.minLevel))
	end
	local ac = cs(attacker)
	local t = os.clock()
	if t < ac.nextAt then
		return -- still cooling down (the client shows this)
	end
	ac.nextAt = t + C.cooldown
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 0.1 or aim.Magnitude > 10 then
		aim = ahrp.CFrame.LookVector
	end
	aim = Vector3.new(aim.X, math.clamp(aim.Y, -0.6, 0.6), aim.Z).Unit
	-- everyone sees the splat fly (the shooter has already drawn their own)
	S.Session.Effect("BlastFx", { by = attacker.UserId, from = ahrp.Position, dir = aim })
	-- pick the closest valid carrier inside range, in front of the aim, in sight
	local eye = ahrp.Position + Vector3.new(0, 1.4, 0)
	local best, bestD, why = nil, math.huge, nil
	for _, target in ipairs(Players:GetPlayers()) do
		local thrp = target ~= attacker and hrpOf(target)
		if thrp then
			local off = thrp.Position - ahrp.Position
			local d = off.Magnitude
			if d <= C.range and d > 0.1 and off.Unit:Dot(aim) >= C.cone then
				local ok, reason = CombatService.CanHit(attacker, target)
				if ok then
					local ignore = { attacker.Character, target.Character, workspace:FindFirstChild("LooseGoobers") }
					if clearShot(eye, thrp.Position + Vector3.new(0, 1, 0), ignore) and d < bestD then
						best, bestD = target, d
					end
				elseif reason and not why then
					why = reason
				end
			end
		end
	end
	if not best then
		if why then
			S.Session.Notify(attacker, "BlastBlocked", { text = why })
		end
		return
	end
	CombatService.ApplyHit(attacker, best)
end

function CombatService.ApplyHit(attacker: Player, target: Player)
	local tst = S.Session.Get(target)
	local ast = S.Session.Get(attacker)
	local ahrp, thrp = hrpOf(attacker), hrpOf(target)
	if not tst or not ast or not ahrp or not thrp or not tst.carry then
		return
	end
	local t = os.clock()
	cs(target).immuneUntil = t + C.hitImmunity
	cs(attacker).lastHitOn[target.UserId] = t + C.sameTarget
	local flat = Vector3.new(thrp.Position.X - ahrp.Position.X, 0, thrp.Position.Z - ahrp.Position.Z)
	local dir = if flat.Magnitude > 0.05 then flat.Unit else ahrp.CFrame.LookVector
	local carried = tst.carry
	local gid = carried.id
	if carried.source == "belt" then
		S.Breach.DropFromCarry(target, dir, "blasted")
	else
		-- a Goober stolen from a base: the theft fails and it goes home to its owner
		S.Steal.Fail(target, "blasted")
	end
	-- stagger + a short shove (raycast so nobody is pushed through a wall)
	tst.stunnedUntil = t + C.stagger
	S.Character.ApplySpeed(target)
	task.delay(C.stagger + 0.05, function()
		if target.Parent then
			S.Character.ApplySpeed(target)
		end
	end)
	losParams.FilterDescendantsInstances = { target.Character, attacker.Character, workspace:FindFirstChild("LooseGoobers") }
	local hit = workspace:Raycast(thrp.Position, dir * (C.knockback + 1.5), losParams)
	local push = if hit then math.max(0, (hit.Position - thrp.Position).Magnitude - 1.5) else C.knockback
	if push > 0.5 then
		local dest = thrp.Position + dir * push
		S.MoveGuard.ServerMove(target, CFrame.lookAt(dest, dest - dir))
	end
	ast.data.stats.hits += 1
	ast.dirty = true
	S.Session.Effect("BlastHit", { by = attacker.UserId, target = target.UserId, pos = thrp.Position, id = gid })
	S.Session.Notify(attacker, "HitConfirm", { target = target.DisplayName, id = gid, stolen = carried.source == "steal" })
	S.Session.Notify(target, "GotBlasted", { by = attacker.DisplayName, id = gid, stolen = carried.source == "steal" })
end

-- spawn protection
function CombatService.OnSpawn(player: Player)
	cs(player).spawnSafeUntil = os.clock() + C.spawnProtection
	player:SetAttribute("SpawnSafeUntil", workspace:GetServerTimeNow() + C.spawnProtection)
end

function CombatService.Start()
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
		for _, t in pairs(state) do
			t.lastHitOn[player.UserId] = nil
		end
	end)
end

return CombatService

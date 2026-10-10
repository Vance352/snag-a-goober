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
-- recent positions of every character (lag compensation: what the shooter saw)
local history: { [Player]: { { t: number, pos: Vector3 } } } = {}
local HISTORY_SPAN = 0.25 -- (the most lag a shot is forgiven for)
local HISTORY_KEEP = HISTORY_SPAN + 0.3 -- (+ the facing re-check delay)

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
	local thrp0 = hrpOf(target)
	if t < (tst.carry.protectUntil or 0) and (not thrp0 or (thrp0.Position - (tst.carry.origPos or thrp0.Position)).Magnitude < C.graceMove) then
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
	-- you shoot where you're facing (within 60 degrees): the client turns you
	-- as it fires, so if the turn hasn't reached the server yet the shot is
	-- checked again a moment later - no 360-degree auto-aim
	local function facing(dir: Vector3): (boolean, Vector3)
		local r = hrpOf(attacker)
		local look = if r then r.CFrame.LookVector else dir
		local flatAim = Vector3.new(dir.X, 0, dir.Z)
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatAim.Magnitude < 0.05 or flatLook.Magnitude < 0.05 then
			return true, dir
		end
		return flatAim.Unit:Dot(flatLook.Unit) >= C.facing, flatLook.Unit
	end
	-- Sprint Boots rest for a moment after firing
	if ast.passes.SprintBoots then
		ast.bootsRestUntil = t + C.bootsRest
		S.Character.ApplySpeed(attacker)
		task.delay(C.bootsRest + 0.05, function()
			if attacker.Parent then
				S.Character.ApplySpeed(attacker)
			end
		end)
	end
	-- everyone sees the splat fly (the shooter has already drawn their own)
	S.Session.Effect("BlastFx", { by = attacker.UserId, from = ahrp.Position, dir = aim })
	local ok = facing(aim)
	if ok then
		CombatService._resolve(attacker, aim)
	else
		task.delay(0.2, function()
			local ok2, straight = facing(aim)
			-- (still judged as of the moment they fired)
			local st = S.Session.Get(attacker)
			if attacker.Parent and hrpOf(attacker) and st and not st.carry then
				CombatService._resolve(attacker, if ok2 then aim else straight, 0.2)
			end
		end)
	end
end

-- pick the closest valid carrier inside range, in front of the aim, in sight
function CombatService._resolve(attacker: Player, aim: Vector3, late: number?)
	local ahrp = hrpOf(attacker)
	if not ahrp then
		return
	end
	-- a re-checked (late) shot is judged from where everyone was when it was fired
	local from = if late then (CombatService.PositionAgo(attacker, late) or ahrp.Position) else ahrp.Position
	local eye = from + Vector3.new(0, 1.4, 0)
	local best, bestD, why = nil, math.huge, nil
	-- where targets were when the shooter fired (their ping ago, capped)
	local lag = math.clamp(attacker:GetNetworkPing(), 0, HISTORY_SPAN) + (late or 0)
	for _, target in ipairs(Players:GetPlayers()) do
		local thrp = target ~= attacker and hrpOf(target)
		if thrp then
			-- accept either where they are now or where the shooter saw them
			local seen = CombatService.PositionAgo(target, lag) or thrp.Position
			local pick, d = nil, math.huge
			for _, p in ipairs(if late then { seen } else { thrp.Position, seen }) do
				local off = p - from
				local dd = off.Magnitude
				if dd <= C.range and dd > 0.1 and off.Unit:Dot(aim) >= C.cone and dd < d then
					pick, d = p, dd
				end
			end
			if pick then
				local ok, reason = CombatService.CanHit(attacker, target)
				if ok then
					local ignore = { attacker.Character, target.Character, workspace:FindFirstChild("LooseGoobers") }
					if clearShot(eye, pick + Vector3.new(0, 1, 0), ignore) and d < bestD then
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
		-- it flies off to one side of the shot: the carrier (pushed away) and the
		-- shooter end up about the same distance from it, and both wait the same
		-- lockout - a fair race, which anyone else nearby can also win
		local side = Vector3.new(-dir.Z, 0, dir.X) * (if math.random() < 0.5 then -1 else 1)
		S.Breach.DropFromCarry(target, (side + dir * 0.25).Unit, "blasted", attacker, (-side + dir * 0.25).Unit)
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

-- where `player` was `ago` seconds back (nil if no history yet)
function CombatService.PositionAgo(player: Player, ago: number): Vector3?
	local h = history[player]
	if not h or #h == 0 then
		return nil
	end
	local want = os.clock() - ago
	local best = h[#h]
	for i = #h, 1, -1 do
		best = h[i]
		if h[i].t <= want then
			break
		end
	end
	return best.pos
end

function CombatService.Start()
	task.spawn(function()
		while true do
			task.wait(0.05)
			local t = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do
				local hrp = hrpOf(p)
				if hrp then
					local h = history[p]
					if not h then
						h = {}
						history[p] = h
					end
					table.insert(h, { t = t, pos = hrp.Position })
					while #h > 0 and t - h[1].t > HISTORY_KEEP do
						table.remove(h, 1)
					end
				else
					history[p] = nil
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
		history[player] = nil

		for _, t in pairs(state) do
			t.lastHitOn[player.UserId] = nil
		end
	end)
end

return CombatService

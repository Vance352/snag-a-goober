--[[
	MoveGuard - server-side sanity checks on client-replicated movement.

	Characters are physically simulated by their own client, so an exploiter
	can teleport or speed-hack. MoveGuard uses one rule everywhere:

	    "Could you have walked here?"

	  * Every position is checked against EVERY trusted sample from the last
	    10 s: the distance must fit the server's WalkSpeed (+8%) times the
	    time since that sample (+0.5 s for replication delay). A position is
	    only trusted (recorded) after passing that check, so there is no
	    unchecked window to abuse.
	  * Lag credit: when a walking client's connection stalls, the server
	    sees it frozen in place while its replicated velocity still says
	    "walking", then catching up in a few bursts. Only that pattern fills a
	    sample's "bank" (seconds behind a full-speed walker, max 1.6 s);
	    simply standing still earns nothing. (A client that fakes the stall
	    pattern can at best turn stall time into the same walk distance -
	    never faster than walking.) Moving faster than walking spends the bank
	    (x1.5), credit is capped at the newest bank + 0.25 s and only spent
	    by a catch-up heading the way the player was walking. After the burst
	    the frozen stall samples are dropped; the samples from before the
	    stall still bound the whole trip to walking speed.
	  * On a violation the player is "in debt": the trusted samples freeze,
	    and debt clears only once the current position is reachable by
	    walking from every one of them. Multi-hop teleports and speed hacks
	    therefore gain nothing. After 30 s in debt the server moves the
	    player back to the last trusted spot (it never trusts where they are).
	  * Respawns and server teleports re-anchor at the server's own target
	    with a 1 s settle window in which only positions near the target count
	    and nothing can complete.
	  * CarryStep() applies the same rule to a carry's own trail (at the
	    real, slowed walk speed +5%) and checks hovering. On a violation it
	    returns the last trusted sample, so the carry's walking clock can
	    restart from there.
]]

local Players = game:GetService("Players")

local MoveGuard = {}
local S

local ACTION_SLACK = 1.08 -- free-roam speed tolerance
local CARRY_SLACK = 1.05 -- carry speed tolerance
local DIST_SLACK = 2.5 -- studs of physics jitter
local REPL_LAG = 0.5 -- seconds: replication delay varies (a catch-up after a freeze collapses it)
local HITCH_CREDIT = 1.6 -- seconds of standing still credited for a lag catch-up
local BANK_SPARE = 0.25 -- old samples keep at most (newest bank + this) of their credit
local STALL_VEL = 0.4 -- replicated speed (x walk speed) that marks a frozen position as a stall
local REBASE_SPEND = 0.3 -- a sample that spends this much bank is a catch-up burst
local STALL_MOVE = 1 -- studs per sample: a stall is a position that doesn't move
local STALL_DIR = 0.7 -- a catch-up must head this close (cosine) to the stalled walking direction
local HISTORY = 10.0 -- long window, so the constant slacks don't let a steady speed hack through
local SETTLE_TIME = 1.0
local SETTLE_RADIUS = 12
local DEBT_FORGIVE = 30

-- bank: seconds the player is behind a full-speed walker (standing still adds,
-- moving faster than walking spends), capped at HITCH_CREDIT
export type Sample = { t: number, pos: Vector3, bank: number, speed: number, dir: Vector3? }
type Guard = {
	history: { Sample },
	frozen: { Sample }?,
	debt: boolean,
	debtSince: number,
	settleUntil: number,
	settlePos: Vector3?,
	flaggedAt: number,
	lastFlag: string?,
	returning: boolean?,
}
local guards: { [Player]: Guard } = {}

function MoveGuard.Init(registry)
	S = registry
end

local function guardOf(player: Player): Guard
	local g = guards[player]
	if not g then
		g = { history = {}, frozen = nil, debt = false, debtSince = 0, settleUntil = 0, settlePos = nil, flaggedAt = -100, lastFlag = nil }
		guards[player] = g
	end
	return g
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The server's own WalkSpeed (clients can't change it on the server), with a
-- floor so a brief stun doesn't count as zero.
function MoveGuard.MaxSpeed(player: Player): number
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return math.max(hum and hum.WalkSpeed or 16, 8)
end

local function pingSlack(player: Player, speed: number): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	ping = if ok and type(ping) == "number" then ping else 0.1
	return speed * math.clamp(ping, 0.05, 0.2)
end

-- Seconds a legit carrier needs to walk from a to b (carries can't finish sooner).
function MoveGuard.MinTravelTime(player: Player, a: Vector3, b: Vector3): number
	local d = (flat(a) - flat(b)).Magnitude
	return math.max(0, d / (MoveGuard.MaxSpeed(player) * 1.05) - 0.1)
end

function MoveGuard.Settling(player: Player): boolean
	return os.clock() < guardOf(player).settleUntil
end

-- The lag bank a sample at `pos` would have, carried forward from the newest
-- one, plus the walking direction it was earned in. `vel` is the server's
-- replicated horizontal velocity of the character.
local function bankAt(list: { Sample }, pos: Vector3, speed: number, vel: Vector3): (number, Vector3?)
	local prev = list[#list]
	if not prev then
		return 0, nil
	end
	local spd = math.max(speed, prev.speed)
	local moved = (flat(pos) - flat(prev.pos)).Magnitude
	local gain = (os.clock() - prev.t) - moved / spd
	if gain < 0 then
		local left = math.max(0, prev.bank + 1.5 * gain) -- faster than walking: spend
		return left, if left > 0 then prev.dir else nil
	elseif moved < STALL_MOVE and vel.Magnitude >= STALL_VEL * spd then
		return math.min(HITCH_CREDIT, prev.bank + gain), vel.Unit -- stalled mid-walk: earn
	end
	return prev.bank, prev.dir
end

local function sample(list: { Sample }, pos: Vector3, speed: number, vel: Vector3): Sample
	local bank, dir = bankAt(list, pos, speed, vel)
	return { t = os.clock(), pos = pos, bank = bank, speed = speed, dir = dir }
end

-- Record a trusted sample. After a catch-up burst the frozen stall samples
-- (the ones that earned credit) are dropped: they were never real positions.
-- The samples from before the stall stay, so over the whole window nobody
-- gets anywhere faster than walking, however often they stall.
local function record(list: { Sample }, smp: Sample): { Sample }
	local prev = list[#list]
	if prev and prev.bank - smp.bank >= REBASE_SPEND then
		local kept = {}
		for _, x in ipairs(list) do
			if x.bank <= 0.05 then
				table.insert(kept, x)
			end
		end
		table.insert(kept, smp)
		return kept
	end
	table.insert(list, smp)
	return list
end

local function hvel(part: BasePart): Vector3
	return flat(part.AssemblyLinearVelocity)
end

-- Reachable from every sample in `list`? Uses the highest walk speed in force
-- since each sample, so a speed drop (e.g. becoming a slowed thief) doesn't
-- make earlier legit walking look fast.
local function reachable(list: { Sample }, pos: Vector3, speedNow: number, slack: number, extra: number): (boolean, number)
	local now = os.clock()
	local speed = speedNow
	local worst = 0
	-- a speed hack spends the bank, so every sample's credit shrinks with it
	local newest = list[#list]
	local cap = (if newest then newest.bank else 0) + BANK_SPARE
	if newest and newest.bank > 0 and newest.dir then
		-- a real catch-up continues the way the player was walking when the
		-- connection stalled; a jump anywhere else gets no lag credit
		local move = flat(pos) - flat(newest.pos)
		if move.Magnitude > DIST_SLACK and move.Unit:Dot(newest.dir) < STALL_DIR then
			cap = 0
		end
	end
	for i = #list, 1, -1 do
		local s = list[i]
		speed = math.max(speed, s.speed)
		local dt = now - s.t + REPL_LAG + math.min(s.bank, cap)
		local d = (flat(pos) - flat(s.pos)).Magnitude
		local over = d - (speed * slack * dt + DIST_SLACK + extra)
		if over > worst then
			worst = over
		end
	end
	return worst <= 0, worst
end

local function prune(list: { Sample }, keep: number)
	local now = os.clock()
	while #list > 1 and now - list[1].t > keep do
		table.remove(list, 1)
	end
end

local function enterDebt(player: Player, g: Guard, excess: number, reason: string)
	if g.debt then
		return
	end
	g.debt = true
	g.debtSince = os.clock()
	g.flaggedAt = os.clock()
	g.lastFlag = ("%s +%.0f studs"):format(reason, excess)
	-- every sample we trusted stays binding until the debt is walked off
	g.frozen = table.clone(g.history)
	local st = S.Session.Get(player)
	if st and st.carry and st.carry.source == "steal" then
		S.Steal.Offence(player, g.frozen[#g.frozen], excess)
	end
end

local function check(player: Player, g: Guard, pos: Vector3): boolean
	local speed = MoveGuard.MaxSpeed(player)
	if g.debt then
		local frozen = g.frozen or {}
		if #frozen == 0 or reachable(frozen, pos, speed, ACTION_SLACK, 0) then
			g.debt = false
			g.history = frozen
			g.frozen = nil
			return true
		end
		if os.clock() - g.debtSince > DEBT_FORGIVE and not g.returning then
			-- safety valve for someone stuck in debt: put them back where we
			-- last trusted them (never trust where they are now)
			g.returning = true
			local back = frozen[#frozen].pos
			task.defer(function()
				g.returning = false
				if g.debt and player.Parent then
					MoveGuard.ServerMove(player, CFrame.new(back))
				end
			end)
		end
		return false
	end
	local ok, excess = reachable(g.history, pos, speed, ACTION_SLACK, pingSlack(player, speed))
	if not ok then
		enterDebt(player, g, excess, "move")
		return false
	end
	return true
end

-- True if the player's current position is trustworthy right now.
function MoveGuard.Plausible(player: Player): boolean
	local g = guardOf(player)
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	if os.clock() < g.settleUntil then
		return g.settlePos ~= nil and (flat(hrp.Position) - flat(g.settlePos)).Magnitude <= SETTLE_RADIUS
	end
	return check(player, g, hrp.Position)
end

function MoveGuard.InDebt(player: Player): boolean
	return guardOf(player).debt
end

function MoveGuard.FlaggedSince(player: Player, t: number): boolean
	return guardOf(player).flaggedAt >= t
end

function MoveGuard.LastFlag(player: Player): string?
	return guardOf(player).lastFlag
end

-- How far beyond the allowance counts as a clear shortcut, not lag (studs).
MoveGuard.TELEPORT_EXCESS = 10

-- Studio test harness only: a snapshot of the guard state.
function MoveGuard.Debug(player: Player)
	local g = guardOf(player)
	local now = os.clock()
	local hist = {}
	for _, h in ipairs(g.history) do
		table.insert(hist, ("%.2f/%.2f@%.0f,%.0f"):format(now - h.t, h.bank, h.pos.X, h.pos.Z))
	end
	return { debt = g.debt, lastFlag = g.lastFlag, flaggedAgo = now - g.flaggedAt, settling = now < g.settleUntil, history = hist, frozen = g.frozen and #g.frozen or 0 }
end

local function anchorAt(player: Player, g: Guard, pos: Vector3)
	local now = os.clock()
	g.history = { { t = now, pos = pos, bank = 0, speed = MoveGuard.MaxSpeed(player) } }
	g.frozen = nil
	g.debt = false
	g.settleUntil = now + SETTLE_TIME
	g.settlePos = pos
end

-- A new character: trust only where the server spawned it.
function MoveGuard.OnSpawn(player: Player)
	local hrp = hrpOf(player)
	if hrp then
		anchorAt(player, guardOf(player), hrp.Position)
	end
end

-- Move a character on the server. Trust re-anchors at the target; carries
-- shift their recorded path by the same offset so validation continues.
function MoveGuard.ServerMove(player: Player, cf: CFrame)
	local c = player.Character
	local hrp = hrpOf(player)
	if not c then
		return
	end
	if hrp then
		local delta = cf.Position - hrp.Position
		local st = S.Session.Get(player)
		local carry = st and st.carry
		if carry then
			if carry.trail then
				for _, s in ipairs(carry.trail) do
					s.pos += delta
				end
			end
			if carry.ground then
				carry.ground.pos += delta
			end
			if carry.startPos then
				carry.startPos += delta
			end
		end
	end
	c:PivotTo(cf)
	anchorAt(player, guardOf(player), cf.Position)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Per-tick validation of a carry's path (call ~10x/s while carrying).
-- Returns false if the carrier teleported, sped or hovered, plus the last
-- trusted sample (where the walking clock should restart from), if known, and
-- how far beyond the allowance they were (studs).
function MoveGuard.CarryStep(player: Player, carry): (boolean, Sample?, number?)
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	local g = guardOf(player)
	local now = os.clock()
	local pos = hrp.Position
	if g.debt then
		local f = g.frozen
		return false, f and f[#f], 0 -- (the excess was reported when the debt began)
	end
	if now < g.settleUntil and g.settlePos and (flat(pos) - flat(g.settlePos)).Magnitude > SETTLE_RADIUS then
		return true -- server move still replicating; completion is blocked by Settling()
	end
	local speed = MoveGuard.MaxSpeed(player)
	local trail = carry.trail
	if not trail then
		carry.trail = { { t = now, pos = pos, bank = 0, speed = speed } }
		carry.airSince = nil
		carry.ground = table.clone(carry.trail[1])
		return true
	end
	local last = trail[#trail]
	local ok, excess = reachable(trail, pos, speed, CARRY_SLACK, pingSlack(player, speed))
	if not ok then
		return false, last, excess
	end
	-- hovering: more than 12 studs above whatever is below for > 0.6 s
	rayParams.FilterDescendantsInstances = { player.Character, carry.model }
	local hit = workspace:Raycast(pos, Vector3.new(0, -40, 0), rayParams)
	local height = if hit then pos.Y - hit.Position.Y else 40
	local s = sample(trail, pos, speed, hvel(hrp))
	if height > 12 then
		carry.airSince = carry.airSince or now
		if now - carry.airSince > 0.6 then
			return false, carry.ground, math.huge -- flying is never lag
		end
	else
		carry.airSince = nil
		carry.ground = table.clone(s)
	end
	carry.trail = record(trail, s)
	prune(carry.trail, HISTORY)
	return true
end

function MoveGuard.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local hrp = hrpOf(player)
				if hrp then
					local g = guardOf(player)
					local pos = hrp.Position
					local ok
					if now < g.settleUntil then
						ok = g.settlePos ~= nil and (flat(pos) - flat(g.settlePos)).Magnitude <= SETTLE_RADIUS
					else
						ok = check(player, g, pos)
					end
					if ok then
						g.history = record(g.history, sample(g.history, pos, MoveGuard.MaxSpeed(player), hvel(hrp)))
						prune(g.history, HISTORY)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		guards[player] = nil
	end)
end

return MoveGuard

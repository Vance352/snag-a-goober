--[[
	MoveGuard - server-side sanity checks on client-replicated movement.

	Characters are physically simulated by their own client, so an exploiter
	can teleport or speed-hack. MoveGuard uses one rule everywhere:

	    "Could you have walked here?"

	  * Normal play: the current position must be reachable, at the server's
	    WalkSpeed (+8%), from every recorded sample 0.6-2 s old. Samples
	    younger than 0.6 s are skipped, so a short replication hitch followed
	    by a catch-up is not punished, while sustained speed hacks and
	    teleports are.
	  * On a violation the player is "in debt": trust freezes at the last
	    trusted spot A. Debt clears only once the current position is
	    reachable by walking from A in the time since A. Every move made while
	    in debt is therefore charged (multi-hop teleports gain nothing), and
	    teleport-then-wait is never faster than walking. A safety valve
	    forgives debt after 30 s (longer than any walk on this map).
	  * Respawns and server teleports re-anchor at the server's own target
	    with a 1 s settle window in which only positions near the target count
	    and nothing can complete.
	  * CarryStep() applies the same reachability rule to a carry's own trail
	    (at the real, slowed walk speed +5%) and checks hovering.
]]

local Players = game:GetService("Players")

local MoveGuard = {}
local S

local ACTION_SLACK = 1.08 -- free-roam speed tolerance
local CARRY_SLACK = 1.05 -- carry speed tolerance
local DIST_SLACK = 2.5 -- studs of physics jitter
local MIN_AGE = 0.6 -- ignore samples younger than this: one hitch catch-up (~0.6 s of walking) is tolerated
local HISTORY = 2.0
local SETTLE_TIME = 1.0
local SETTLE_RADIUS = 12
local DEBT_FORGIVE = 30

type Sample = { t: number, pos: Vector3, speed: number? }
type Guard = {
	history: { Sample },
	anchor: Sample?,
	debt: boolean,
	debtSince: number,
	settleUntil: number,
	settlePos: Vector3?,
	flaggedAt: number,
	lastFlag: string?,
}
local guards: { [Player]: Guard } = {}

function MoveGuard.Init(registry)
	S = registry
end

local function guardOf(player: Player): Guard
	local g = guards[player]
	if not g then
		g = { history = {}, anchor = nil, debt = false, debtSince = 0, settleUntil = 0, settlePos = nil, flaggedAt = -100, lastFlag = nil }
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
	return math.max(0, d / (MoveGuard.MaxSpeed(player) * 1.1) - 0.3)
end

function MoveGuard.Settling(player: Player): boolean
	return os.clock() < guardOf(player).settleUntil
end

-- Reachable from every sample in `list` that is MIN_AGE..HISTORY old?
-- Uses the highest walk speed in force since each sample, so a speed drop
-- (e.g. becoming a slowed thief) doesn't make earlier legit walking look fast.
local function reachable(list: { Sample }, pos: Vector3, speedNow: number, slack: number, extra: number): (boolean, number)
	local now = os.clock()
	local speed = speedNow
	for i = #list, 1, -1 do
		local s = list[i]
		speed = math.max(speed, s.speed or speedNow)
		local dt = now - s.t
		if dt >= MIN_AGE then
			local d = (flat(pos) - flat(s.pos)).Magnitude
			local allowed = speed * slack * dt + DIST_SLACK + extra
			if d > allowed then
				return false, d - allowed
			end
		end
	end
	return true, 0
end

local function enterDebt(player: Player, g: Guard, excess: number, reason: string)
	if g.debt then
		return
	end
	g.debt = true
	g.debtSince = os.clock()
	g.flaggedAt = os.clock()
	g.lastFlag = ("%s +%.0f studs"):format(reason, excess)
	-- trust freezes at the newest sample (the last position we accepted)
	g.anchor = g.history[#g.history] or g.anchor
	local st = S.Session.Get(player)
	if st and st.carry and st.carry.source == "steal" then
		S.Steal.Offence(player)
	end
end

-- While in debt: could they have walked here from the frozen anchor?
local function debtPaid(player: Player, g: Guard, pos: Vector3): boolean
	local a = g.anchor
	local now = os.clock()
	if not a or now - g.debtSince > DEBT_FORGIVE then
		return true
	end
	local d = (flat(pos) - flat(a.pos)).Magnitude
	return d <= MoveGuard.MaxSpeed(player) * ACTION_SLACK * (now - a.t) + DIST_SLACK
end

local function check(player: Player, g: Guard, pos: Vector3): boolean
	if g.debt then
		if debtPaid(player, g, pos) then
			g.debt = false
			g.history = { { t = os.clock(), pos = pos, speed = MoveGuard.MaxSpeed(player) } }
			return true
		end
		return false
	end
	local speed = MoveGuard.MaxSpeed(player)
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

local function anchorAt(g: Guard, pos: Vector3)
	local now = os.clock()
	g.history = { { t = now, pos = pos } }
	g.anchor = { t = now, pos = pos }
	g.debt = false
	g.settleUntil = now + SETTLE_TIME
	g.settlePos = pos
end

-- A new character: trust only where the server spawned it.
function MoveGuard.OnSpawn(player: Player)
	local hrp = hrpOf(player)
	if hrp then
		anchorAt(guardOf(player), hrp.Position)
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
			if carry.startPos then
				carry.startPos += delta
			end
		end
	end
	c:PivotTo(cf)
	anchorAt(guardOf(player), cf.Position)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Per-tick validation of a carry's path (call ~10x/s while carrying).
-- Returns false if the carrier teleported, sped or hovered.
function MoveGuard.CarryStep(player: Player, carry): boolean
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	local g = guardOf(player)
	local now = os.clock()
	local pos = hrp.Position
	if g.debt then
		return false
	end
	if now < g.settleUntil and g.settlePos and (flat(pos) - flat(g.settlePos)).Magnitude > SETTLE_RADIUS then
		return true -- server move still replicating; completion is blocked by Settling()
	end
	local trail = carry.trail
	if not trail then
		carry.trail = { { t = now, pos = pos, speed = MoveGuard.MaxSpeed(player) } }
		carry.airSince = nil
		return true
	end
	local speed = MoveGuard.MaxSpeed(player)
	local ok = reachable(trail, pos, speed, CARRY_SLACK, pingSlack(player, speed))
	table.insert(trail, { t = now, pos = pos, speed = speed })
	while #trail > 1 and now - trail[1].t > 3.0 do
		table.remove(trail, 1)
	end
	if not ok then
		return false
	end
	-- hovering: more than 12 studs above whatever is below for > 0.6 s
	rayParams.FilterDescendantsInstances = { player.Character, carry.model }
	local hit = workspace:Raycast(pos, Vector3.new(0, -40, 0), rayParams)
	local height = if hit then pos.Y - hit.Position.Y else 40
	if height > 12 then
		carry.airSince = carry.airSince or now
		if now - carry.airSince > 0.6 then
			return false
		end
	else
		carry.airSince = nil
	end
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
					local record = true
					if now < g.settleUntil then
						record = g.settlePos ~= nil and (flat(pos) - flat(g.settlePos)).Magnitude <= SETTLE_RADIUS
					else
						record = check(player, g, pos)
					end
					if record then
						table.insert(g.history, { t = now, pos = pos, speed = MoveGuard.MaxSpeed(player) })
						while #g.history > 1 and now - g.history[1].t > HISTORY do
							table.remove(g.history, 1)
						end
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

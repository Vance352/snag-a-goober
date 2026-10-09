--[[
	MoveGuard - server-side sanity checks on client-replicated movement.

	Characters are physically simulated by their own client, so an exploiter
	can teleport or speed-hack. MoveGuard uses a "trust anchor" model:

	  * Every 0.1 s it samples each character. While movement is plausible
	    (reachable at the player's server-set walk speed), the anchor follows
	    the player.
	  * On an implausible jump the player goes "into debt": the anchor stays at
	    the last trusted spot and the player is treated as still walking from
	    there. Until enough time has passed to have walked to where they are
	    now, Plausible() is false, so snag / steal requests are refused.
	    Teleport-then-wait therefore gains nothing over just walking.
	  * CarryStep() validates every tick of a carry: big single-tick jumps,
	    sustained speed over ~1.2 s against the humanoid's actual WalkSpeed
	    (thieves are slowed), and hovering. Lag gets slack from the player's
	    network ping.
	Server-initiated moves (spawn, ejection) go through ServerMove, which
	shifts the recorded history instead of forgetting it.
]]

local Players = game:GetService("Players")

local MoveGuard = {}
local S

local SPEED_SLACK = 1.12 -- 12% over max walk speed
local DIST_SLACK = 3 -- studs of physics jitter
local JUMP_LIMIT = 12 -- a single 0.1 s step longer than this (+ speed) is a teleport

type Sample = { t: number, pos: Vector3 }
type Guard = {
	history: { Sample },
	anchor: Sample?,
	debt: boolean,
	graceUntil: number,
	flaggedAt: number,
}
local guards: { [Player]: Guard } = {}

function MoveGuard.Init(registry)
	S = registry
end

local function guardOf(player: Player): Guard
	local g = guards[player]
	if not g then
		g = { history = {}, anchor = nil, debt = false, graceUntil = 0, flaggedAt = -100 }
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

-- The server's own WalkSpeed for the character (clients can't change it on
-- the server), with a floor so a brief stun doesn't count as zero.
function MoveGuard.MaxSpeed(player: Player): number
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return math.max(hum and hum.WalkSpeed or 16, 8)
end

-- extra studs allowed for network delay
local function pingSlack(player: Player, speed: number): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	ping = if ok and type(ping) == "number" then ping else 0.1
	return speed * math.clamp(ping * 2, 0.1, 0.6)
end

-- Minimum seconds a legit player needs to walk from a to b.
function MoveGuard.MinTravelTime(player: Player, a: Vector3, b: Vector3): number
	local d = (flat(a) - flat(b)).Magnitude
	return math.max(0, d / (MoveGuard.MaxSpeed(player) * 1.25) - 0.5)
end

local function sampleAgo(g: Guard, ago: number): Sample?
	local h = g.history
	if #h == 0 then
		return nil
	end
	local target = os.clock() - ago
	for i = #h, 1, -1 do
		if h[i].t <= target then
			return h[i]
		end
	end
	return h[1]
end

-- Is `pos` (now) reachable from the sample ~1 s ago?
local function windowOk(player: Player, g: Guard, pos: Vector3): boolean
	local old = sampleAgo(g, 1.0)
	if not old then
		return true
	end
	local dt = math.max(0.1, os.clock() - old.t)
	local speed = MoveGuard.MaxSpeed(player)
	local allowed = speed * SPEED_SLACK * dt + DIST_SLACK + pingSlack(player, speed)
	return (flat(pos) - flat(old.pos)).Magnitude <= allowed
end

local function enterDebt(player: Player, g: Guard)
	if not g.debt then
		g.debt = true
		g.flaggedAt = os.clock()
		local st = S.Session.Get(player)
		if st and st.carry and st.carry.source == "steal" then
			S.Steal.Fail(player, "teleport")
		end
	end
end

-- While in debt: has the player had time to really walk here from the anchor?
local function debtPaid(player: Player, g: Guard, pos: Vector3): boolean
	local a = g.anchor
	if not a then
		return true
	end
	-- strictly slower than walking: real walk speed + 10%, plus a 1.5 s penalty
	local d = (flat(a.pos) - flat(pos)).Magnitude
	return os.clock() >= a.t + d / (MoveGuard.MaxSpeed(player) * 1.1) + 1.5
end

-- True if the player's current position is trustworthy right now.
function MoveGuard.Plausible(player: Player): boolean
	local g = guardOf(player)
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	if os.clock() < g.graceUntil then
		return true
	end
	if g.debt then
		return false
	end
	if not windowOk(player, g, hrp.Position) then
		enterDebt(player, g) -- caught between samples
		return false
	end
	return true
end

function MoveGuard.FlaggedSince(player: Player, t: number): boolean
	return guardOf(player).flaggedAt >= t
end

-- Respawn and similar: forget history, trust the new position.
function MoveGuard.Grace(player: Player, seconds: number)
	local g = guardOf(player)
	g.graceUntil = math.max(g.graceUntil, os.clock() + seconds)
	g.history = {}
	g.anchor = nil
	g.debt = false
end

-- Move a character on the server: shift recorded positions by the same
-- offset so the move never looks like a teleport, and carries keep their
-- validation (no blanket grace that an exploiter could ride).
function MoveGuard.ServerMove(player: Player, cf: CFrame)
	local c = player.Character
	local hrp = hrpOf(player)
	if not c then
		return
	end
	if hrp then
		local delta = cf.Position - hrp.Position
		local g = guardOf(player)
		for _, s in ipairs(g.history) do
			s.pos += delta
		end
		if g.anchor then
			g.anchor.pos += delta
		end
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
		-- a short settle window for replication only (no history wipe)
		g.graceUntil = math.max(g.graceUntil, os.clock() + 0.6)
	end
	c:PivotTo(cf)
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
	local trail = carry.trail
	if not trail then
		carry.trail = { { t = now, pos = pos } }
		carry.airSince = nil
		return true
	end
	local inGrace = now < g.graceUntil
	local speed = MoveGuard.MaxSpeed(player)
	local slack = pingSlack(player, speed)
	local last = trail[#trail]
	-- single-tick jump (teleport)
	if not inGrace and (flat(pos) - flat(last.pos)).Magnitude > JUMP_LIMIT + speed * 1.5 * math.max(0.1, now - last.t) then
		return false
	end
	table.insert(trail, { t = now, pos = pos })
	while #trail > 2 and now - trail[2].t >= 1.3 do
		table.remove(trail, 1)
	end
	-- sustained speed over ~1.2 s, against the real (slowed) walk speed
	local first = trail[1]
	local dt = now - first.t
	if not inGrace and dt >= 1.2 and (flat(pos) - flat(first.pos)).Magnitude > speed * SPEED_SLACK * dt + DIST_SLACK + slack then
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
					if now < g.graceUntil then
						if not g.anchor then
							g.anchor = { t = now, pos = pos }
						end
					elseif g.debt then
						if debtPaid(player, g, pos) then
							g.debt = false
							g.history = {}
							g.anchor = { t = now, pos = pos }
						end
					elseif windowOk(player, g, pos) then
						g.anchor = { t = now, pos = pos }
					else
						enterDebt(player, g)
					end
					table.insert(g.history, { t = now, pos = pos })
					while #g.history > 0 and now - g.history[1].t > 2.2 do
						table.remove(g.history, 1)
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

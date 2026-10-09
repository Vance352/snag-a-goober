--[[
	MoveGuard - server-side sanity checks on client-replicated movement.

	Characters are physically simulated by their own client, so an exploiter
	can teleport or speed-hack. MoveGuard keeps a "trust anchor" per player:

	  * Every 0.1 s it samples each character. While movement is plausible
	    (reachable at the server-set walk speed), the anchor follows the player.
	  * An implausible jump puts the player "in debt": they owe the time it
	    would have taken to walk that jump (+1 s). Snag / steal requests are
	    refused until the debt is paid. The debt is a fixed amount of time, so
	    it pays down while the player walks on and never snowballs from a
	    single physics bump. Teleport-then-wait is never faster than walking.
	  * There is no free grace period. Respawns and server teleports (spawn,
	    ejection) anchor trust at the *server's* chosen position and open a
	    short "settle" window in which only positions near that target count;
	    anything else is ignored and nothing can complete meanwhile.
	  * CarryStep() validates every tick of a carry: single-tick jumps,
	    sustained speed averaged over ~3 s against the humanoid's real
	    WalkSpeed (thieves are slowed, so a thief can't out-run an owner), and
	    hovering. Network ping adds a small capped slack.
]]

local Players = game:GetService("Players")

local MoveGuard = {}
local S

local SPEED_SLACK = 1.12 -- short-window (1 s) action checks
local DIST_SLACK = 3 -- studs of physics jitter
local JUMP_LIMIT = 12 -- a single 0.1 s step longer than this (+ speed) is a teleport
local CARRY_WINDOW = 3.0 -- seconds averaged for carry speed
local CARRY_SLACK = 1.05 -- +5% over walk speed while carrying
local SETTLE_TIME = 1.0 -- seconds a server move needs to replicate
local SETTLE_RADIUS = 12

type Sample = { t: number, pos: Vector3 }
type Guard = {
	history: { Sample },
	anchor: Sample?,
	debtUntil: number,
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
		g = { history = {}, anchor = nil, debtUntil = 0, settleUntil = 0, settlePos = nil, flaggedAt = -100, lastFlag = nil }
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

local function pingOf(player: Player): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	return if ok and type(ping) == "number" then ping else 0.1
end

-- Seconds a legit player needs to walk from a to b (used for carries:
-- you can't finish faster than this).
function MoveGuard.MinTravelTime(player: Player, a: Vector3, b: Vector3): number
	local d = (flat(a) - flat(b)).Magnitude
	return math.max(0, d / (MoveGuard.MaxSpeed(player) * 1.1) - 0.3)
end

function MoveGuard.Settling(player: Player): boolean
	return os.clock() < guardOf(player).settleUntil
end

local function inDebt(g: Guard): boolean
	return os.clock() < g.debtUntil
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
-- Is `pos` (now) reachable from every sample 1-2 s ago (and from the
-- newest sample at least ~1 s old if history is short)?
local function windowOk(player: Player, g: Guard, pos: Vector3): (boolean, number)
	local h = g.history
	if #h == 0 then
		return true, 0
	end
	local now = os.clock()
	local speed = MoveGuard.MaxSpeed(player)
	local lag = speed * math.clamp(pingOf(player) * 2, 0.1, 0.4)
	local checked = false
	for i = #h, 1, -1 do
		local s = h[i]
		local dt = now - s.t
		if dt >= 1.0 or (i == 1 and not checked) then
			checked = true
			dt = math.max(0.1, dt)
			local d = (flat(pos) - flat(s.pos)).Magnitude
			if d > speed * SPEED_SLACK * dt + DIST_SLACK + lag then
				return false, d - speed * dt
			end
		end
	end
	return true, 0
end

-- Owe the time it would take to walk the excess distance (+1 s).
local function addDebt(player: Player, g: Guard, excess: number, reason: string)
	local now = os.clock()
	local owed = math.clamp(excess / (MoveGuard.MaxSpeed(player) * 1.1) + 1.0, 1.0, 10)
	g.debtUntil = math.max(g.debtUntil, now) + owed
	g.flaggedAt = now
	g.lastFlag = ("%s %.0f studs -> %.1fs"):format(reason, excess, owed)
	g.history = {}
	local st = S.Session.Get(player)
	if st and st.carry and st.carry.source == "steal" then
		S.Steal.Fail(player, "teleport")
	end
end

-- True if the player's current position is trustworthy right now.
function MoveGuard.Plausible(player: Player): boolean
	local g = guardOf(player)
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	if inDebt(g) then
		return false
	end
	if os.clock() < g.settleUntil then
		-- only the server's target position is trusted while a move settles
		return g.settlePos ~= nil and (flat(hrp.Position) - flat(g.settlePos)).Magnitude <= SETTLE_RADIUS
	end
	local ok, excess = windowOk(player, g, hrp.Position)
	if not ok then
		addDebt(player, g, excess, "action")
		return false
	end
	return true
end

function MoveGuard.FlaggedSince(player: Player, t: number): boolean
	return guardOf(player).flaggedAt >= t
end

function MoveGuard.LastFlag(player: Player): string?
	return guardOf(player).lastFlag
end

-- Anchor trust at a position the server chose (spawn / server teleport).
local function anchorAt(player: Player, g: Guard, pos: Vector3)
	local now = os.clock()
	g.history = { { t = now, pos = pos } }
	g.anchor = { t = now, pos = pos }
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
-- Returns false if the carrier teleported, sped or hovered.
function MoveGuard.CarryStep(player: Player, carry): boolean
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	local g = guardOf(player)
	local now = os.clock()
	local pos = hrp.Position
	if inDebt(g) then
		return false
	end
	if now < g.settleUntil then
		-- ignore samples until the server move has replicated (completion is
		-- blocked meanwhile by Settling())
		if g.settlePos and (flat(pos) - flat(g.settlePos)).Magnitude > SETTLE_RADIUS then
			return true
		end
	end
	local trail = carry.trail
	if not trail then
		carry.trail = { { t = now, pos = pos } }
		carry.airSince = nil
		return true
	end
	local speed = MoveGuard.MaxSpeed(player)
	local last = trail[#trail]
	-- single-tick jump (teleport)
	if (flat(pos) - flat(last.pos)).Magnitude > JUMP_LIMIT + speed * 1.5 * math.max(0.1, now - last.t) then
		return false
	end
	table.insert(trail, { t = now, pos = pos })
	while #trail > 2 and now - trail[2].t >= CARRY_WINDOW do
		table.remove(trail, 1)
	end
	-- sustained speed against the real (slowed) walk speed: every sub-window
	-- of >= 1 s inside the trail is checked, so standing still first can't
	-- "bank" distance for a later burst
	local ping = math.clamp(pingOf(player), 0.05, 0.15)
	for i = 1, #trail - 1 do
		local s = trail[i]
		local dt = now - s.t
		if dt < 1.0 then
			break
		end
		local allowed = speed * CARRY_SLACK * dt + 1.5 + speed * ping
		if (flat(pos) - flat(s.pos)).Magnitude > allowed then
			return false
		end
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
						-- trust only positions near the server's target
						if g.settlePos and (flat(pos) - flat(g.settlePos)).Magnitude <= SETTLE_RADIUS then
							g.anchor = { t = now, pos = pos }
						else
							record = false
						end
					elseif not inDebt(g) then
						local ok, excess = windowOk(player, g, pos)
						if ok then
							g.anchor = { t = now, pos = pos }
						else
							addDebt(player, g, excess, "sample")
						end
					end
					if record then
						table.insert(g.history, { t = now, pos = pos })
						while #g.history > 0 and now - g.history[1].t > 2.2 do
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

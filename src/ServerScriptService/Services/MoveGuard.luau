--[[
	MoveGuard - server-side sanity checks on client-replicated movement.

	Characters are physically simulated by their own client, so an exploiter
	can teleport. MoveGuard keeps ~2 s of position history per player and:
	  * Plausible(player): did the player get here at walking speed?
	    (compares now vs ~1 s ago, horizontal only, generous lag margin)
	  * flags teleports every sample; a flag cancels a stolen-Goober carry and
	    blocks snag/steal requests for a few seconds
	  * MinTravelTime(): the least time a legit player needs to walk between
	    two points - carries cannot complete faster than that
	Server-initiated moves (spawn, ejection) go through ServerMove so they are
	never mistaken for cheating.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local Config = require(ReplicatedStorage.Shared.Config)

local MoveGuard = {}
local S

local WINDOW = 1.0 -- seconds of history compared
local SPEED_SLACK = 1.25 -- tolerate 25% over max walk speed
local DIST_SLACK = 6 -- studs of lag / physics jitter
local FLAG_BLOCK = 3 -- seconds actions stay blocked after a flag

type Sample = { t: number, pos: Vector3 }
local history: { [Player]: { Sample } } = {}
local graceUntil: { [Player]: number } = {}
local flaggedAt: { [Player]: number } = {}

function MoveGuard.Init(registry)
	S = registry
end

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MoveGuard.MaxSpeed(player: Player): number
	local st = S.Session.Get(player)
	if not st then
		return 16
	end
	local speed = Util.WalkSpeed(st.data.upgrades.Speed, st.passes.SprintBoots == true)
	if st.carry and st.carry.source == "steal" then
		speed *= Config.Steal.carrySpeedMult -- thieves are slowed
	end
	return speed
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Per-tick validation of a carry's path (call ~10x/s while carrying).
-- Returns false if the carrier teleported, sped or hovered. Keeps its own
-- short trail on the carry table.
function MoveGuard.CarryStep(player: Player, carry): boolean
	local hrp = hrpOf(player)
	if not hrp then
		return true
	end
	local now = os.clock()
	if now < (graceUntil[player] or 0) then
		carry.trail = nil
		return true
	end
	local pos = hrp.Position
	local speed = MoveGuard.MaxSpeed(player) * SPEED_SLACK
	local trail = carry.trail
	if not trail then
		carry.trail = { { t = now, pos = pos } }
		carry.airSince = nil
		return true
	end
	local last = trail[#trail]
	-- single-tick jump (teleport)
	if (flat(pos) - flat(last.pos)).Magnitude > speed * math.max(0.1, now - last.t) + 3 then
		return false
	end
	-- sustained speed over ~0.6 s
	table.insert(trail, { t = now, pos = pos })
	while #trail > 2 and now - trail[2].t >= 0.6 do
		table.remove(trail, 1)
	end
	local first = trail[1]
	local dt = now - first.t
	if dt >= 0.5 and (flat(pos) - flat(first.pos)).Magnitude > speed * dt + 2.5 then
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

-- Move a character on the server without tripping the guard.
function MoveGuard.ServerMove(player: Player, cf: CFrame)
	graceUntil[player] = os.clock() + 1.5
	history[player] = {}
	local c = player.Character
	if c then
		c:PivotTo(cf)
	end
end

function MoveGuard.Grace(player: Player, seconds: number)
	graceUntil[player] = os.clock() + seconds
	history[player] = {}
end

local function sampleAgo(player: Player, ago: number): Sample?
	local h = history[player]
	if not h or #h == 0 then
		return nil
	end
	local target = os.clock() - ago
	local best = h[1]
	for i = #h, 1, -1 do
		if h[i].t <= target then
			best = h[i]
			break
		end
	end
	return best
end

-- True if the player's current position is reachable from where they were
-- ~1 s ago at their max walk speed.
function MoveGuard.Plausible(player: Player): boolean
	if os.clock() < (graceUntil[player] or 0) then
		return true
	end
	if os.clock() - (flaggedAt[player] or -100) < FLAG_BLOCK then
		return false
	end
	local hrp = hrpOf(player)
	local old = sampleAgo(player, WINDOW)
	if not hrp or not old then
		return true
	end
	local dt = math.max(0.1, os.clock() - old.t)
	local allowed = MoveGuard.MaxSpeed(player) * dt * SPEED_SLACK + DIST_SLACK
	return (flat(hrp.Position) - flat(old.pos)).Magnitude <= allowed
end

function MoveGuard.FlaggedSince(player: Player, t: number): boolean
	return (flaggedAt[player] or -100) >= t
end

-- Minimum seconds a legit player needs to walk from a to b.
function MoveGuard.MinTravelTime(player: Player, a: Vector3, b: Vector3): number
	local d = (flat(a) - flat(b)).Magnitude
	return math.max(0, d / (MoveGuard.MaxSpeed(player) * SPEED_SLACK) - 0.75)
end

local function onFlag(player: Player)
	flaggedAt[player] = os.clock()
	local st = S.Session.Get(player)
	if st and st.carry and st.carry.source == "steal" then
		S.Steal.Fail(player, "teleport")
	end
end

function MoveGuard.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local hrp = hrpOf(player)
				if hrp then
					local h = history[player]
					if not h then
						h = {}
						history[player] = h
					end
					table.insert(h, { t = now, pos = hrp.Position })
					while #h > 0 and now - h[1].t > 2.2 do
						table.remove(h, 1)
					end
					if now >= (graceUntil[player] or 0) and not MoveGuard.Plausible(player) then
						if now - (flaggedAt[player] or -100) >= FLAG_BLOCK then
							onFlag(player)
						end
						history[player] = { { t = now, pos = hrp.Position } }
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		graceUntil[player] = nil
		flaggedAt[player] = nil
	end)
end

return MoveGuard

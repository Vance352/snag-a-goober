--[[
	StealService - stealing a Goober from another player's base.

	Fairness rules (all enforced here, never on the client):
	  * both players must be Level >= Config.StealLevel (new players are safe)
	  * victim base must not be locked (lock pad, join grace, post-theft shield)
	  * a freshly placed Goober is protected for Config.Steal.placeProtection s
	  * thief needs a free stand, empty hands, and no active cooldown
	  * the same thief can only hit the same victim once per pairCooldown
	  * only ONE Goober moves per theft; the victim's record stays theirs until
	    the thief actually reaches home
	  * the owner catches the thief by getting within catchRadius: the Goober
	    returns, the thief is stunned and gets a longer cooldown
	  * a successful theft pays the victim 25% of the Goober's price and
	    shields their base for victimShield seconds
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)

local StealService = {}
local S
local C = Config.Steal

function StealService.Init(registry)
	S = registry
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function fail(player: Player, msg: string)
	S.Session.Notify(player, "Error", { text = msg })
end

-- Returns (ok, reason) - also used by the client to explain why a prompt is hidden.
function StealService.CanSteal(thief: Player, victim: Player, uid: string): (boolean, string?)
	local ts = S.Session.Get(thief)
	local vs = S.Session.Get(victim)
	if not ts or not vs or not ts.ready or not vs.ready or thief == victim then
		return false, nil
	end
	local now = os.clock()
	if ts.data.level < Config.StealLevel then
		return false, ("Stealing unlocks at Level %d."):format(Config.StealLevel)
	end
	if vs.data.level < Config.StealLevel then
		return false, "New players are protected until Level " .. Config.StealLevel .. "."
	end
	if now < vs.lockUntil then
		return false, "That base is locked!"
	end
	if ts.carry then
		return false, "Your hands are full!"
	end
	if now < ts.stealCooldownUntil then
		return false, ("Steal cooldown: %ds"):format(math.ceil(ts.stealCooldownUntil - now))
	end
	local pair = ts.pairCooldown[victim.UserId]
	if pair and now < pair then
		return false, ("You already hit this base. Try again in %s."):format(Util.Time(pair - now))
	end
	if not S.Session.HasFreeSlot(thief) then
		return false, "Your base is full!"
	end
	local g = vs.data.goobers[uid]
	local model = S.Base.ModelOf(victim, uid)
	if not g or not model or vs.inTransit[uid] then
		return false, nil
	end
	local protectedUntil = model:GetAttribute("ProtectedUntil") or 0
	if workspace:GetServerTimeNow() < protectedUntil then
		return false, "That Goober was just placed and is protected."
	end
	return true, nil
end

-- The client tells us when the player starts holding the Steal prompt; the
-- server times the hold itself, so the hold can't be skipped.
local holds: { [Player]: { uid: string, t: number } } = {}

function StealService.HoldBegan(thief: Player, uid: any)
	if type(uid) ~= "string" or #uid > 40 or not S.Session.RateOk(thief, "StealHold", 6, 1) then
		return
	end
	local victim = S.Base.OwnerOf(uid)
	local model = victim and S.Base.ModelOf(victim, uid)
	local hrp = hrpOf(thief)
	if not S.MoveGuard.Plausible(thief) then
		return -- arrived by teleport: still "walking" from the last trusted spot
	end
	if model and hrp and (hrp.Position - model:GetPivot().Position).Magnitude <= C.stealRange then
		holds[thief] = { uid = uid, t = os.clock() }
	end
end

function StealService.Request(thief: Player, uid: any)
	if type(uid) ~= "string" or #uid > 40 or not S.Session.RateOk(thief, "Steal", 3, 1) then
		return
	end
	local hold = holds[thief]
	holds[thief] = nil
	if not hold or hold.uid ~= uid or os.clock() - hold.t < C.holdDuration - 0.25 then
		return -- no (or too short a) hold seen by the server
	end
	if not S.MoveGuard.Plausible(thief) then
		return fail(thief, "Whoa, slow down!")
	end
	local victim = S.Base.OwnerOf(uid)
	if not victim then
		return
	end
	local ok, reason = StealService.CanSteal(thief, victim, uid)
	if not ok then
		if reason then
			fail(thief, reason)
		end
		return
	end
	local hrp = hrpOf(thief)
	local model = S.Base.ModelOf(victim, uid)
	if not hrp or not model or (hrp.Position - model:GetPivot().Position).Magnitude > C.stealRange then
		return fail(thief, "Get closer!")
	end
	local ts = S.Session.Get(thief)
	local vs = S.Session.Get(victim)
	local g = vs.data.goobers[uid]
	local def = GooberData.ById[g.id]

	local detached = S.Base.DetachForSteal(victim, uid)
	if not detached then
		return
	end
	local now = os.clock()
	ts.stealCooldownUntil = now + C.thiefCooldown
	ts.pairCooldown[victim.UserId] = now + C.pairCooldown
	S.Carry.Begin(thief, {
		uid = uid,
		id = g.id,
		source = "steal",
		model = detached,
		price = def.price,
		victim = victim,
		victimName = victim.DisplayName,
		startedAt = now,
	})
	S.Session.Notify(victim, "StealAlert", { thief = thief.DisplayName, thiefId = thief.UserId, id = g.id })
	S.Session.Notify(thief, "StealStart", { victim = victim.DisplayName, victimId = victim.UserId, id = g.id })
	S.Session.Effect("StealStarted", { thief = thief.UserId, victim = victim.UserId, id = g.id })
end

local function stun(player: Player)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	st.stunnedUntil = os.clock() + C.stunTime
	S.Character.ApplySpeed(player)
	task.delay(C.stunTime + 0.05, function()
		if player.Parent then
			S.Character.ApplySpeed(player)
		end
	end)
end

-- Theft failed for any reason: the Goober goes back to its owner's stand.
function StealService.Fail(thief: Player, reason: string)
	local ts = S.Session.Get(thief)
	local carry = ts and ts.carry
	if not carry or carry.source ~= "steal" then
		return
	end
	local victim: Player = carry.victim
	S.Carry._clear(thief)
	if victim and victim.Parent and S.Session.Get(victim) then
		S.Base.ReturnFromSteal(victim, carry.uid, carry.model)
	else
		carry.model:Destroy()
	end
	if reason == "caught" then
		ts.stealCooldownUntil = os.clock() + C.failedCooldown
		ts.data.stats.caught += 1
		stun(thief)
		S.Session.Notify(thief, "Caught", { by = victim and victim.DisplayName })
		if victim and victim.Parent then
			S.Session.Notify(victim, "CaughtThief", { thief = thief.DisplayName })
		end
		S.Session.Effect("ThiefCaught", { thief = thief.UserId, victim = victim and victim.UserId })
	else
		local text = ({
			timeout = "Too slow! The Goober wriggled free and ran home.",
			died = "You dropped the stolen Goober!",
			dropped = "You let the Goober go home.",
			left = "",
			teleport = "The Goober slipped away - no shortcuts!",
			victimLeft = "Its owner left - the Goober went home with them.",
		})[reason] or "The stolen Goober got away!"
		if thief.Parent and text ~= "" then
			S.Session.Toast(thief, text, "red")
		end
		if victim and victim.Parent and reason ~= "victimLeft" then
			S.Session.Notify(victim, "StealFailed", { thief = thief.DisplayName })
		end
	end
end

-- A movement violation during a theft, with how far beyond walking range the
-- thief is right now (re-measured every tick). A clear shortcut - more than
-- TELEPORT_EXCESS studs out (a teleport, or a tween/speed hack whose lead
-- keeps growing), flying, or being out of range for 8 s - cancels the theft.
-- A lag-sized flag (a few studs, shrinking as they walk) only restarts the
-- walk clock from the last trusted spot, so it never gets the thief home
-- sooner and the owner can still catch them.
function StealService.Offence(thief: Player, from: { t: number, pos: Vector3 }?, excess: number?)
	local ts = S.Session.Get(thief)
	local carry = ts and ts.carry
	if not carry or carry.source ~= "steal" then
		return
	end
	local now = os.clock()
	carry.badSince = carry.badSince or now
	if (excess or 0) > S.MoveGuard.TELEPORT_EXCESS or now - carry.badSince > 8 then
		StealService.Fail(thief, "teleport")
		return
	end
	if from then
		carry.startPos = from.pos
		carry.startT = from.t
	end
	carry.trail = nil
	if now - (carry.warnedAt or -100) > 3 then
		carry.warnedAt = now
		S.Session.Toast(thief, "Careful! Walk it home - no shortcuts.", "red")
	end
end

local function succeed(thief: Player)
	local ts = S.Session.Get(thief)
	local carry = ts.carry
	local victim: Player = carry.victim
	local vs = S.Session.Get(victim)
	local def = GooberData.ById[carry.id]
	if not vs or not vs.data.goobers[carry.uid] then
		-- victim record already gone (should not happen) - abort safely
		StealService.Fail(thief, "victimLeft")
		return
	end
	-- transfer: remove from victim first, then give the thief a fresh record
	local victimPaid = (vs.data.goobers[carry.uid] and vs.data.goobers[carry.uid].paid) or def.price
	S.Carry._clear(thief)
	carry.model:Destroy()
	S.Base.RemoveRecord(victim, carry.uid)
	local newUid = S.Base.Place(thief, carry.id, { stolen = true, paid = math.floor(victimPaid * 0.5) })
	if not newUid then
		-- thief base filled up mid-run: give it back
		S.Base.Place(victim, carry.id, { uid = carry.uid, paid = victimPaid })
		S.Session.Toast(thief, "Your base was full - the Goober went home.", "red")
		return
	end
	ts.data.stats.steals += 1
	vs.data.stats.stolenFrom += 1
	ts.stealXpAt = ts.stealXpAt or {}
	if os.clock() - (ts.stealXpAt[victim.UserId] or -1e9) >= 1800 then
		ts.stealXpAt[victim.UserId] = os.clock()
		S.Session.AddXP(thief, Config.XP.steal) -- once per victim per 30 min (no friend farming)
	end
	-- insurance pays at most once per compensationCooldown per victim, so
	-- friends can't farm coins by stealing back and forth
	local comp = 0
	if os.clock() >= (vs.compensatedAt or -1e9) + C.compensationCooldown then
		comp = math.floor(victimPaid * C.compensation) -- based on what they actually paid
		vs.compensatedAt = os.clock()
		S.Session.AddCoins(victim, comp)
	end
	S.Base.LockFor(victim, C.victimShield, false)
	S.Session.Notify(thief, "StealSuccess", { id = carry.id, victim = victim.DisplayName })
	S.Session.Notify(victim, "StolenFrom", {
		id = carry.id,
		thief = thief.DisplayName,
		compensation = comp,
		shield = C.victimShield,
	})
	S.Session.Effect("StealDone", { thief = thief.UserId, victim = victim.UserId, id = carry.id })
end

function StealService.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			for thief, ts in pairs(S.Session.All()) do
				local carry = ts.carry
				if carry and carry.source == "steal" then
					local victim: Player = carry.victim
					local thrp = hrpOf(thief)
					if not victim.Parent or not S.Session.Get(victim) then
						StealService.Fail(thief, "victimLeft")
					elseif not thrp then
						StealService.Fail(thief, "died")
					elseif os.clock() - carry.startedAt > C.timeout then
						StealService.Fail(thief, "timeout")
					else
						local vhrp = hrpOf(victim)
						local plot = S.Plot.Get(thief)
						local gap = vhrp and (vhrp.Position - thrp.Position)
						local caught = gap ~= nil and Vector2.new(gap.X, gap.Z).Magnitude <= C.catchRadius and math.abs(gap.Y) <= 10
						local ok, from, excess = true, nil, nil
						if not caught then
							ok, from, excess = S.MoveGuard.CarryStep(thief, carry)
							if ok then
								carry.badSince = nil
							end
						end
						if caught then
							-- the owner's tag always wins
							StealService.Fail(thief, "caught")
						elseif not ok then
							StealService.Offence(thief, from, excess)
						elseif
							plot
							and S.Plot.Inside(plot, thrp.Position)
							and not S.MoveGuard.Settling(thief)
							and os.clock() - carry.startedAt >= C.minCarryTime
							and os.clock() - carry.startT >= S.MoveGuard.MinTravelTime(thief, carry.startPos, thrp.Position)
						then
							succeed(thief)
						end
					end
				end
			end
		end
	end)
	-- A victim leaving mid-theft needs no special handling: their record was
	-- never removed (only marked in transit at runtime), so it saves with
	-- them, and the loop above cancels the thief's carry.
end

return StealService

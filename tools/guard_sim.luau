--[[
	guard_sim.luau - deterministic stress test of MoveGuard's carry check.

	Runs the REAL MoveGuard module (a fresh clone, Edit mode is fine) with a
	fake clock against a simulated network: a carrier walking at `speed`,
	seen by the server `LAG` seconds late, with stalls in which the server's
	copy freezes but keeps the last (walking) velocity, followed by a catch-up
	in 1-3 bursts. Server ticks are jittered. For each trial it applies the
	theft rules (StealService.Offence): cancel when a CarryStep failure is more
	than 10 studs out, or when failures last 8 s.

	Usage (MCP execute_luau / command bar, Edit mode):
		local run = loadstring(game:GetService("HttpService"):GetAsync(".../tools/guard_sim.luau"))()
		return run({ speeds = {17, 20, 26, 29.75}, stalls = { {1.5} }, trials = 150, dtMin = 0.10, dtMax = 0.12 })
	Each stall entry is {duration, gapBeforeNext?}. Returns cancel/flag rates.
	Options: lag (0.3), dtMin/dtMax (tick jitter), stallVel (velocity the
	server sees during a stall; default = walking), receiveAge (false = don't
	simulate BasePart.ReceiveAge growing during a stall), source (MoveGuard
	source to test instead of the current one), seed.
]]

return function(opts)
	local src = game:GetService("ServerScriptService").Services.MoveGuard:Clone()
	if opts.source then -- test another version of the module (e.g. from git)
		src.Source = opts.source
	end
	local MG = require(src)
	local fake = { now = 0 }
	local env = getfenv(MG.CarryStep)
	env.os = { clock = function() return fake.now end, time = os.time }
	MG.Init({ Session = { Get = function() return nil end }, Steal = { Offence = function() end } })
	local stallStart -- for the simulated ReceiveAge
	MG._receiveAge = function()
		return if opts.receiveAge ~= false and stallStart then fake.now - stallStart else 0
	end

	-- a temporary floor under the test lane (long walks leave the map, and
	-- the hover check would then see no ground); removed before returning
	local floor = Instance.new("Part")
	floor.Name = "GuardSimFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(20000, 1, 40)
	floor.CFrame = CFrame.new(0, -0.5, -27)
	floor.Transparency = 1
	floor.Parent = workspace

	local rng = Random.new(opts.seed or 1)
	local LAG = opts.lag or 0.3
	local out = {}
	for _, speed in ipairs(opts.speeds or { 20 }) do
		local cancels, flagged = 0, 0
		for trial = 1, opts.trials or 100 do
			-- a fresh dummy carrier
			local model = Instance.new("Model")
			local hum = Instance.new("Humanoid")
			hum.WalkSpeed = speed
			hum.Parent = model
			local hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Anchored = true
			hrp.Parent = model
			local player = { Character = model, GetNetworkPing = function() return 0.05 end }
			local carry = { model = model }

			-- the client's real path: walk +X; stalls only stop what the server sees
			local stallsAt = {}
			local t0 = 1.0 + rng:NextNumber() * 0.5 -- random phase
			for _, st in ipairs(opts.stalls or {}) do
				table.insert(stallsAt, { t0, t0 + st[1], bursts = rng:NextInteger(1, 3) })
				t0 += st[1] + (st[2] or 3)
			end
			local total = t0 + 2
			local function clientX(t) return speed * math.max(t, 0) end
			local function seen(t)
				for _, st in ipairs(stallsAt) do
					if t >= st[1] and t < st[2] then
						return clientX(st[1] - LAG), true -- frozen at the last packet
					end
					-- catch-up bursts right after the stall
					local after = t - st[2]
					if after >= 0 and after < 0.15 * st.bursts then
						local k = math.floor(after / 0.15) + 1
						local behind = (st[2] - st[1] + LAG) * (1 - k / st.bursts)
						return clientX(t - behind), false
					end
				end
				return clientX(t - LAG), false
			end

			local t, badSince, cancelled, flag = 0, nil, false, false
			fake.now = 1000 + trial * 100
			local base = fake.now
			while t < total do
				local x, frozen = seen(t)
				if frozen then
					stallStart = stallStart or fake.now
				else
					stallStart = nil
				end
				hrp.CFrame = CFrame.new(x, 3, -27)
				-- walking velocity; a stall keeps the last one unless opts.stallVel says otherwise
				hrp.AssemblyLinearVelocity = Vector3.new(if frozen and opts.stallVel then opts.stallVel else speed, 0, 0)
				fake.now = base + t
				local ok, _, excess = MG.CarryStep(player, carry)
				if opts.trace and trial == 1 then
					local last = carry.trail and carry.trail[#carry.trail]
					table.insert(out, ("t=%.2f x=%.1f %s ok=%s ex=%.1f tag=%s n=%d"):format(t, x, if frozen then "F" else "-", tostring(ok), excess or 0,
						last and (if last.stall then "S" elseif last.catchup then "C" else "") or "?", carry.trail and #carry.trail or 0))
				end
				if not ok then
					flag = true
					badSince = badSince or t
					if (excess or 0) > 10 or t - badSince > 8 then
						cancelled = true
						break
					end
					carry.trail = nil -- what StealService.Offence does on a re-time
				else
					badSince = nil
				end
				t += rng:NextNumber(opts.dtMin or 0.10, opts.dtMax or 0.12)
			end
			if cancelled then cancels += 1 end
			if flag then flagged += 1 end
			model:Destroy()
		end
		table.insert(out, ("speed %.2f: cancel %d/%d, flagged %d"):format(speed, cancels, opts.trials or 100, flagged))
	end
	floor:Destroy()
	return out
end

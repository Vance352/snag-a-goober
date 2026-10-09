--[[
	BreachFx - how the Goober Breach (and the island cauldrons) look and sound
	on the client, driven by ReplicatedStorage.BreachState (the server's cycle):

	  Cooldown  ring idles, core dim
	  Charging  ring spins up, core swells and glows in the blast type's colour,
	            energy gathers, a hum rises
	  Unstable  sparks crackle, the core flickers, nearby cameras shake,
	            RARE RIFTs sound an alarm
	  Blast     flash, shockwave ring, burst - the Goobers fly (World animates them)

	Also drives the HUD charge meter when you're near a Breach.
	Purely cosmetic: nothing here decides anything.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Breach = require(ReplicatedStorage.Shared.Breach)

local Effects = require(script.Parent.Effects)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local BreachFx = {}

local SLOP = Color3.fromRGB(123, 227, 90)
local SPOOKY = Color3.fromRGB(150, 255, 110)
local NEAR = 140 -- studs: closer than this you see the HUD meter / feel the shake

type Machine = {
	model: Model,
	site: string,
	ring: BasePart?,
	ringBase: CFrame?,
	core: BasePart?,
	coreSize: Vector3?,
	glows: { BasePart },
	light: PointLight?,
	gather: ParticleEmitter?,
	sparks: ParticleEmitter?,
	angle: number,
	lastStage: string?,
}

local machines: { [Instance]: Machine } = {}

local function typeColor(site: string, typ: string?): Color3
	if typ and Breach.Types[typ] then
		return Breach.Types[typ].color
	end
	return if Breach.Sites[site] and Breach.Sites[site].spooky then SPOOKY else SLOP
end

local function stateOf(site: string): Folder?
	local f = ReplicatedStorage:FindFirstChild("BreachState")
	return f and f:FindFirstChild(site) :: Folder?
end

local function addMachine(model: Instance)
	if not model:IsA("Model") or machines[model] then
		return
	end
	local site = model:GetAttribute("Site")
	if not site then
		return
	end
	local m: Machine = { model = model, site = site, glows = {}, angle = 0 }
	m.ring = model:FindFirstChild("RingCenter", true) :: BasePart?
	m.ringBase = m.ring and m.ring.CFrame
	m.core = model:FindFirstChild("Core", true) :: BasePart?
	m.coreSize = m.core and m.core.Size
	m.light = m.core and m.core:FindFirstChildOfClass("PointLight")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Glow" then
			table.insert(m.glows, d)
		elseif d:IsA("ParticleEmitter") and d.Name == "Gather" then
			m.gather = d
		elseif d:IsA("ParticleEmitter") and d.Name == "Sparks" then
			m.sparks = d
		end
	end
	machines[model] = m
end

-- one-off blast visuals at a machine
local function blastFx(m: Machine, color: Color3)
	local core = m.core
	local pos = if core then core.Position else m.model:GetPivot().Position
	-- shockwave ring
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.4, 4, 4)
	ring.CFrame = CFrame.new(pos.X, m.model:GetPivot().Position.Y + 0.6, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, 70, 70), Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(ring, 0.8)
	Effects.Burst(pos, color, 60, 1.6)
	if core then
		local s = m.coreSize or core.Size
		core.Size = s * 1.8
		TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = s }):Play()
	end
end

local function shake(strength: number)
	Effects.Kick(strength)
end

local function nearestMachine(pos: Vector3): (Machine?, number)
	local best, bestD = nil, math.huge
	for _, m in pairs(machines) do
		local p = m.model:GetPivot().Position
		local d = (p - pos).Magnitude
		if d < bestD then
			best, bestD = m, d
		end
	end
	return best, bestD
end

function BreachFx.Start()
	for _, m in ipairs(CollectionService:GetTagged("BreachSite")) do
		addMachine(m)
	end
	CollectionService:GetInstanceAddedSignal("BreachSite"):Connect(addMachine)
	CollectionService:GetInstanceRemovedSignal("BreachSite"):Connect(function(m)
		machines[m] = nil
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
		local camPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero
		acc += dt
		for _, m in pairs(machines) do
			local st = stateOf(m.site)
			if st and m.model.Parent then
				local stage = st:GetAttribute("Stage") or "Cooldown"
				local ends = st:GetAttribute("StageEndsAt") or now
				local typ = st:GetAttribute("Type")
				local color = typeColor(m.site, if typ ~= "" then typ else nil)
				local stageLen = 1
				for _, s in ipairs(Breach.Stages) do
					if s.key == stage then
						stageLen = s.seconds
					end
				end
				local u = math.clamp(1 - (ends - now) / stageLen, 0, 1) -- progress through the stage
				local charge = if stage == "Charging" then u * 0.8 elseif stage == "Unstable" then 0.8 + u * 0.2 elseif stage == "Blast" then 1 else 0.05
				local close = (m.model:GetPivot().Position - camPos).Magnitude < 260
				if close then
					-- ring spin speeds up with the charge
					local speed = 0.4 + charge * 9
					m.angle = (m.angle + dt * speed) % (math.pi * 2)
					if m.ring and m.ringBase then
						local wobble = if stage == "Unstable" then CFrame.Angles(math.rad(math.sin(now * 40) * 2), 0, math.rad(math.cos(now * 37) * 2)) else CFrame.identity
						m.ring.CFrame = m.ringBase * wobble * CFrame.Angles(0, m.angle, 0)
					end
					if m.core and m.coreSize then
						local flicker = if stage == "Unstable" then 0.85 + math.random() * 0.3 else 1
						m.core.Size = m.coreSize * (0.55 + charge * 0.75) * flicker
						m.core.Color = color
						m.core.Transparency = 0.35 - charge * 0.3
					end
					for _, g in ipairs(m.glows) do
						g.Color = color:Lerp(Color3.new(1, 1, 1), if stage == "Unstable" then math.random() * 0.5 else 0)
					end
					if m.light then
						m.light.Color = color
						m.light.Brightness = 0.5 + charge * 3
						m.light.Range = 18 + charge * 22
					end
					if m.gather then
						m.gather.Enabled = stage == "Charging" or stage == "Unstable"
						m.gather.Color = ColorSequence.new(color)
						m.gather.Rate = if stage == "Unstable" then 60 else 25
					end
					if m.sparks then
						m.sparks.Enabled = stage == "Unstable"
						m.sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
					end
				end
				-- stage changes: sounds, shake, blast
				if stage ~= m.lastStage then
					local prev = m.lastStage
					m.lastStage = stage
					local d = if hrp then (m.model:GetPivot().Position - hrp.Position).Magnitude else math.huge
					if prev ~= nil and d < NEAR * 1.6 then
						if stage == "Charging" then
							Effects.Play("BreachCharge")
						elseif stage == "Unstable" then
							Effects.Play(if typ == "Rift" then "BreachAlarm" else "BreachCharge", 1.3)
							if d < NEAR then
								shake(0.25)
							end
						elseif stage == "Blast" then
							Effects.Play("BreachOpen")
							blastFx(m, color)
							if d < NEAR then
								shake(0.6)
							end
						end
					end
				end
			end
		end
		-- HUD meter for the Breach you're nearest to
		if acc >= 0.1 then
			acc = 0
			local m, d = nil, math.huge
			if hrp then
				m, d = nearestMachine(hrp.Position)
			end
			if m and d < NEAR and UI.SetBreachMeter then
				local st = stateOf(m.site)
				local stage = st and st:GetAttribute("Stage") or "Cooldown"
				local ends = st and st:GetAttribute("StageEndsAt") or now
				local typ = st and st:GetAttribute("Type") or ""
				local site = Breach.Sites[m.site]
				local title = if typ ~= "" and Breach.Types[typ] then Breach.Types[typ].title elseif site and site.spooky then "CAULDRON" else "BREACH"
				local left = math.max(0, ends - now)
				local text, fill
				if stage == "Charging" then
					text = ("%s CHARGING  %ds"):format(title, math.ceil(left + 3))
					fill = 1 - left / 8
				elseif stage == "Unstable" then
					text = ("%s UNSTABLE!  %ds"):format(title, math.ceil(left))
					fill = 0.85 + 0.15 * (1 - left / 3)
				elseif stage == "Blast" then
					text = "BLAST! GRAB THEM!"
					fill = 1
				else
					text = (if site and site.spooky then "Cauldron bubbling..." else "Goober Breach recharging...")
					fill = 0.02
				end
				UI.SetBreachMeter(true, text, math.clamp(fill, 0.02, 1), typeColor(m.site, if typ ~= "" then typ else nil), stage == "Unstable")
			elseif UI.SetBreachMeter then
				UI.SetBreachMeter(false)
			end
		end
	end)
end

return BreachFx

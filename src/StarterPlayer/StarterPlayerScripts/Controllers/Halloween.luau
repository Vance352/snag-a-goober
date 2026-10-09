--[[
	Halloween - the island on the client: portals (prompt or walk-through),
	candy pickups and buckets, level gates, night lighting, music zones and
	the first-arrival intro. Everything that grants something is only a
	request; the server checks distance, level and cooldowns itself.

	The island streams in and out (StreamingEnabled), so world objects are
	found by CollectionService tag / ProximityPromptService, never by
	walking the tree once.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Net = require(ReplicatedStorage.Shared.Net)

local Effects = require(script.Parent.Effects)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local HalloweenClient = {}
HalloweenClient.zone = "Main"

local CANDY_PICKUP = 6 -- studs; the server allows Halloween.CandyRadius
local PORTAL_WALK = 3.2 -- walking into the swirl also travels

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function data()
	return State.data
end

local function found(): { [string]: boolean }
	local s = data()
	local out = {}
	if s and s.event then
		for _, id in ipairs(s.event.candyFound) do
			out[id] = true
		end
	end
	return out
end

local function onIsland(pos: Vector3): boolean
	local o, size = Halloween.Origin, Halloween.Size
	return math.abs(pos.X - o.X) <= size.X / 2 + 12 and math.abs(pos.Z - o.Z) <= size.Y / 2 + 12
end

-- ------------------------------------------------------------- travel
local travelAt = -100
function HalloweenClient.Travel(dest: string)
	if os.clock() - travelAt < 1.5 then
		return
	end
	travelAt = os.clock()
	Net.Event("Travel"):FireServer(dest)
end

-- ------------------------------------------------------------ lighting
local day = nil -- Lighting properties to return to (tween goal, so only real properties)
local dayAtm = nil
local function nightLighting(on: boolean)
	local N = Halloween.Night
	if not day then
		day = {
			ClockTime = Lighting.ClockTime,
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			FogColor = Lighting.FogColor,
			FogStart = Lighting.FogStart,
			FogEnd = Lighting.FogEnd,
			ColorShift_Top = Lighting.ColorShift_Top,
		}
	end
	local goal = if on
		then { ClockTime = N.ClockTime, Brightness = N.Brightness, Ambient = N.Ambient, OutdoorAmbient = N.OutdoorAmbient, FogColor = N.FogColor, FogStart = N.FogStart, FogEnd = N.FogEnd, ColorShift_Top = N.ColorShift }
		else day
	Theme.tween(Lighting, 1.6, goal)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		if not dayAtm then
			dayAtm = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay, Haze = atm.Haze }
		end
		Theme.tween(atm, 1.6, if on then { Density = 0.42, Color = Color3.fromRGB(110, 70, 150), Decay = Color3.fromRGB(60, 30, 90), Haze = 2.2 } else dayAtm)
	end
end

local myPlot: Model? = nil
local function plotOf(): Model?
	if myPlot and myPlot.Parent and myPlot:GetAttribute("OwnerId") == player.UserId then
		return myPlot
	end
	myPlot = nil
	local plots = Workspace:FindFirstChild("Plots", true)
	for _, p in ipairs(if plots then plots:GetChildren() else {}) do
		if p:GetAttribute("OwnerId") == player.UserId and p:IsA("Model") then
			myPlot = p
		end
	end
	return myPlot
end

local function setZone(z: string)
	if z == HalloweenClient.zone then
		return
	end
	HalloweenClient.zone = z
	nightLighting(z == "Island")
	Effects.SetZone(z)
end

-- the highlighted travel tab: Island, or Base when you're at your own plot
local function tabZone(pos: Vector3): string
	if HalloweenClient.zone == "Island" then
		return "Island"
	end
	local p = plotOf()
	if p then
		local c = p:GetPivot().Position
		if math.abs(pos.X - c.X) < 30 and math.abs(pos.Z - c.Z) < 40 then
			return "Base"
		end
	end
	return "Plaza"
end

-- -------------------------------------------------------------- candy
local candies: { [Model]: { id: string, base: CFrame, phase: number } } = {}
local function styleCandy(m: Model, visible: boolean)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if visible then 0 else 1
		elseif d:IsA("PointLight") or d:IsA("Sparkles") then
			d.Enabled = visible
		end
	end
end

local function addCandy(m: Instance)
	if not m:IsA("Model") then
		return
	end
	local id = m:GetAttribute("Candy")
	if not id then
		return
	end
	candies[m] = { id = id, base = m:GetPivot(), phase = math.random() * 6.28 }
	styleCandy(m, not found()[id])
end

local requested: { [string]: number } = {}

-- --------------------------------------------------------------- gates
local function refreshGates()
	local s = data()
	local level = s and s.level or 1
	local evl = s and s.event and s.event.eventLevel or 0
	for _, b in ipairs(CollectionService:GetTagged("GateBarrier")) do
		if b:IsA("BasePart") then
			local open = level >= (b:GetAttribute("Level") or 1) and (evl >= (b:GetAttribute("EventLevel") or 0) or not Halloween.Active())
			b.CanCollide = not open
			b.LocalTransparencyModifier = if open then 1 else 0
		end
	end
end

-- ------------------------------------------------------------- prompts
local function onPrompt(prompt: ProximityPrompt)
	local part = prompt.Parent
	if not part then
		return
	end
	local dest = part:GetAttribute("Dest")
	if dest == "PortalIn" and not Halloween.Enabled then
		return
	end
	local bucket = part:GetAttribute("Bucket")
	if dest then
		HalloweenClient.Travel(dest)
	elseif bucket then
		Net.Event("Bucket"):FireServer(bucket)
	elseif part.Name == "PromptPart" and part.Parent then
		if part.Parent.Name == "CandyShop" then
			UI.Open("Halloween", "Shop")
		elseif part.Parent.Name == "QuestBoard" then
			UI.Open("Quests")
		end
	end
end

-- --------------------------------------------------------------- guide
-- a glowing trail to the Spooky Portal while "step through the portal" is the quest
local guideBeam: Beam? = nil
local guideA1: Attachment? = nil
local function updateGuide()
	local s = data()
	local q = s and s.quests
	local want = q and q.chainIndex == 1 and s.tutorial and s.tutorial >= 99 and HalloweenClient.zone == "Main"
	local root = hrp()
	if want and root then
		if not guideA1 then
			local anchor = Instance.new("Part")
			anchor.Name = "PortalGuideAnchor"
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one
			anchor.CFrame = CFrame.new(Halloween.MainPortal.pos + Vector3.new(0, 4, 0))
			anchor.Parent = Workspace
			guideA1 = Instance.new("Attachment")
			guideA1.Parent = anchor
		end
		if not guideBeam or not guideBeam.Parent or guideBeam.Attachment0 == nil or guideBeam.Attachment0.Parent ~= root then
			if guideBeam then
				if guideBeam.Attachment0 then
					guideBeam.Attachment0:Destroy()
				end
				guideBeam:Destroy()
			end
			local a0 = Instance.new("Attachment")
			a0.Name = "PortalGuide"
			a0.Parent = root
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = guideA1
			b.Width0 = 0.7
			b.Width1 = 0.7
			b.FaceCamera = true
			b.LightEmission = 1
			b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			b.TextureMode = Enum.TextureMode.Static
			b.TextureLength = 3
			b.TextureSpeed = 1.5
			b.Color = ColorSequence.new(Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 150, 40))
			b.Transparency = NumberSequence.new(0.25)
			b.Parent = root
			guideBeam = b
		end
	elseif guideBeam then
		if guideBeam.Attachment0 then
			guideBeam.Attachment0:Destroy()
		end
		guideBeam:Destroy()
		guideBeam = nil
	end
end

-- ------------------------------------------------------------- start
function HalloweenClient.Start()
	-- top travel tabs
	UI.OnTab = function(key: string)
		if key == "Island" and HalloweenClient.zone == "Island" then
			UI.Toast("You're already on Halloween Island!", "purple", 2)
			return
		end
		HalloweenClient.Travel(key)
	end
	for _, m in ipairs(CollectionService:GetTagged("Candy")) do
		addCandy(m)
	end
	CollectionService:GetInstanceAddedSignal("Candy"):Connect(addCandy)
	CollectionService:GetInstanceRemovedSignal("Candy"):Connect(function(m)
		candies[m] = nil
	end)
	CollectionService:GetInstanceAddedSignal("GateBarrier"):Connect(refreshGates)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player then
			onPrompt(prompt)
		end
	end)

	local lastLevel, lastFoundN = -1, -1
	State.Changed.Event:Connect(function(s)
		local key = s.level * 100 + (s.event and s.event.eventLevel or 0)
		if key ~= lastLevel then
			lastLevel = key
			refreshGates()
		end
		local n = s.event and #s.event.candyFound or 0
		if n ~= lastFoundN then
			lastFoundN = n
			local f = found()
			for m, c in pairs(candies) do
				styleCandy(m, not f[c.id])
			end
		end
		updateGuide()
	end)

	-- travel effect: fade + whoosh
	Net.Event("Effect").OnClientEvent:Connect(function(kind, p)
		if kind == "Travel" then
			Effects.Play("Portal")
			if UI.Fade then
				UI.Fade(0.15, 0.5)
			end
			setZone(if p and p.to == "Island" then "Island" else "Main")
			-- swing the camera behind you, looking away from the portal
			task.delay(0.12, function()
				local root = hrp()
				local cam = Workspace.CurrentCamera
				if root and cam then
					local look = root.CFrame.LookVector
					cam.CFrame = CFrame.lookAt(root.Position - look * 14 + Vector3.new(0, 7, 0), root.Position + look * 6)
				end
			end)
		end
	end)

	-- zone, candy pickup, walk-through portals and candy bobbing
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local root = hrp()
		local t = os.clock()
		if root then
			local pos = root.Position
			if acc >= 0.2 then
				acc = 0
				setZone(if onIsland(pos) then "Island" else "Main")
				UI.SetZone(tabZone(pos))
				-- walk-through portals
				for dest, portal in pairs(if Halloween.Enabled then { PortalIn = Halloween.MainPortal, PortalOut = Halloween.IslandPortal } else { PortalOut = Halloween.IslandPortal }) do
					local d = Vector2.new(pos.X - portal.pos.X, pos.Z - portal.pos.Z).Magnitude
					if d < PORTAL_WALK and pos.Y - portal.pos.Y < 12 then
						HalloweenClient.Travel(dest)
					end
				end
				-- candy within reach
				if HalloweenClient.zone == "Island" then
					local f = found()
					for _, c in ipairs(Halloween.Candies) do
						if not f[c.id] and (pos - c.pos).Magnitude < CANDY_PICKUP and t - (requested[c.id] or -10) > 2 then
							requested[c.id] = t
							Net.Event("CollectCandy"):FireServer(c.id)
						end
					end
				end
			end
			if HalloweenClient.zone == "Island" then
				for m, c in pairs(candies) do
					if m.Parent and (c.base.Position - pos).Magnitude < 90 then
						m:PivotTo(c.base * CFrame.new(0, 0.5 + math.sin(t * 2 + c.phase) * 0.4, 0) * CFrame.Angles(0, t * 1.4 + c.phase, 0))
					end
				end
			end
		end
	end)
	refreshGates()
end

return HalloweenClient

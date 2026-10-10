--[[
	World - everything the client does to world objects:
	  * flies, lands and hops loose Goobers from the Goober Breach along the
	    path the server gave them (the server computes the same position with
	    Shared/Breach to validate snags)
	  * creates the local ProximityPrompts: Snag / Grab (loose and dropped
	    Goobers), Sell (own stands), Steal (other bases), Upgrades
	  * idle-animates every nearby Goober
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Breach = require(ReplicatedStorage.Shared.Breach)
local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local World = {}
World.OpenUpgrades = nil :: (() -> ())?
World.OpenRebirth = nil :: (() -> ())?

local ANIM_RANGE = 130
local FAR_RANGE = 260 -- loose Goobers further than this from the camera aren't animated
local tracked: { [Model]: { phase: number, weld: Weld?, prompt: ProximityPrompt?, kind: string? } } = {}

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- ------------------------------------------------------------- prompts
local function makePrompt(model: Model, action: string, object: string, hold: number, key: Enum.KeyCode?): ProximityPrompt?
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return nil
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "LocalPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.UIOffset = Vector2.new(0, 0)
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.Parent = root
	return p
end

local function myLevel()
	local s = State.data
	return s and s.level or 1
end

local function loosePromptText(model: Model): (string, boolean)
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	local s = State.data
	local t = serverNow()
	local _, grounded = Breach.PositionAt(Breach.PathOf(model), t)
	if s and s.carry then
		return "Hands full", false
	end
	local dropped = model:GetAttribute("Mode") == "dropped"
	if dropped and t < (model:GetAttribute("DropLockUntil") or 0) then
		if model:GetAttribute("DroppedBy") == player.UserId then
			return "Dizzy...", false
		elseif model:GetAttribute("BlastedBy") == player.UserId then
			return "Recoiling...", false
		end
	end
	local reserved = model:GetAttribute("ReservedFor")
	if reserved and reserved ~= player.UserId then
		return "Reserved", false
	end
	local line = Config.Lines[model:GetAttribute("Line") or "Main"]
	if line and myLevel() < line.levelRequired then
		return ("Unlocks at Lv %d"):format(line.levelRequired), false
	end
	if not grounded then
		return "Incoming!", false
	end
	if dropped then
		return "GRAB IT!", true
	end
	local price = model:GetAttribute("Price") or def.price
	if s and s.coins < price then
		return ("Need $%s"):format(Util.Short(price)), false
	end
	return ("Snag  $%s"):format(Util.Short(price)), true
end

local function setupLoose(model: Model, info)
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	local text, enabled = loosePromptText(model)
	local p = makePrompt(model, text, def.name .. " • " .. def.rarity, 0)
	if p then
		p.Enabled = enabled
		p.MaxActivationDistance = 12
		p.Triggered:Connect(function()
			Net.Event("Snag"):FireServer(model:GetAttribute("Uid"))
		end)
		info.prompt = p
	end
	-- personal drop marker
	local reserved = model:GetAttribute("ReservedFor")
	if reserved then
		local mine = reserved == player.UserId
		local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
		if tag and not tag:FindFirstChild("Reserved") then
			local l = Instance.new("TextLabel")
			l.Name = "Reserved"
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 0.3)
			l.LayoutOrder = 0
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Text = if mine then "★ YOUR PERSONAL DROP ★" else (model:GetAttribute("ReservedName") or "?") .. "'s drop"
			l.TextColor3 = if mine then Color3.fromRGB(255, 230, 90) else Color3.fromRGB(200, 200, 210)
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = Color3.fromRGB(30, 18, 50)
			s.Parent = l
			l.Parent = tag
		end
		if mine and not model:FindFirstChild("MineHighlight") then
			local h = Instance.new("Highlight")
			h.Name = "MineHighlight"
			h.FillTransparency = 0.85
			h.OutlineColor = Color3.fromRGB(255, 230, 90)
			h.FillColor = Color3.fromRGB(255, 230, 90)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
		end
	end
	info.kind = "loose"
end

local function setupStand(model: Model, info)
	local owner = model:GetAttribute("OwnerId")
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	if owner == player.UserId then
		local refund = math.floor((model:GetAttribute("Paid") or def.price) * Config.SellRefund)
		local p = makePrompt(model, ("Sell  +$%s"):format(Util.Short(refund)), def.name, 0.8, Enum.KeyCode.F)
		if p then
			p.MaxActivationDistance = 7
			p.Triggered:Connect(function()
				Net.Event("Sell"):FireServer(model:GetAttribute("Uid"))
			end)
			info.prompt = p
		end
		info.kind = "own"
	else
		local p = makePrompt(model, "Steal!", def.name, Config.Steal.holdDuration, Enum.KeyCode.E)
		if p then
			p.MaxActivationDistance = 9
			p.PromptButtonHoldBegan:Connect(function()
				Net.Event("StealHold"):FireServer(model:GetAttribute("Uid"))
			end)
			p.Triggered:Connect(function()
				Net.Event("Steal"):FireServer(model:GetAttribute("Uid"))
			end)
			info.prompt = p
		end
		info.kind = "other"
	end
end

local function plotLockedFor(ownerId: number): boolean
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return false
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerId") == ownerId then
			return plot:GetAttribute("Locked") == true
		end
	end
	return false
end

-- Client-side hint only; the server re-checks every rule.
local function stealPromptState(model: Model): (boolean, string)
	local s = State.data
	if not s or s.carry then
		return false, ""
	end
	-- the prompt stays visible with the reason; the server re-checks every rule
	if s.level < Config.StealLevel then
		return true, ("Steal (Lv %d)"):format(Config.StealLevel)
	end
	if s.used and s.capacity and s.used >= s.capacity then
		return true, "Base full"
	end
	local ownerId = model:GetAttribute("OwnerId")
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner and (owner:GetAttribute("Level") or 1) < Config.StealLevel then
		return true, "New player - safe"
	end
	if plotLockedFor(ownerId) then
		return true, "Base locked"
	end
	local prot = (model:GetAttribute("ProtectedUntil") or 0) - serverNow()
	if prot > 0 then
		local secs = math.ceil(prot)
		return true, ("Protected %d:%02d"):format(secs // 60, secs % 60)
	end
	local pair = s.pairCooldowns and s.pairCooldowns[tostring(ownerId)]
	local wait = math.max(pair or 0, s.stealCooldown or 0)
	if wait > 0 then
		local secs = math.ceil(wait)
		return true, ("Steal in %d:%02d"):format(secs // 60, secs % 60)
	end
	return true, "Steal!"
end

-- ----------------------------------------------------------- animation
local function animOffset(style: string, t: number, phase: number, carried: boolean): CFrame
	t += phase
	local rad = math.rad
	if carried then
		return CFrame.new(0, math.abs(math.sin(t * 9)) * 0.15, 0) * CFrame.Angles(0, 0, rad(math.sin(t * 11) * 12))
	end
	if style == "wobble" then
		return CFrame.new(0, math.abs(math.sin(t * 3)) * 0.12, 0) * CFrame.Angles(0, 0, rad(math.sin(t * 3) * 9))
	elseif style == "slide" then
		return CFrame.new(math.sin(t * 1.4) * 0.25, 0, 0) * CFrame.Angles(0, rad(math.sin(t * 1.4) * 14), rad(math.sin(t * 2.8) * 4))
	elseif style == "hop" then
		local h = math.max(0, math.sin(t * 4))
		return CFrame.new(0, h * 0.7, 0) * CFrame.Angles(rad(-h * 8), 0, 0)
	elseif style == "bounce" then
		return CFrame.new(0, math.abs(math.sin(t * 3.4)) * 0.45, 0)
	elseif style == "sleepy" then
		return CFrame.new(0, math.sin(t * 1.1) * 0.05, 0) * CFrame.Angles(0, 0, rad(math.sin(t * 0.55) * 6))
	elseif style == "waddle" then
		return CFrame.new(0, math.abs(math.sin(t * 5)) * 0.1, 0) * CFrame.Angles(0, rad(math.sin(t * 2.5) * 12), rad(math.sin(t * 5) * 10))
	elseif style == "jelly" then
		return CFrame.Angles(rad(math.sin(t * 4.2) * 6), 0, rad(math.cos(t * 4.2) * 6))
	elseif style == "swim" then
		return CFrame.new(0, 0.25 + math.sin(t * 2) * 0.25, 0) * CFrame.Angles(rad(math.sin(t * 2) * 8), rad(math.sin(t) * 18), 0)
	elseif style == "wave" then
		return CFrame.Angles(0, rad(math.sin(t * 2) * 22), rad(math.sin(t * 4) * 5))
	elseif style == "float" then
		return CFrame.new(0, 0.55 + math.sin(t * 1.8) * 0.3, 0) * CFrame.Angles(0, rad(math.sin(t * 0.9) * 15), 0)
	elseif style == "dance" then
		return CFrame.new(0, math.abs(math.sin(t * 6)) * 0.3, 0) * CFrame.Angles(0, t * 2.5 % (math.pi * 2), rad(math.sin(t * 6) * 8))
	elseif style == "shuffle" then
		return CFrame.new(math.sin(t * 0.8) * 0.15, 0, 0) * CFrame.Angles(0, rad(math.sin(t * 0.8) * 16), rad(math.sin(t * 1.6) * 3))
	elseif style == "stoic" then
		return CFrame.new(0, math.sin(t * 0.6) * 0.04, 0)
	elseif style == "stomp" then
		local s = math.sin(t * 2.2)
		return CFrame.new(0, math.abs(s) * 0.3, 0) * CFrame.Angles(0, rad(math.sin(t * 0.5) * 20), rad(s * 7))
	elseif style == "spin" then
		return CFrame.new(0, 0.2 + math.sin(t * 2) * 0.15, 0) * CFrame.Angles(0, t * 1.4 % (math.pi * 2), 0)
	elseif style == "jitter" then
		local r = Random.new(math.floor(t * 12))
		local glitch = r:NextNumber() < 0.08
		return CFrame.new(r:NextNumber(-0.06, 0.06) + (if glitch then r:NextNumber(-0.5, 0.5) else 0), r:NextNumber(0, 0.08), 0)
			* CFrame.Angles(0, rad(if glitch then r:NextNumber(-60, 60) else 0), rad(r:NextNumber(-3, 3)))
	end
	return CFrame.new()
end

local function track(model: Model)
	if tracked[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local root = model:WaitForChild("Root", 5) :: BasePart
	if not root then
		return
	end
	local info = { phase = math.random() * 10, weld = root:FindFirstChild("Anim") :: Weld?, prompt = nil, kind = nil }
	tracked[model] = info
	local mode = model:GetAttribute("Mode")
	if mode == "loose" or mode == "dropped" then
		setupLoose(model, info)
	elseif mode == "stand" then
		setupStand(model, info)
	end
	model:GetAttributeChangedSignal("Mode"):Connect(function()
		if info.prompt then
			info.prompt:Destroy()
			info.prompt = nil
		end
		local m = model:GetAttribute("Mode")
		info.kind = m
		if m == "loose" or m == "dropped" then
			setupLoose(model, info)
		end
	end)
end

local function untrack(model: Model)
	tracked[model] = nil
end

-- -------------------------------------------------------------- start
function World.Start()
	for _, m in ipairs(CollectionService:GetTagged("Goober")) do
		task.spawn(track, m)
	end
	CollectionService:GetInstanceAddedSignal("Goober"):Connect(function(m)
		task.spawn(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Goober"):Connect(untrack)

	-- upgrade station prompt on my own plot
	task.spawn(function()
		local plots = Workspace:WaitForChild("Plots")
		local current: ProximityPrompt? = nil
		local function refresh()
			if current then
				current:Destroy()
				current = nil
			end
			for _, plot in ipairs(plots:GetChildren()) do
				if plot:GetAttribute("OwnerId") == player.UserId then
					local console = plot:FindFirstChild("UpgradeStation") and plot.UpgradeStation:FindFirstChild("Console")
					if console then
						local p = Instance.new("ProximityPrompt")
						p.ActionText = "Upgrades"
						p.ObjectText = "Slop-O-Matic"
						p.HoldDuration = 0
						p.MaxActivationDistance = 10
						p.RequiresLineOfSight = false
						p.Parent = console
						p.Triggered:Connect(function()
							if World.OpenUpgrades then
								World.OpenUpgrades()
							end
						end)
						current = p
					end
				end
			end
		end
		for _, plot in ipairs(plots:GetChildren()) do
			plot:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
		end
		refresh()
	end)

	local map = Workspace:WaitForChild("Map")

	-- Rebirth Shrine opens the rebirth panel
	task.spawn(function()
		local shrine = map:WaitForChild("RebirthShrine", 10)
		local spot = shrine and shrine:FindFirstChild("RebirthPrompt")
		if spot then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Rebirth"
			p.ObjectText = "Rebirth Shrine"
			p.HoldDuration = 0
			p.MaxActivationDistance = 16
			p.RequiresLineOfSight = false
			p.Parent = spot
			p.Triggered:Connect(function()
				if World.OpenRebirth then
					World.OpenRebirth()
				end
			end)
		end
	end)

	-- shop stalls (the Goober Mart): their prompt's part names a panel to open
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
		local panel = prompt.Parent and prompt.Parent:GetAttribute("OpenPanel")
		if who == player and type(panel) == "string" and World.OpenPanel then
			World.OpenPanel(panel)
		end
	end)

	-- the Chaos Rift wakes up during Goober Chaos events
	task.spawn(function()
		local rift = map:WaitForChild("ChaosRift", 10)
		if not rift then
			return
		end
		local light = rift:FindFirstChild("RiftLight", true) :: PointLight?
		local sparks = rift:FindFirstChild("RiftSparks", true) :: ParticleEmitter?
		local function apply()
			local active = (ReplicatedStorage:GetAttribute("ChaosType") or "") ~= ""
			if light then
				light.Brightness = if active then 4 else 0.5
				light.Range = if active then 60 else 40
			end
			if sparks then
				sparks.Rate = if active then 60 else 4
			end
		end
		ReplicatedStorage:GetAttributeChangedSignal("ChaosType"):Connect(apply)
		apply()
	end)

	local promptTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = serverNow()
		local t = os.clock()
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		promptTimer += dt
		local refreshPrompts = promptTimer > 0.25
		if refreshPrompts then
			promptTimer = 0
		end
		for model, info in pairs(tracked) do
			local root = model.PrimaryPart
			if not root or not model.Parent then
				tracked[model] = nil
				continue
			end
			local mode = model:GetAttribute("Mode")
			if mode == "loose" or mode == "dropped" then
				-- fly / land / hop along the server's plan
				local pos = Breach.PositionAt(Breach.PathOf(model), now)
				if info.lastPos and (pos - camPos).Magnitude > FAR_RANGE then
					continue -- far away (e.g. the island while you're in the hub): not worth animating
				end
				local last = info.lastPos or pos
				local flat = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z)
				if flat.Magnitude > 0.05 then
					info.face = flat.Unit
				end
				info.lastPos = pos
				local face = info.face or Vector3.new(0, 0, -1)
				-- spin in the air while flying
				local spin = if pos.Y > (model:GetAttribute("GroundY") or 0) + 0.6 then CFrame.Angles(0, t * 8, 0) else CFrame.identity
				root.CFrame = CFrame.lookAt(pos, pos + face) * spin
				if refreshPrompts and info.prompt then
					local text, enabled = loosePromptText(model)
					info.prompt.ActionText = text
					info.prompt.Enabled = enabled
					-- a knocked-loose Goober has to be reached (BreachService checks the same)
					info.prompt.MaxActivationDistance = if mode == "dropped" then Breach.DropSnagRange else 12
				end
			elseif mode == "stand" and refreshPrompts and info.prompt and info.kind == "other" then
				local ok, text = stealPromptState(model)
				info.prompt.Enabled = ok
				info.prompt.ActionText = text
			end
			if info.weld and (root.Position - camPos).Magnitude < ANIM_RANGE then
				info.weld.C0 = animOffset(model:GetAttribute("Anim") or "wobble", t, info.phase, mode == "carried")
			end
		end
	end)
end

return World

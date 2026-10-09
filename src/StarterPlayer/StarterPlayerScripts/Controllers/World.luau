--[[
	World - everything the client does to world objects:
	  * moves belt Goobers along the conveyor from their spawn time (the
	    server computes the same position to validate snags)
	  * scrolls the belt chevron textures
	  * creates the local ProximityPrompts: Snag (belt), Sell (own stands),
	    Steal (other bases), Upgrades (own Slop-O-Matic)
	  * idle-animates every nearby Goober
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local World = {}
World.OpenUpgrades = nil :: (() -> ())?

local ANIM_RANGE = 130
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

local function beltPromptText(model: Model): (string, boolean)
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	local s = State.data
	local reserved = model:GetAttribute("ReservedFor")
	if reserved and reserved ~= player.UserId then
		return "Reserved", false
	end
	local line = Config.Lines[model:GetAttribute("Line") or "Main"]
	if myLevel() < line.levelRequired then
		return ("Unlocks at Lv %d"):format(line.levelRequired), false
	end
	local price = def.price
	if s and s.coins < price then
		return ("Need $%s"):format(Util.Short(price)), true
	end
	return ("Snag  $%s"):format(Util.Short(price)), true
end

local function setupBelt(model: Model, info)
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	local text, enabled = beltPromptText(model)
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
		if tag then
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
		if mine then
			local h = Instance.new("Highlight")
			h.Name = "MineHighlight"
			h.FillTransparency = 0.85
			h.OutlineColor = Color3.fromRGB(255, 230, 90)
			h.FillColor = Color3.fromRGB(255, 230, 90)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
		end
	end
	info.kind = "belt"
end

local function setupStand(model: Model, info)
	local owner = model:GetAttribute("OwnerId")
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	if owner == player.UserId then
		local refund = math.floor(def.price * Config.SellRefund)
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
	if not s then
		return false, ""
	end
	if s.level < Config.StealLevel then
		return false, ""
	end
	if s.carry then
		return false, ""
	end
	local ownerId = model:GetAttribute("OwnerId")
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner and (owner:GetAttribute("Level") or 1) < Config.StealLevel then
		return false, ""
	end
	if plotLockedFor(ownerId) then
		return false, ""
	end
	local prot = (model:GetAttribute("ProtectedUntil") or 0) - serverNow()
	if prot > 0 then
		return false, ""
	end
	if s.stealCooldown > 0 then
		return true, ("Steal (%ds)"):format(math.ceil(s.stealCooldown))
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
	if mode == "belt" then
		setupBelt(model, info)
	elseif mode == "stand" then
		setupStand(model, info)
	end
	model:GetAttributeChangedSignal("Mode"):Connect(function()
		if info.prompt then
			info.prompt:Destroy()
			info.prompt = nil
		end
		info.kind = model:GetAttribute("Mode")
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

	local chevrons = {}
	local map = Workspace:WaitForChild("Map")
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("Texture") and d.Name == "Chevrons" then
			table.insert(chevrons, d)
		end
	end

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
			if mode == "belt" then
				local x = model:GetAttribute("StartX") + model:GetAttribute("Dir") * model:GetAttribute("Speed") * (now - model:GetAttribute("SpawnT"))
				local pos = Vector3.new(x, model:GetAttribute("BeltY"), model:GetAttribute("BeltZ"))
				local face = if model:GetAttribute("Line") == "Main" then -1 else 1
				root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, face))
				if refreshPrompts and info.prompt then
					local text, enabled = beltPromptText(model)
					info.prompt.ActionText = text
					info.prompt.Enabled = enabled
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
		for _, tex in ipairs(chevrons) do
			local dir = tex.Parent:GetAttribute("Dir") or 1
			local speed = if tex.Parent.Parent and tex.Parent.Parent.Name == "GoldLine" then Config.Lines.Gold.speed else Config.Lines.Main.speed
			tex.OffsetStudsU = (now * speed * dir) % tex.StudsPerTileU
		end
	end)
end

return World

--[[
	CharacterService - spawning at your own base, walk speed, overhead name
	tags (level, rebirth stars, title, VIP, THIEF!) and VIP cosmetics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local Util = require(ReplicatedStorage.Shared.Util)

local CharacterService = {}
local S

function CharacterService.Init(registry)
	S = registry
end

function CharacterService.ApplySpeed(player: Player)
	local st = S.Session.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not st or not hum then
		return
	end
	local carry = st.carry
	-- Sprint Boots help you reach the Breach and chase - not outrun everyone
	-- while carrying a Breach Goober (paid speed must not make deliveries risk-free)
	-- ...and they rest for a moment after you fire the Goober Blaster, so the
	-- race for a knocked-loose Goober is never won by a paid pass
	local boots = st.passes.SprintBoots == true and not (carry and carry.source == "belt") and os.clock() >= (st.bootsRestUntil or 0)
	local speed = Util.WalkSpeed(st.data.upgrades.Speed, boots)
	if carry and carry.source == "steal" then
		speed *= Config.Steal.carrySpeedMult
	elseif carry then
		-- heavier Goobers slow you down a little, so rare ones can be chased
		local def = GooberData.ById[carry.id]
		speed *= Config.CarrySpeed[def and def.rarity or "Common"] or 1
	end
	if os.clock() < st.stunnedUntil then
		speed = 0
	end
	hum.WalkSpeed = speed
end

local function makeTag(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "OverheadTag"
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function label(name, h, order)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.LayoutOrder = order
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Color = Color3.fromRGB(30, 18, 50)
		s.Parent = t
		t.Parent = gui
		return t
	end
	label("Thief", 18, 0).TextColor3 = Color3.fromRGB(255, 70, 70)
	label("Title", 14, 1).TextColor3 = Color3.fromRGB(255, 214, 80)
	label("Name", 20, 2)
	label("Level", 14, 3).TextColor3 = Color3.fromRGB(160, 255, 140)
	return gui
end

function CharacterService.RefreshTag(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local st = S.Session.Get(player)
	if not head or not st then
		return
	end
	local tag = head:FindFirstChild("OverheadTag") :: BillboardGui
	if not tag then
		tag = makeTag()
		tag.Parent = head
	end
	local vip = st.passes.VIP == true
	local d = st.data
	local name = tag:FindFirstChild("Name") :: TextLabel
	name.Text = (if vip then "[VIP] " else "") .. player.DisplayName
	name.TextColor3 = if vip then Color3.fromRGB(255, 214, 80) else Color3.new(1, 1, 1)
	-- Goober Glam: a shimmering rainbow name
	local grad = name:FindFirstChild("GlamGradient")
	if st.passes.Glam and not grad then
		grad = Instance.new("UIGradient")
		grad.Name = "GlamGradient"
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 210, 255)),
		})
		grad.Parent = name
		name.TextColor3 = Color3.new(1, 1, 1)
	end
	local stars = if d.rebirths > 0 then ("  ★" .. d.rebirths) else ""
	;(tag:FindFirstChild("Level") :: TextLabel).Text = ("Lv %d%s"):format(d.level, stars)
	;(tag:FindFirstChild("Title") :: TextLabel).Text = d.title or ""
	local thief = st.carry ~= nil and st.carry.source == "steal"
	local thiefLabel = tag:FindFirstChild("Thief") :: TextLabel
	if thief then
		thiefLabel.Text = "THIEF!"
		thiefLabel.TextColor3 = Color3.fromRGB(255, 80, 100)
	elseif st.carry then
		-- carrying Breach loot: everyone can see what's worth chasing
		local def = GooberData.ById[st.carry.id]
		thiefLabel.Text = if def then ("CARRYING %s!"):format(string.upper(def.rarity)) else ""
		thiefLabel.TextColor3 = if def then Config.Rarities[def.rarity].color else Color3.new(1, 1, 1)
	else
		thiefLabel.Text = ""
	end
	player:SetAttribute("VIP", vip)
	CharacterService.ApplyBlaster(player)
end

-- ------------------------------------------------------- the Goober Blaster
-- Built on the server (welded at the right hip) so everyone can see who's
-- armed - and whose Blaster is golden (Goober Glam). It's put away while you
-- carry a Goober, like the BLAST button.
local GOO = Color3.fromRGB(123, 227, 90)

local function buildBlaster(gold: boolean): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local tpl = props and props:FindFirstChild("P_GooBlaster")
	local m: Model
	if tpl and tpl:IsA("Model") and tpl.PrimaryPart then
		m = tpl:Clone()
		m:ScaleTo(0.55)
	else
		-- simple built-in stand-in (until the Blender model is imported)
		m = Instance.new("Model")
		local function p(name, size, cf, color, mat, shape)
			local x = Instance.new("Part")
			x.Name = name
			x.Size = size
			x.CFrame = cf
			x.Color = color
			x.Material = mat or Enum.Material.SmoothPlastic
			if shape then
				x.Shape = shape
			end
			x.Parent = m
			return x
		end
		local body = p("Body", Vector3.new(0.7, 0.75, 1.9), CFrame.new(0, 0, 0), Color3.fromRGB(110, 70, 190))
		p("Tank", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.7, 0.2), GOO, Enum.Material.Neon, Enum.PartType.Ball)
		p("Nozzle", Vector3.new(0.9, 0.45, 0.45), CFrame.new(0, 0.05, -1.25) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 201, 60), nil, Enum.PartType.Cylinder)
		p("Grip", Vector3.new(0.35, 0.8, 0.45), CFrame.new(0, -0.6, 0.45) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(40, 28, 60))
		m.PrimaryPart = body
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if gold and d.Material ~= Enum.Material.Neon then
				d.Color = Color3.fromRGB(255, 196, 61)
				d.Material = Enum.Material.Foil
			end
			if d ~= m.PrimaryPart then
				local w = Instance.new("WeldConstraint")
				w.Part0 = m.PrimaryPart
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	m.Name = "GooBlaster"
	m:SetAttribute("Gold", gold)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0.05, -1.6)
	tip.Parent = m.PrimaryPart
	return m
end

function CharacterService.ApplyBlaster(player: Player)
	local st = S.Session.Get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not st or not root then
		return
	end
	local want = st.ready and st.carry == nil and st.data.level >= Config.Combat.minLevel and st.data.tutorial == Tutorial.DONE
	local gold = st.passes.Glam == true
	local have = char:FindFirstChild("GooBlaster")
	if have and (not want or have:GetAttribute("Gold") ~= gold) then
		have:Destroy()
		have = nil
	end
	if want and not have then
		local gun = buildBlaster(gold)
		gun:PivotTo(root.CFrame * CFrame.new(1.25, -0.25, -0.7))
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = gun.PrimaryPart
		w.Parent = gun.PrimaryPart
		gun.Parent = char
	end
end

function CharacterService.ApplyVIP(player: Player)
	local st = S.Session.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not st or not hrp or not st.passes.VIP or hrp:FindFirstChild("VIPTrail") or st.passes.Glam then
		return -- (Goober Glam's rainbow trail replaces the VIP one)
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "VIPTrailA0"
	a0.Position = Vector3.new(0, 0.8, 0.4)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "VIPTrailA1"
	a1.Position = Vector3.new(0, -1.4, 0.4)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "VIPTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
	})
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = hrp
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "VIPSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120))
	sparkles.LightEmission = 0.8
	sparkles.Parent = hrp
end

-- Goober Glam (cosmetic): rainbow glitter trail + the "Glam" attribute the
-- client reads for the golden Goober Blaster and delivery glitter
function CharacterService.ApplyGlam(player: Player)
	local st = S.Session.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not st or not st.passes.Glam then
		return
	end
	player:SetAttribute("Glam", true)
	if not hrp or hrp:FindFirstChild("GlamTrail") then
		return
	end
	for _, n in ipairs({ "VIPTrail", "VIPSparkles" }) do
		local old = hrp:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local a0 = hrp:FindFirstChild("GlamA0") or Instance.new("Attachment")
	a0.Name = "GlamA0"
	a0.Position = Vector3.new(0, 0.9, 0.4)
	a0.Parent = hrp
	local a1 = hrp:FindFirstChild("GlamA1") or Instance.new("Attachment")
	a1.Name = "GlamA1"
	a1.Position = Vector3.new(0, -1.5, 0.4)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "GlamTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.7
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(123, 227, 90)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
	})
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Parent = hrp
	local glitter = Instance.new("ParticleEmitter")
	glitter.Name = "GlamGlitter"
	glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glitter.Rate = 8
	glitter.Lifetime = NumberRange.new(0.5, 0.9)
	glitter.Speed = NumberRange.new(0.5, 2)
	glitter.Size = NumberSequence.new(0.3, 0)
	glitter.Color = ColorSequence.new(Color3.fromRGB(255, 160, 220), Color3.fromRGB(160, 220, 255))
	glitter.LightEmission = 0.9
	glitter.Parent = hrp
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not hum or not hrp then
		return
	end
	S.MoveGuard.OnSpawn(player) -- trust only where the server spawned the character
	-- wait until the session (and plot) exist
	local t0 = os.clock()
	while not (S.Session.Get(player) and S.Session.Get(player).ready) and os.clock() - t0 < 30 do
		task.wait(0.1)
	end
	local cf = S.Plot.SpawnCFrame(player)
	if cf then
		task.defer(function()
			S.MoveGuard.ServerMove(player, cf)
		end)
	end
	CharacterService.ApplySpeed(player)
	CharacterService.RefreshTag(player)
	CharacterService.ApplyVIP(player)
	CharacterService.ApplyGlam(player)
	hum.Died:Connect(function()
		S.Carry.Settle(player, "died")
	end)
	S.Combat.OnSpawn(player)
end

function CharacterService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	-- the Blaster also appears at moments that don't refresh the tag (finishing the tutorial)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				CharacterService.ApplyBlaster(p)
			end
		end
	end)

end

return CharacterService

--[[
	CharacterService - spawning at your own base, walk speed, overhead name
	tags (level, rebirth stars, title, VIP, THIEF!) and VIP cosmetics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
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
	local speed = Util.WalkSpeed(st.data.upgrades.Speed, st.passes.SprintBoots == true and not (carry and carry.source == "belt"))
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
	local stars = if d.rebirths > 0 then ("  ★" .. d.rebirths) else ""
	;(tag:FindFirstChild("Level") :: TextLabel).Text = ("Lv %d%s"):format(d.level, stars)
	;(tag:FindFirstChild("Title") :: TextLabel).Text = d.title or ""
	local thief = st.carry ~= nil and st.carry.source == "steal"
	;(tag:FindFirstChild("Thief") :: TextLabel).Text = if thief then "THIEF!" else ""
	player:SetAttribute("VIP", vip)
end

function CharacterService.ApplyVIP(player: Player)
	local st = S.Session.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not st or not hrp or not st.passes.VIP or hrp:FindFirstChild("VIPTrail") then
		return
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
end

return CharacterService

--[[
	Effects - sounds, particle bursts, floating numbers and camera kicks.
	Purely cosmetic and local.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Effects = {}
local sounds: { [string]: Sound } = {}
local sfxOn = true
local musicOn = true
local music: Sound? = nil

local VOLUME = {
	Snag = 0.6,
	Place = 0.6,
	Coin = 0.45,
	Upgrade = 0.6,
	LevelUp = 0.7,
	Rare = 0.7,
	Legendary = 0.8,
	StealAlarm = 0.55,
	Caught = 0.7,
	StealSuccess = 0.7,
	Rebirth = 0.8,
	Event = 0.7,
	Click = 0.35,
	Error = 0.4,
}

function Effects.Start()
	local group = Instance.new("SoundGroup")
	group.Name = "SFX"
	group.Parent = SoundService
	local A = Config.Audio
	for name, region in pairs(A.Regions) do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = A.Sprite
		s.Volume = VOLUME[name] or 0.5
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
		s.SoundGroup = group
		s.Parent = SoundService
		sounds[name] = s
	end
	if A.Music ~= "" then
		music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = A.Music
		music.Looped = true
		music.Volume = 0.22
		music.Parent = SoundService
		music:Play()
	end
end

function Effects.SetSettings(settings)
	if not settings then
		return
	end
	sfxOn = settings.sfx ~= false
	musicOn = settings.music ~= false
	if music then
		music.Playing = musicOn
	end
end

function Effects.Play(name: string, pitch: number?)
	if not sfxOn then
		return
	end
	local s = sounds[name]
	if not s then
		return
	end
	-- clone so overlapping plays of the same effect don't cut each other off
	local c = s:Clone()
	c.PlaybackSpeed = pitch or 1
	c.Parent = SoundService
	c:Play()
	Debris:AddItem(c, 4)
end

local function anchorAt(pos: Vector3): (Part, Attachment)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = Workspace
	local a = Instance.new("Attachment")
	a.Parent = p
	return p, a
end

function Effects.Burst(pos: Vector3, color: Color3, count: number?, size: number?)
	local p, a = anchorAt(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.7
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = a
	e:Emit(count or 24)
	Debris:AddItem(p, 1.5)
end

function Effects.Coins(pos: Vector3, count: number?)
	local p, a = anchorAt(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Theme.C.gold)
	e.LightEmission = 0.5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	e.Lifetime = NumberRange.new(0.7, 1.1)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = a
	e:Emit(count or 18)
	Debris:AddItem(p, 2)
end

function Effects.FloatText(pos: Vector3, text: string, color: Color3?, big: boolean?)
	local p = anchorAt(pos)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(if big then 8 else 5, if big then 2.2 else 1.4)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	local t = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color or Theme.C.gold,
		MaxText = 60,
		Parent = gui,
	})
	gui.Parent = p
	local start = pos
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local a = (os.clock() - t0) / 1.2
		if a >= 1 then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.CFrame = CFrame.new(start + Vector3.new(0, a * 3, 0))
		t.TextTransparency = math.max(0, (a - 0.6) / 0.4)
	end)
end

function Effects.Kick(strength: number?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local s = strength or 0.4
	task.spawn(function()
		for i = 1, 6 do
			local k = s * (1 - i / 6)
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * k * 4), math.rad((math.random() - 0.5) * k * 4), 0)
			task.wait()
		end
	end)
end

function Effects.Pop(gui: GuiObject)
	local s = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = gui
	s.Scale = 1.25
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return Effects

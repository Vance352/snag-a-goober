--[[
	Guide - the first-minute tutorial. No text walls: one short hint pill, a
	glowing beam from the player to the next target and a bouncing arrow over
	it. Steps only advance when the server sees the real action happen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Net = require(ReplicatedStorage.Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local Guide = {}

local beam: Beam? = nil
local a0: Attachment? = nil
local a1: Attachment? = nil
local holder: Part? = nil
local arrow: BillboardGui? = nil
local tipsShown = false

local function myPlot(): Model?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, p in ipairs(plots:GetChildren()) do
		if p:GetAttribute("OwnerId") == player.UserId then
			return p :: Model
		end
	end
	return nil
end

local function ensure()
	if holder then
		return
	end
	holder = Instance.new("Part")
	holder.Name = "GuideTarget"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = Workspace
	a1 = Instance.new("Attachment")
	a1.Parent = holder
	a0 = Instance.new("Attachment")
	beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Width0 = 1.4
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Color = ColorSequence.new(Color3.fromRGB(150, 255, 110), Color3.fromRGB(255, 240, 120))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	beam.Segments = 20
	beam.CurveSize0 = 4
	beam.CurveSize1 = -2
	beam.Parent = holder
	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(120, 90)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	arrow.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	local t = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = Color3.fromRGB(150, 255, 110), MaxText = 80, Stroke = 4 })
	t.Name = "Arrow"
	t.Parent = arrow
	arrow.Parent = holder
end

local function hide()
	if beam then
		beam.Enabled = false
	end
	if arrow then
		arrow.Enabled = false
	end
	UI.refs.hint.Visible = false
end

local function findGrabTarget(): BasePart?
	local field = Workspace:FindFirstChild("LooseGoobers")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not field or not hrp then
		return nil
	end
	local s = State.data
	local best, bestScore = nil, math.huge
	for _, m in ipairs(field:GetChildren()) do
		local root = m:FindFirstChild("Root") :: BasePart
		if root then
			local reserved = m:GetAttribute("ReservedFor")
			local def = GooberData.ById[m:GetAttribute("GooberId")]
			local mine = reserved == player.UserId
			local price = m:GetAttribute("Price") or def.price
			local ok = (mine or not reserved) and m:GetAttribute("Line") == "Main" and m:GetAttribute("Mode") == "loose" and (s == nil or price <= s.coins)
			if ok then
				local score = (root.Position - hrp.Position).Magnitude - (if mine then 1000 else 0)
				-- prefer Goobers that won't dive back into the Breach any second
				if (m:GetAttribute("Expire") or math.huge) - Workspace:GetServerTimeNow() < 8 then
					score += 500
				end
				if score < bestScore then
					best, bestScore = root, score
				end
			end
		end
	end
	return best
end

local function showTips()
	if tipsShown or UI.openPanel ~= nil then
		return -- wait until the player closes the panel they're in
	end
	tipsShown = true
	UI.Banner("YOU'RE A GOOBER BOSS!", "Rarer Goobers earn way more  •  Steal from other bases at Lv 3  •  Rebirth at Lv 15", Color3.fromRGB(150, 255, 110), 7)
	task.delay(7, function()
		Net.Event("TutorialAck"):FireServer(Tutorial.Tips)
	end)
end

function Guide.Start()
	ensure()
	hide()
	RunService.Heartbeat:Connect(function()
		local s = State.data
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
		if not s or not hrp or s.tutorial >= Tutorial.Tips then
			hide()
			if s and s.tutorial == Tutorial.Tips then
				showTips()
			end
			return
		end
		if a0.Parent ~= hrp then
			a0.Parent = hrp
			beam.Attachment0 = a0
		end
		local plot = myPlot()
		local target: Vector3? = nil
		local step = s.tutorial
		local hintText = Tutorial.Hints[step]
		if step == Tutorial.Grab or (step == Tutorial.Home and not s.carry) then
			local root = findGrabTarget()
			target = root and root.Position
			hintText = Tutorial.Hints[Tutorial.Grab]
		elseif step == Tutorial.Home and plot then
			local sign = plot:FindFirstChild("Spawn") :: BasePart
			target = sign and sign.Position
		elseif step == Tutorial.Collect and plot then
			local pad = plot:FindFirstChild("CashPad") :: BasePart
			target = pad and pad.Position
			if s.bank < 1 then
				hintText = "Your Goober makes coins! Visit the Cash Pad."
			end
		elseif step == Tutorial.Upgrade and plot then
			local st = plot:FindFirstChild("UpgradeStation")
			local console = st and st:FindFirstChild("Console") :: BasePart
			target = console and console.Position
			local cheapest = 50
			if s.coins < cheapest then
				hintText = ("Get $%d, then buy Zoomies!"):format(cheapest)
			end
		end
		UI.refs.hint.Visible = true
		UI.refs.hintText.Text = hintText or ""
		if target then
			holder.CFrame = CFrame.new(target + Vector3.new(0, 1.5, 0))
			beam.Enabled = true
			arrow.Enabled = true
			arrow.StudsOffsetWorldSpace = Vector3.new(0, 4 + math.abs(math.sin(os.clock() * 4)) * 1.2, 0)
		else
			beam.Enabled = false
			arrow.Enabled = false
		end
	end)
end

return Guide

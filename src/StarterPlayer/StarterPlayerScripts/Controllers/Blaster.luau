--[[
	Blaster - the Goober Blaster on the client: input, aiming, the gun in your
	hand, the shot and splat effects, and hit feedback.

	Controls: PC click or Q · controller R2 · touch: the BLAST button.
	Touch and controller auto-aim at the nearest Goober carrier in front of you.

	The client only sends "I fired, aiming here". The server picks the target
	and decides the hit (CombatService); a hit is only shown as a hit when the
	server confirms it (HitConfirm / BlastHit).
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

local Effects = require(script.Parent.Effects)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local Blaster = {}
local C = Config.Combat
local GOO = Color3.fromRGB(123, 227, 90)

local readyAt = 0
local gun: Model? = nil
local lockedToastAt = -100

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function canUse(): boolean
	local s = State.data
	return s ~= nil and s.level >= C.minLevel and s.tutorial == Tutorial.DONE and s.carry == nil
end

-- --------------------------------------------------------------- the gun
-- The gun itself is built by the server (CharacterService.ApplyBlaster) so
-- everyone sees it; the client just finds it for the muzzle position.
local function refreshGun()
	local char = player.Character
	gun = if char then char:FindFirstChild("GooBlaster") :: Model? else nil
end

-- -------------------------------------------------------------- effects
local function splat(pos: Vector3, big: boolean)
	Effects.Burst(pos, GOO, if big then 40 else 14, if big then 1.1 else 0.6)
end

-- draw a shot: a goo blob flying from `from` along `dir`
function Blaster.DrawShot(from: Vector3, dir: Vector3)
	local blob = Instance.new("Part")
	blob.Shape = Enum.PartType.Ball
	blob.Size = Vector3.new(1.1, 1.1, 1.1)
	blob.Material = Enum.Material.Neon
	blob.Color = GOO
	blob.Anchored = true
	blob.CanCollide = false
	blob.CanQuery = false
	blob.CanTouch = false
	blob.CFrame = CFrame.new(from)
	blob.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, blob, Workspace:FindFirstChild("LooseGoobers") }
	local hit = Workspace:Raycast(from, dir * C.range, params)
	local to = if hit then hit.Position else from + dir * C.range
	local tw = TweenService:Create(blob, TweenInfo.new(0.16, Enum.EasingStyle.Linear), { CFrame = CFrame.new(to), Size = Vector3.new(0.6, 0.6, 0.6) })
	tw:Play()
	tw.Completed:Connect(function()
		splat(to, false)
		blob:Destroy()
	end)
	Debris:AddItem(blob, 1)
end

-- ----------------------------------------------------------------- aim
local function autoTarget(origin: Vector3, look: Vector3): Vector3?
	-- nearest player carrying a Goober in range and roughly in front of you
	local best, bestD = nil, math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("Carrying") then
			local c = other.Character
			local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart
			if r then
				local off = r.Position - origin
				local d = off.Magnitude
				if d <= C.range and d > 0.1 and Vector3.new(off.X, 0, off.Z).Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.2 and d < bestD then
					best, bestD = off.Unit, d
				end
			end
		end
	end
	return best
end

local function aimDirection(fromMouse: boolean): Vector3?
	local root = hrp()
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	if fromMouse then
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		local point = if hit then hit.Position else ray.Origin + ray.Direction * 300
		local off = point - root.Position
		if off.Magnitude > 0.5 then
			-- a carrier near where you clicked wins (forgiving aim)
			return autoTarget(root.Position, off.Unit) or Vector3.new(off.X, math.clamp(off.Y / off.Magnitude, -0.3, 0.3) * off.Magnitude, off.Z).Unit
		end
	end
	local look = cam.CFrame.LookVector
	return autoTarget(root.Position, look) or Vector3.new(look.X, 0, look.Z).Unit
end

-- ----------------------------------------------------------------- fire
function Blaster.Fire(fromMouse: boolean)
	if not canUse() then
		local s = State.data
		if s and s.carry == nil and s.level < C.minLevel and os.clock() - lockedToastAt > 15 then
			lockedToastAt = os.clock() -- (once in a while, not on every click)
			UI.Toast(("The Goober Blaster unlocks at Level %d!"):format(C.minLevel), "purple", 2)
		end
		return
	end
	local t = os.clock()
	if t < readyAt then
		return
	end
	local root = hrp()
	local dir = aimDirection(fromMouse)
	if not root or not dir then
		return
	end
	readyAt = t + C.cooldown
	-- turn to face the shot so everyone can read it
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
	refreshGun()
	local tip = gun and gun.PrimaryPart and gun.PrimaryPart:FindFirstChild("Tip") :: Attachment?
	local from = if tip then tip.WorldPosition else root.Position + Vector3.new(0, 1.2, 0) + flat.Unit * 1.5
	Blaster.DrawShot(from, dir)
	Effects.Play("Blast")
	Net.Event("Blast"):FireServer(dir)
	if UI.BlastCooldown then
		UI.BlastCooldown(C.cooldown)
	end
end

-- --------------------------------------------------------------- start
function Blaster.Start()
	-- PC: click (not on UI) / Q; controller: R2
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Blaster.Fire(true)
		end
	end)
	ContextActionService:BindAction("GooBlast", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Blaster.Fire(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
	-- touch: the HUD button
	if UI.MakeBlastButton then
		UI.MakeBlastButton(function()
			Blaster.Fire(false)
		end)
	end

	-- the gun appears when you can use it
	State.Changed.Event:Connect(function()
		refreshGun()
		if UI.ShowBlastButton then
			UI.ShowBlastButton(canUse() and UserInputService.TouchEnabled)
		end
	end)
	player.CharacterAdded:Connect(function()
		gun = nil
	end)

	-- other players' shots and confirmed hits
	Net.Event("Effect").OnClientEvent:Connect(function(kind, p)
		if kind == "BlastFx" and p and p.by ~= player.UserId and p.from and p.dir then
			local cam = Workspace.CurrentCamera
			if cam and (cam.CFrame.Position - p.from).Magnitude < 200 then
				Blaster.DrawShot(p.from + Vector3.new(0, 1.2, 0), p.dir)
				Effects.Play("Blast", 0.95)
			end
		elseif kind == "BlastHit" and p and p.pos then
			splat(p.pos + Vector3.new(0, 1.5, 0), true)
			Effects.Play("Hit")
			if p.target == player.UserId then
				Effects.Kick(0.9)
			end
		end
	end)
end

return Blaster

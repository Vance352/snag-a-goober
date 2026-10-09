--[[
	Snag A Goober - client entry point.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local State = require(Controllers.State)
local Effects = require(Controllers.Effects)
local UI = require(Controllers.UI)
local World = require(Controllers.World)
local Guide = require(Controllers.Guide)
local Feedback = require(Controllers.Feedback)
local Chat = require(Controllers.Chat)

State.Start()
Effects.Start()
UI.Start()
World.OpenUpgrades = function()
	UI.Open("Upgrades")
end
World.OpenRebirth = function()
	UI.Open("Rebirth")
end
World.Start()
Feedback.Start()
Chat.Start()
task.spawn(function()
	State.Wait()
	Guide.Start()
end)

-- After the server moves us to our base, point the camera toward the conveyor.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local function onCharacter(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not hrp then
		return
	end
	local start = hrp.Position
	local t0 = os.clock()
	while (hrp.Position - start).Magnitude < 20 and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	task.wait(0.1)
	local cam = workspace.CurrentCamera
	local look = hrp.CFrame.LookVector
	cam.CFrame = CFrame.lookAt(hrp.Position - look * 14 + Vector3.new(0, 7, 0), hrp.Position + look * 6)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

--[[
	State - the latest snapshot the server sent about *this* player.
	Read-only on the client; used purely for display.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local State = {}
State.data = nil :: any
State.Changed = Instance.new("BindableEvent")

function State.Start()
	Net.Event("State").OnClientEvent:Connect(function(snap)
		local prev = State.data
		State.data = snap
		State.Changed:Fire(snap, prev)
	end)
end

function State.Wait()
	while not State.data do
		State.Changed.Event:Wait()
	end
	return State.data
end

return State

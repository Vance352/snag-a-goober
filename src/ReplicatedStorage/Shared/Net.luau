--[[
	Net - one place that names every remote. The server creates them, the
	client waits for them. Client -> server remotes only ever carry *requests*
	(ids and keys); the server validates everything.
]]

local RunService = game:GetService("RunService")

local EVENTS = {
	-- client -> server
	"Snag", -- (gooberUid)
	"Steal", -- (gooberUid)
	"Sell", -- (gooberUid)
	"Drop", -- ()
	"BuyUpgrade", -- (key)
	"Rebirth", -- ()
	"TutorialSkip", -- ()
	"TutorialAck", -- (step)
	"SetSetting", -- (key, value)
	"PromptPass", -- (passKey)
	"PromptProduct", -- (productKey)
	-- server -> client
	"State", -- (snapshot)
	"Notify", -- (kind, payload)
	"Effect", -- (kind, payload)
	"ChaosState", -- (state)
}

local FUNCTIONS = {
	"GetQuote", -- () -> { [productKey] = coins }
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	folder = script.Parent:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = script.Parent
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = script.Parent:WaitForChild("Remotes") :: Folder
end

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net

--[[
	Chat - the VIP Club chat tag. Messages from players with the VIP attribute
	(set by the server from real gamepass ownership) get a gold [VIP] prefix.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Chat = {}

function Chat.Start()
	-- keep Roblox's chat window off the top-left menu buttons on desktop
	local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local UserInputService = game:GetService("UserInputService")
	if cfg then
		pcall(function()
			cfg.HorizontalAlignment = Enum.HorizontalAlignment.Left
			cfg.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end)
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local p = Players:GetPlayerByUserId(source.UserId)
			if p and p:GetAttribute("VIP") == true then
				props.PrefixText = '<font color="#FFD650">[VIP]</font> ' .. message.PrefixText
			end
		end
		return props
	end
end

return Chat

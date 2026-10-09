--[[
	LeaderboardUI - the Leaderboard panel: category tabs, GLOBAL / THIS SERVER,
	top 10 with avatars (top 3 get medals), when it was updated, and your own
	score. Data comes from the server (Net "GetLeaderboard"); nothing is
	invented on the client. Global rankings refresh about every 90 s.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local C = Theme.C
local player = Players.LocalPlayer
local LeaderboardUI = {}

local MEDAL = { Color3.fromRGB(255, 201, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }

local function fmt(key: string, v: number): string
	if Leaderboards.ByKey[key].money then
		return "$" .. Util.Short(v)
	end
	return Util.Comma(v)
end

function LeaderboardUI.Build()
	local _, body = UI.panelShell("Leaderboard", "LEADERBOARDS", Color3.fromRGB(230, 140, 30), "crown")
	local current = Leaderboards.Categories[1].key
	local scope = "global"
	local cache: { [string]: { data: any, at: number } } = {}

	-- category tabs (scroll sideways on small screens)
	local tabs = Instance.new("ScrollingFrame")
	tabs.Size = UDim2.new(1, -10, 0, 52)
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollingDirection = Enum.ScrollingDirection.X
	tabs.ScrollBarThickness = 4
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabs.CanvasSize = UDim2.new()
	tabs.Parent = body
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	local tabButtons = {}
	local refresh

	for i, c in ipairs(Leaderboards.Categories) do
		local b = Theme.button({ Size = UDim2.fromOffset(150, 46), Text = "", Color = C.panel2, LayoutOrder = i, Parent = tabs }, function()
			Effects.Play("Click")
			current = c.key
			refresh()
		end)
		Theme.icon(c.icon, { Position = UDim2.fromOffset(4, 5), Size = UDim2.fromOffset(36, 36), Parent = b })
		Theme.label({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 42, 0.5, 0), Size = UDim2.new(1, -46, 0, 22), Text = c.title, MaxText = 15, MinText = 9, Parent = b })
		tabButtons[c.key] = { b, c.color }
	end

	-- scope toggle + status
	local scopeRow = Theme.frame({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, -10, 0, 44), BackgroundTransparency = 1, Parent = body })
	local scopeButtons = {}
	for i, sc in ipairs({ { "global", "GLOBAL" }, { "server", "THIS SERVER" } }) do
		local b = Theme.button({ Position = UDim2.fromOffset((i - 1) * 156, 0), Size = UDim2.fromOffset(150, 44), Text = sc[2], Color = C.panel2, MaxText = 17, Parent = scopeRow }, function()
			Effects.Play("Click")
			scope = sc[1]
			refresh()
		end)
		scopeButtons[sc[1]] = b
	end
	local status = Theme.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -330, 0, 22), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 14, MinText = 10, Parent = scopeRow })
	local statLine = Theme.label({ Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, -10, 0, 22), Text = "", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, MinText = 10, Parent = body })

	-- rows
	local list = Theme.frame({ Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 5)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	local rows = {}
	for i = 1, Leaderboards.Size do
		local r = Theme.frame({ Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel2, LayoutOrder = i, Visible = false, Parent = list })
		Theme.corner(r, 12)
		local stroke = Theme.stroke(r, 2.5)
		local rank = Theme.frame({ Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.ink, Parent = r })
		Theme.corner(rank, 18)
		local rankText = Theme.label({ Size = UDim2.fromScale(1, 1), Text = tostring(i), MaxText = 18, Parent = rank })
		local av = Instance.new("ImageLabel")
		av.BackgroundColor3 = C.ink
		av.Position = UDim2.fromOffset(48, 5)
		av.Size = UDim2.fromOffset(36, 36)
		av.Parent = r
		Theme.corner(av, 10)
		local name = Theme.label({ Position = UDim2.fromOffset(92, 4), Size = UDim2.new(1, -260, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 17, MinText = 10, Parent = r })
		local user = Theme.label({ Position = UDim2.fromOffset(92, 25), Size = UDim2.new(1, -260, 0, 16), Text = "", TextColor3 = C.sub, Font = Theme.Body, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 12, MinText = 9, Parent = r })
		local value = Theme.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 26), Text = "", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 20, MinText = 11, Parent = r })
		rows[i] = { frame = r, stroke = stroke, rank = rank, rankText = rankText, av = av, name = name, user = user, value = value }
	end
	local empty = Theme.label({ Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, -10, 0, 60), Text = "", TextColor3 = C.sub, TextWrapped = true, Font = Theme.Body, MaxText = 16, Visible = false, Parent = body })
	local you = Theme.label({ Size = UDim2.new(1, -10, 0, 26), Text = "", TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, MinText = 10, LayoutOrder = 99, Parent = list })

	local function show(data)
		local cat = Leaderboards.ByKey[current]
		statLine.Text = cat.stat .. (if scope == "server" then "  •  players in this server" else "  •  all servers")
		if not data then
			status.Text = "Rankings unavailable - try again soon"
			for _, r in ipairs(rows) do
				r.frame.Visible = false
			end
			empty.Visible = true
			empty.Text = "Couldn't load the rankings right now. Your stats are still being saved."
			you.Text = ""
			return
		end
		if scope == "server" then
			status.Text = "Live"
		elseif data.updatedAt then
			status.Text = "Updated " .. os.date("!%H:%M", data.updatedAt) .. " UTC" .. (if data.error then " (refresh failed)" else "")
		else
			status.Text = if data.error then "Rankings unavailable" else "Loading..."
		end
		local entries = data.entries or {}
		for i, r in ipairs(rows) do
			local e = entries[i]
			r.frame.Visible = e ~= nil
			if e then
				r.rankText.Text = tostring(e.rank or i)
				r.rank.BackgroundColor3 = MEDAL[i] or C.ink
				r.rankText.TextColor3 = if MEDAL[i] then C.ink else C.text
				r.stroke.Color = if MEDAL[i] then MEDAL[i] elseif e.userId == player.UserId then C.lime else C.ink
				r.frame.BackgroundColor3 = if e.userId == player.UserId then Color3.fromRGB(46, 84, 52) else C.panel2
				r.av.Image = if e.userId and e.userId > 0 then ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(e.userId) else ""
				r.name.Text = e.name or "?"
				r.user.Text = if e.user and e.user ~= "" then "@" .. e.user else ""
				r.value.Text = fmt(current, e.value or 0)
			end
		end
		empty.Visible = #entries == 0
		empty.Text = if scope == "global" and not data.updatedAt then "Loading the global rankings..." else "Nobody on this board yet - be the first!"
		you.Text = if data.you then ("You: %s"):format(fmt(current, data.you)) else ""
	end

	refresh = function()
		for k, t in pairs(tabButtons) do
			t[1].BackgroundColor3 = if k == current then t[2]:Lerp(Color3.new(0, 0, 0), 0.2) else C.panel2
		end
		for k, b in pairs(scopeButtons) do
			b.BackgroundColor3 = if k == scope then Color3.fromRGB(230, 140, 30) else C.panel2
		end
		local ck = current .. "|" .. scope
		local c = cache[ck]
		if c and os.clock() - c.at < (if scope == "server" then 5 else 25) then
			show(c.data)
			return
		end
		status.Text = "Loading..."
		local want = ck
		task.spawn(function()
			local ok, data = pcall(function()
				return Net.Function("GetLeaderboard"):InvokeServer(current, scope)
			end)
			if current .. "|" .. scope ~= want then
				return -- switched tab meanwhile
			end
			if ok and data then
				cache[ck] = { data = data, at = os.clock() }
				show(data)
			else
				show(nil)
			end
		end)
	end
	UI.panelRefresh.Leaderboard = function()
		-- (called on open; the per-state refresh is skipped below)
	end
	UI.onOpen = UI.onOpen or {}
	UI.onOpen.Leaderboard = refresh
	UI.zify(UI.panels.Leaderboard, 21)
end

return LeaderboardUI

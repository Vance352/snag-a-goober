--[[
	UI - HUD, toasts, banners and the five panels (Upgrades, Goober-dex,
	Rebirth, Shop, Odds) plus Settings. Mobile-first: everything is laid out at
	a 960x540 reference size and scaled with one UIScale.

	Buttons only send *requests* to the server; what the UI shows always comes
	from the server's State snapshot.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Effects = require(script.Parent.Effects)

local C = Theme.C
local player = Players.LocalPlayer

local UI = {}
UI.root = nil :: Frame?
UI.openPanel = nil :: string?

local refs: { [string]: any } = {}
local panels: { [string]: Frame } = {}
local panelRefresh: { [string]: () -> () } = {}

-- ------------------------------------------------------------ helpers
local UPGRADE_ICON = { Speed = "shoe", Slots = "stand", Income = "flask", Lock = "lock" }
local PASS_ICON = { VIP = "trophy", DoubleCoins = "coin", ExtraSlots = "stand", SprintBoots = "shoe", AutoCollect = "coin", Lucky = "gift" }
local PRODUCT_ICON = { CoinsSmall = "coin", CoinsMedium = "coin", CoinsLarge = "coin", Boost = "bolt" }

local function rarityColor(r: string): Color3
	return Config.Rarities[r].color
end

-- "+30 Candy  +40 Event XP  +$1.2K" for a reward table (coins are seconds of income)
function UI.RewardText(reward): string
	if not reward then
		return ""
	end
	local s = State.data
	local parts = {}
	if reward.candy then
		table.insert(parts, ("+%d Candy"):format(reward.candy))
	end
	if reward.coins then
		local rate = s and s.rate or 0
		table.insert(parts, "+$" .. Util.Short(math.max(math.floor(rate * reward.coins), reward.coins * 2)))
	end
	if reward.exp then
		table.insert(parts, ("+%d Event XP"):format(reward.exp))
	end
	if reward.xp then
		table.insert(parts, ("+%d XP"):format(reward.xp))
	end
	if reward.boost then
		table.insert(parts, "2x income " .. Util.Time(reward.boost))
	end
	if reward.goober then
		local def = GooberData.ById[reward.goober]
		table.insert(parts, if def then def.name else "a Goober")
	end
	if reward.title then
		table.insert(parts, ('title "%s"'):format(reward.title))
	end
	return table.concat(parts, "  ")
end

function UI.GooberViewport(gid: string, parent: Instance, size: UDim2, silhouette: boolean?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = size
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 160, 190)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	if silhouette then
		vp.ImageColor3 = Color3.fromRGB(25, 15, 40)
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Goobers")
	local template = folder and folder:FindFirstChild(gid)
	local def = GooberData.ById[gid]
	local model: Model
	if template then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(2, 2, 2)
		b.Color = rarityColor(def.rarity)
		b.CFrame = CFrame.new(0, 1, 0)
		b.Parent = model
	end
	model.Parent = vp
	local cam = Instance.new("Camera")
	local h = def.height
	local center = Vector3.new(0, h * 0.5, 0)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(0, 0, 0) * (pivot - pivot.Position))
	local cf, sz = model:GetBoundingBox()
	center = cf.Position
	local dist = math.max(sz.X, sz.Y, sz.Z) * 1.55
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.35, dist * 0.2, -dist), center)
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	return vp
end

-- --------------------------------------------------------------- HUD
-- Layout (900x500 reference, scaled): currencies + level top-left, the
-- chunky nav grid under them, travel tabs top-centre, player card + quest
-- card + status pills top-right. The bottom corners stay free for the
-- thumbstick and jump button.
local NAV = {
	{ key = "Halloween", icon = "pumpkin", label = "EVENT", color = Color3.fromRGB(255, 128, 30) },
	{ key = "Shop", icon = "shop", label = "SHOP", color = Color3.fromRGB(255, 196, 50) },
	{ key = "Dex", icon = "book", label = "INDEX", color = Color3.fromRGB(70, 160, 255) },
	{ key = "Quests", icon = "scroll", label = "QUESTS", color = Color3.fromRGB(255, 95, 162) },
	{ key = "Levels", icon = "trophy", label = "LEVELS", color = Color3.fromRGB(150, 110, 255) },
	{ key = "Upgrades", icon = "upgrade", label = "UPGRADE", color = Color3.fromRGB(90, 200, 90) },
	{ key = "Rebirth", icon = "rebirth", label = "REBIRTH", color = Color3.fromRGB(190, 100, 255) },
	{ key = "Settings", icon = "gear", label = "SETTINGS", color = Color3.fromRGB(110, 95, 150) },
}
local TABS = {
	{ key = "Base", icon = "house", label = "BASE", color = Color3.fromRGB(90, 200, 90) },
	{ key = "Plaza", icon = "belt", label = "BELT", color = Color3.fromRGB(70, 160, 255) },
	{ key = "Island", icon = "ghost", label = "SPOOKY", color = Color3.fromRGB(255, 128, 30) },
}

local function badge(parent: GuiObject)
	local b = Theme.frame({ Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 5, 0, -5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.red, Visible = false, ZIndex = 3, Parent = parent })
	Theme.corner(b, 10)
	Theme.stroke(b, 2.5)
	return b
end

local function buildHUD(root: Frame)
	-- coins pill
	local coins = Theme.frame({ Name = "Coins", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(222, 52), BackgroundColor3 = C.panel, Parent = root })
	Theme.corner(coins, 26)
	Theme.stroke(coins, 3)
	Theme.icon("coin", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(3, 3), Parent = coins })
	refs.coins = Theme.label({ Position = UDim2.fromOffset(54, 2), Size = UDim2.new(1, -62, 0, 30), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 30, Parent = coins })
	refs.rate = Theme.label({ Position = UDim2.fromOffset(54, 31), Size = UDim2.new(1, -62, 0, 18), Text = "+0/s", TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = coins })

	-- candy pill (event currency) with the event countdown
	local candy = Theme.frame({ Name = "Candy", Position = UDim2.fromOffset(8, 62), Size = UDim2.fromOffset(222, 38), BackgroundColor3 = Color3.fromRGB(92, 40, 92), Parent = root })
	Theme.corner(candy, 19)
	Theme.stroke(candy, 3)
	Theme.icon("candy", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(4, 1), Parent = candy })
	refs.candy = Theme.label({ Position = UDim2.fromOffset(44, 3), Size = UDim2.new(0.42, -10, 1, -6), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 170, 220), MaxText = 24, Parent = candy })
	refs.eventTimer = Theme.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.new(0.52, 0, 1, -8), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.sub, MaxText = 14, Parent = candy })

	-- level bar
	local bar = Theme.frame({ Name = "Level", Position = UDim2.fromOffset(8, 104), Size = UDim2.fromOffset(222, 24), BackgroundColor3 = C.ink, Parent = root })
	Theme.corner(bar, 12)
	Theme.stroke(bar, 2.5)
	refs.xpFill = Theme.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.lime, Parent = bar })
	Theme.corner(refs.xpFill, 12)
	refs.level = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "Lv 1", MaxText = 16, ZIndex = 2, Parent = bar })
	refs.nextUnlock = Theme.label({ Position = UDim2.fromOffset(10, 130), Size = UDim2.fromOffset(260, 16), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = root })

	-- chunky nav grid (3 columns)
	-- (ends ~350 so the bottom-left stays free for the phone thumbstick)
	local menu = Theme.frame({ Name = "Menu", Position = UDim2.fromOffset(8, 150), Size = UDim2.fromOffset(222, 200), BackgroundTransparency = 1, Parent = root })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(70, 62)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menu
	for i, n in ipairs(NAV) do
		local b = Theme.button({ Name = n.key, Text = "", Color = n.color, LayoutOrder = i, Radius = 16, Parent = menu }, function()
			Effects.Play("Click")
			UI.Toggle(n.key)
		end)
		Theme.icon(n.icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(40, 40), Parent = b })
		Theme.label({ Position = UDim2.new(0, 2, 1, -20), Size = UDim2.new(1, -4, 0, 18), Text = n.label, MaxText = 14, MinText = 7, Parent = b })
		badge(b)
		refs["menu" .. n.key] = b
	end

	-- travel tabs (top centre)
	local tabs = Theme.frame({ Name = "Tabs", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(348, 46), BackgroundTransparency = 1, Parent = root })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	refs.tabs = {}
	for i, tdef in ipairs(TABS) do
		local b = Theme.button({ Name = tdef.key, Text = "", Color = C.panel2, LayoutOrder = i, Size = UDim2.fromOffset(112, 46), Radius = 14, Parent = tabs }, function()
			Effects.Play("Click")
			if UI.OnTab then
				UI.OnTab(tdef.key)
			end
		end)
		Theme.icon(tdef.icon, { Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(40, 40), Parent = b })
		Theme.label({ Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -50, 1, -8), Text = tdef.label, MaxText = 18, MinText = 8, Parent = b })
		refs.tabs[tdef.key] = { button = b, color = tdef.color }
	end
	refs.tabsFrame = tabs

	-- top-right column: player card, quest card, status pills
	local status = Theme.frame({ Name = "Status", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(250, 380), BackgroundTransparency = 1, Parent = root })
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = status

	local card = Theme.frame({ Name = "Player", Size = UDim2.fromOffset(250, 44), BackgroundColor3 = C.panel, LayoutOrder = 0, Parent = status })
	Theme.corner(card, 14)
	Theme.stroke(card, 2.5)
	local head = Instance.new("ImageLabel")
	head.BackgroundColor3 = C.panel2
	head.Position = UDim2.fromOffset(4, 4)
	head.Size = UDim2.fromOffset(36, 36)
	head.Parent = card
	Theme.corner(head, 18)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		if ok then
			head.Image = img
		end
	end)
	refs.playerName = Theme.label({ Position = UDim2.fromOffset(46, 2), Size = UDim2.new(1, -52, 0, 22), Text = player.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = card })
	refs.playerStats = Theme.label({ Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 18), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = card })

	local quest = Instance.new("TextButton")
	quest.Name = "Quest"
	quest.Text = ""
	quest.AutoButtonColor = false
	quest.BackgroundColor3 = Color3.fromRGB(70, 34, 86)
	quest.Size = UDim2.fromOffset(250, 98)
	quest.LayoutOrder = 1
	quest.Parent = status
	Theme.corner(quest, 14)
	refs.questStroke = Theme.stroke(quest, 3)
	Theme.icon("scroll", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(26, 26), Parent = quest })
	refs.questHead = Theme.label({ Position = UDim2.fromOffset(36, 6), Size = UDim2.new(1, -44, 0, 22), Text = "QUEST", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = quest })
	refs.questText = Theme.label({ Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = quest })
	local qbar = Theme.frame({ Position = UDim2.fromOffset(8, 56), Size = UDim2.new(1, -16, 0, 14), BackgroundColor3 = C.ink, Parent = quest })
	Theme.corner(qbar, 7)
	refs.questFill = Theme.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 140, 40), Parent = qbar })
	Theme.corner(refs.questFill, 7)
	refs.questCount = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "", MaxText = 12, ZIndex = 2, Parent = qbar })
	refs.questReward = Theme.label({ Position = UDim2.fromOffset(8, 73), Size = UDim2.new(1, -110, 0, 20), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, MinText = 8, Parent = quest })
	refs.questClaim = Theme.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -5), Size = UDim2.fromOffset(96, 32), Text = "CLAIM", Color = C.lime, MaxText = 16, Visible = false, Parent = quest }, function()
		Effects.Play("Click")
		Net.Event("ClaimQuest"):FireServer("chain")
	end)
	quest.Activated:Connect(function()
		Effects.Play("Click")
		UI.Open("Quests")
	end)
	refs.quest = quest

	local function pill(name, order, color, iconName, h)
		h = h or 40
		local f = Theme.frame({ Name = name, Size = UDim2.fromOffset(250, h), BackgroundColor3 = color, LayoutOrder = order, Parent = status })
		Theme.corner(f, 12)
		Theme.stroke(f, 2.5)
		Theme.icon(iconName, { Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(h - 8, h - 8), Parent = f })
		local t = Theme.label({ Name = "Text", Size = UDim2.new(1, -h - 6, 1, -6), Position = UDim2.fromOffset(h, 3), Text = "", MaxText = 17, Parent = f })
		return f, t
	end
	refs.chaosPill, refs.chaosText = pill("Chaos", 2, C.panel, "swirl", 52)
	refs.boostPill, refs.boostText = pill("Boost", 3, Color3.fromRGB(230, 150, 20), "bolt")
	refs.lockPill, refs.lockText = pill("Lock", 4, Color3.fromRGB(70, 110, 200), "lock")
	refs.dropPill, refs.dropText = pill("Drop", 5, Color3.fromRGB(60, 140, 70), "gift")

	-- carry bar (bottom centre, above mobile controls)
	local carry = Theme.frame({ Name = "Carry", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(430, 58), BackgroundColor3 = C.panel, Visible = false, Parent = root })
	Theme.corner(carry, 16)
	refs.carryStroke = Theme.stroke(carry, 3)
	refs.carryText = Theme.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -130, 1, -8), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = carry })
	refs.dropBtn = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(108, 44), Text = "DROP", Color = C.red, MaxText = 20, Parent = carry }, function()
		Net.Event("Drop"):FireServer()
	end)
	refs.carry = carry

	-- tutorial hint (under the travel tabs)
	local hint = Theme.frame({ Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(370, 62), BackgroundColor3 = C.lime, Visible = false, Parent = root })
	Theme.corner(hint, 16)
	Theme.stroke(hint, 3)
	refs.hintText = Theme.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -134, 1, -8), Text = "", MaxText = 22, Parent = hint })
	-- big enough to tap on a phone (~80x40 px at phone scale)
	Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(112, 54), Text = "Skip", Color = C.panel2, MaxText = 18, Parent = hint }, function()
		Net.Event("TutorialSkip"):FireServer()
	end)
	refs.hint = hint

	-- toasts (under the hint)
	local toasts = Theme.frame({ Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(360, 200), BackgroundTransparency = 1, Parent = root })
	local tll = Instance.new("UIListLayout")
	tll.Padding = UDim.new(0, 6)
	tll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tll.SortOrder = Enum.SortOrder.LayoutOrder
	tll.Parent = toasts
	refs.toasts = toasts

	-- banner
	local banner = Theme.frame({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 96), BackgroundTransparency = 1, Visible = false, Parent = root })
	refs.bannerTitle = Theme.label({ Size = UDim2.new(1, 0, 0.62, 0), Text = "", MaxText = 64, Stroke = 4, Parent = banner })
	refs.bannerSub = Theme.label({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.new(1, 0, 0.36, 0), Text = "", MaxText = 28, Stroke = 3, Parent = banner })
	refs.banner = banner

	-- full-screen fade for portal travel
	refs.fade = Theme.frame({ Name = "Fade", Size = UDim2.new(1, 0, 1, 80), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = Color3.fromRGB(20, 8, 32), BackgroundTransparency = 1, ZIndex = 50, Visible = false, Parent = root })
end

local fadeToken = 0
function UI.Fade(inTime: number, hold: number)
	local f = refs.fade
	if not f then
		return
	end
	fadeToken += 1
	local token = fadeToken
	f.Visible = true
	f.BackgroundTransparency = 1
	Theme.tween(f, inTime, { BackgroundTransparency = 0 })
	task.delay(inTime + hold, function()
		if token == fadeToken then
			Theme.tween(f, 0.6, { BackgroundTransparency = 1 })
			task.wait(0.62)
			if token == fadeToken then
				f.Visible = false
			end
		end
	end)
end

-- highlight the travel tab for where you are ("Island", "Base" or "Plaza")
function UI.SetZone(zone: string)
	UI.zone = zone
	if not refs.tabs then
		return
	end
	for key, t in pairs(refs.tabs) do
		t.button.BackgroundColor3 = if key == zone then t.color else C.panel2
	end
end

-- ------------------------------------------------------------- toasts
local TOAST_COLORS = {
	green = C.limeDark,
	gold = Color3.fromRGB(190, 135, 20),
	red = Color3.fromRGB(200, 50, 70),
	blue = Color3.fromRGB(50, 110, 210),
	purple = Color3.fromRGB(130, 70, 200),
}
local toastOrder = 0

function UI.Toast(text: string, color: string?, seconds: number?, iconName: string?)
	if not refs.toasts then
		return
	end
	toastOrder += 1
	local items = {}
	for _, c in ipairs(refs.toasts:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	local f = Theme.frame({ Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = TOAST_COLORS[color or "purple"] or C.panel2, LayoutOrder = toastOrder, Parent = refs.toasts })
	Theme.corner(f, 12)
	Theme.stroke(f, 2.5)
	local x = 10
	if iconName then
		Theme.icon(iconName, { Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(32, 32), Parent = f })
		x = 40
	end
	Theme.label({ Position = UDim2.fromOffset(x, 3), Size = UDim2.new(1, -x - 10, 1, -6), Text = text, MaxText = 19, Parent = f })
	Effects.Pop(f)
	task.delay(seconds or 3.2, function()
		if f.Parent then
			Theme.tween(f, 0.25, { BackgroundTransparency = 1 })
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("TextLabel") then
					Theme.tween(d, 0.25, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Theme.tween(d, 0.25, { Transparency = 1 })
				end
			end
			task.wait(0.27)
			f:Destroy()
		end
	end)
end

local bannerToken = 0
function UI.Banner(title: string, sub: string?, color: Color3?, seconds: number?)
	local b = refs.banner
	if not b then
		return
	end
	bannerToken += 1
	local token = bannerToken
	refs.bannerTitle.Text = title
	refs.bannerTitle.TextColor3 = color or C.gold
	refs.bannerSub.Text = sub or ""
	b.Visible = true
	Effects.Pop(b)
	task.delay(seconds or 3, function()
		if token == bannerToken then
			b.Visible = false
		end
	end)
end

-- ------------------------------------------------------------- panels
local function panelShell(name: string, title: string, accent: Color3, iconName: string?): (Frame, ScrollingFrame)
	local dim = Theme.frame({ Name = name .. "Modal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20, Active = true, Parent = UI.root })
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromScale(1, 1)
	close.BackgroundTransparency = 1
	close.Text = ""
	close.ZIndex = 20
	close.Parent = dim
	close.Activated:Connect(function()
		UI.Close()
	end)
	-- fills most of a phone screen, capped at 620x440 on bigger screens
	local p = Theme.frame({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.86), BackgroundColor3 = C.panel, ZIndex = 21, Active = true, Parent = dim })
	Theme.corner(p, 20)
	Theme.stroke(p, 4)
	local sizer = Instance.new("UISizeConstraint")
	sizer.MaxSize = Vector2.new(760, 440)
	sizer.Parent = p
	local head = Theme.frame({ Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = accent, ZIndex = 22, Parent = p })
	Theme.corner(head, 20)
	Theme.frame({ Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = accent, ZIndex = 22, Parent = head })
	local tx = 18
	if iconName then
		Theme.icon(iconName, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(52, 52), ZIndex = 23, Parent = head })
		tx = 70
	end
	Theme.label({ Position = UDim2.fromOffset(tx, 6), Size = UDim2.new(1, -tx - 84, 1, -12), Text = title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 34, ZIndex = 23, Stroke = 3, Parent = head })
	local x = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(72, 60), Text = "X", Color = C.red, ZIndex = 24, MaxText = 30, Parent = head }, function()
		Effects.Play("Click")
		UI.Close()
	end)
	x.ZIndex = 24
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(14, 78)
	body.Size = UDim2.new(1, -28, 1, -90)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 8
	body.ScrollBarImageColor3 = C.sub
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ZIndex = 22
	body.Parent = p
	panels[name] = dim
	return dim, body
end

local function zify(root: Instance, z: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, z)
		end
	end
end

UI.tabSelect = {} :: { [string]: (string) -> () }

function UI.Open(name: string, tab: string?)
	if UI.openPanel and UI.openPanel ~= name then
		UI.returnTo = nil -- switching panels directly: don't bounce back
		UI.Close()
	end
	local p = panels[name]
	if not p then
		return
	end
	UI.openPanel = name
	p.Visible = true
	if tab and UI.tabSelect[name] then
		UI.tabSelect[name](tab)
	end
	if panelRefresh[name] then
		panelRefresh[name]()
	end
	local inner = p:FindFirstChild("Panel") :: Frame
	if inner then
		Effects.Pop(inner)
	end
	if refs["menu" .. name] and refs["menu" .. name]:FindFirstChild("Badge") then
		refs["menu" .. name].Badge.Visible = false
	end
end

function UI.Close()
	if UI.openPanel and panels[UI.openPanel] then
		panels[UI.openPanel].Visible = false
	end
	local back = UI.returnTo
	UI.returnTo = nil
	UI.openPanel = nil
	if back and back ~= UI.openPanel then
		UI.Open(back) -- e.g. Odds -> back to the Shop it was opened from
	end
end

function UI.Toggle(name: string)
	if UI.openPanel == name then
		UI.Close()
	else
		UI.Open(name)
	end
end

-- ----------------------------------------------------------- upgrades
local function buildUpgrades()
	local _, body = panelShell("Upgrades", "UPGRADES", Color3.fromRGB(70, 170, 70), "upgrade")
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local rows = {}
	for i, def in ipairs(Config.Upgrades) do
		local row = Theme.frame({ Size = UDim2.new(1, -12, 0, 86), BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = body })
		Theme.corner(row, 14)
		Theme.icon(UPGRADE_ICON[def.key], { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(70, 70), Parent = row })
		local name = Theme.label({ Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -270, 0, 30), Text = def.name, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 26, Parent = row })
		local desc = Theme.label({ Position = UDim2.fromOffset(86, 36), Size = UDim2.new(1, -270, 0, 22), Text = def.desc, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = row })
		local eff = Theme.label({ Position = UDim2.fromOffset(86, 58), Size = UDim2.new(1, -270, 0, 22), Text = "", TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 17, Parent = row })
		local buy = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(170, 60), Text = "", MaxText = 24, Parent = row }, function()
			Effects.Play("Click")
			Net.Event("BuyUpgrade"):FireServer(def.key)
		end)
		rows[def.key] = { name = name, desc = desc, eff = eff, buy = buy }
	end
	panelRefresh.Upgrades = function()
		local s = State.data
		if not s then
			return
		end
		for _, def in ipairs(Config.Upgrades) do
			local r = rows[def.key]
			local lvl = s.upgrades[def.key]
			r.name.Text = ("%s  <font color=\"#CDBEEB\">Lv %d/%d</font>"):format(def.name, lvl, def.max)
			local now, nxt
			if def.key == "Speed" then
				now = Util.WalkSpeed(lvl, s.passes.SprintBoots)
				nxt = Util.WalkSpeed(lvl + 1, s.passes.SprintBoots)
				r.eff.Text = ("Speed %s → %s"):format(now, nxt)
			elseif def.key == "Slots" then
				r.eff.Text = ("Stands %d → %d"):format(s.capacity, math.min(s.capacity + 1, Config.MaxStands))
			elseif def.key == "Income" then
				r.eff.Text = ("Income +%d%% → +%d%%"):format(lvl * 10, (lvl + 1) * 10)
			elseif def.key == "Lock" then
				r.eff.Text = ("Lock %ds → %ds"):format(Config.Lock.baseDuration + Config.Lock.perLevel * lvl, Config.Lock.baseDuration + Config.Lock.perLevel * (lvl + 1))
			end
			if lvl >= def.max then
				r.buy.Text = "MAXED"
				r.buy.BackgroundColor3 = C.gray
				r.eff.Text = "All done!"
			elseif def.key == "Lock" and s.level < Config.LockLevel then
				r.buy.Text = "Lv " .. Config.LockLevel
				r.buy.BackgroundColor3 = C.gray
			else
				local cost = Util.UpgradeCost(def, lvl)
				r.buy.Text = "$" .. Util.Short(cost)
				r.buy.BackgroundColor3 = if s.coins >= cost then C.lime else C.gray
			end
		end
	end
end

-- ----------------------------------------------------------------- dex
local function buildDex()
	local _, body = panelShell("Dex", "GOOBER INDEX", Color3.fromRGB(60, 130, 230), "book")
	local pool = "Classic"
	local poolTabs = {}
	for i, pdef in ipairs({ { "Classic", "CLASSIC", "book", Color3.fromRGB(70, 160, 255) }, { "Halloween", "HALLOWEEN", "pumpkin", Color3.fromRGB(255, 128, 30) } }) do
		local b = Theme.button({ Position = UDim2.fromOffset((i - 1) * 170, 0), Size = UDim2.fromOffset(162, 42), Text = "", Color = C.panel2, Parent = body }, function()
			Effects.Play("Click")
			UI.tabSelect.Dex(pdef[1])
			panelRefresh.Dex()
		end)
		Theme.icon(pdef[3], { Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(36, 36), Parent = b })
		Theme.label({ Position = UDim2.fromOffset(42, 4), Size = UDim2.new(1, -48, 1, -8), Text = pdef[2], MaxText = 18, Parent = b })
		poolTabs[pdef[1]] = { b, pdef[4] }
	end
	local header = Theme.label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, -10, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = body })
	local sub = Theme.label({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, -10, 0, 22), Text = "", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = body })
	local info = Theme.label({ Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, -10, 0, 40), Text = "Tap a Goober to see its details.", TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = body })
	local gridHolder = Theme.frame({ Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
	UI.tabSelect.Dex = function(p)
		if p ~= "Classic" and p ~= "Halloween" then
			return
		end
		pool = p
		for key, t in pairs(poolTabs) do
			t[1].BackgroundColor3 = if key == p then t[2] else C.panel2
		end
	end
	UI.tabSelect.Dex("Classic")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(104, 132)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridHolder
	local cards = {}
	local built = false
	local function build()
		built = true
		for _, def in ipairs(GooberData.List) do
			local card = Instance.new("TextButton")
			card.Text = ""
			card.AutoButtonColor = false
			card.BackgroundColor3 = C.panel2
			card.LayoutOrder = def.order
			card.Parent = gridHolder
			Theme.corner(card, 12)
			local stroke = Theme.stroke(card, 3, rarityColor(def.rarity))
			local name = Theme.label({ Position = UDim2.new(0, 4, 1, -30), Size = UDim2.new(1, -8, 0, 26), Text = "???", MaxText = 15, Parent = card })
			cards[def.id] = { card = card, name = name, stroke = stroke, vp = nil, discovered = nil }
			card.Activated:Connect(function()
				local s = State.data
				local n = s and s.dex[def.id]
				if n then
					info.Text = ("<font color=\"#%s\">%s</font> %s • +%s/s • $%s • collected %dx\n<i>%s</i>"):format(
						rarityColor(def.rarity):ToHex(), def.rarity:upper(), def.name, Util.Short(def.income), Util.Short(def.price), n, def.blurb)
				else
					info.Text = ("<font color=\"#%s\">%s</font> ??? — %s"):format(rarityColor(def.rarity):ToHex(), def.rarity:upper(),
						if def.eventOnly then "only appears during a CHAOS RIFT event!"
							elseif def.pool == "Halloween" then "snag it on Halloween Island!"
							else "keep snagging to discover it!")
				end
			end)
		end
	end
	panelRefresh.Dex = function()
		local s = State.data
		if not s then
			return
		end
		if not built then
			build()
		end
		local count, total = 0, 0
		for _, def in ipairs(GooberData.List) do
			local found = s.dex[def.id] ~= nil
			local c = cards[def.id]
			local inPool = (def.pool or "Classic") == pool
			c.card.Visible = inPool
			if not inPool then
				continue
			end
			total += 1
			if found then
				count += 1
			end
			if c.discovered ~= found then
				c.discovered = found
				if c.vp then
					c.vp:Destroy()
				end
				c.vp = UI.GooberViewport(def.id, c.card, UDim2.new(1, -8, 1, -34), not found)
				c.vp.Position = UDim2.fromOffset(4, 4)
				c.name.Text = if found then def.name else "???"
			end
		end
		header.Text = ("Discovered %d / %d %s Goobers"):format(count, total, if pool == "Halloween" then "Halloween" else "Classic")
		if pool == "Halloween" then
			local ev = s.event
			local nextH
			for _, m in ipairs(require(ReplicatedStorage.Shared.Halloween).DexRewards) do
				if not (ev and ev.hdexClaimed[tostring(m.count)]) then
					nextH = m
					break
				end
			end
			sub.Text = if nextH
				then ("Collection reward at %d: +%d Candy%s (claim in EVENT)"):format(nextH.count, nextH.candy, if nextH.title then (' + title "%s"'):format(nextH.title) else "")
				else "Halloween collection complete!"
		else
			local nextM
			for _, m in ipairs(Config.DexMilestones) do
				if not s.dexClaimed[tostring(m.count)] then
					nextM = m
					break
				end
			end
			sub.Text = if nextM
				then ("Next reward at %d: $%s + title \"%s\""):format(nextM.count, Util.Short(nextM.coins), nextM.title)
				else "Every milestone claimed. You are a Goober Legend!"
		end
	end
end

-- ------------------------------------------------------------- rebirth
local function buildRebirth()
	local _, body = panelShell("Rebirth", "REBIRTH", Color3.fromRGB(150, 80, 220), "rebirth")
	local title = Theme.label({ Size = UDim2.new(1, -10, 0, 34), Text = "", MaxText = 28, Parent = body })
	local req = Theme.label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, -10, 0, 50), Text = "", TextWrapped = true, MaxText = 19, Parent = body })
	local cols = Theme.frame({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, -10, 0, 124), BackgroundTransparency = 1, Parent = body })
	local function col(i, head, color)
		local f = Theme.frame({ Position = UDim2.new((i - 1) / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.panel2, Parent = cols })
		Theme.corner(f, 12)
		Theme.label({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 26), Text = head, TextColor3 = color, MaxText = 20, Parent = f })
		return Theme.label({ Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -36), Text = "", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Font = Theme.Body, Parent = f })
	end
	local resets = col(1, "RESETS", C.red)
	local keeps = col(2, "YOU KEEP", C.lime)
	local gains = col(3, "YOU GAIN", C.gold)
	local why = Theme.label({ Position = UDim2.fromOffset(0, 282), Size = UDim2.new(1, -10, 0, 22), Text = "Why? Your Goobers earn more forever, so every future run is faster.", TextColor3 = C.sub, MaxText = 16, Parent = body })
	local confirmUntil = 0
	local btn
	btn = Theme.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 220), Size = UDim2.fromOffset(300, 56), Text = "REBIRTH", Color = Color3.fromRGB(190, 100, 255), Parent = body }, function()
		local s = State.data
		if not s then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.Event("Rebirth"):FireServer(true) -- confirmed
			UI.Close()
		else
			confirmUntil = os.clock() + 3
			btn.Text = "TAP AGAIN TO CONFIRM"
			task.delay(3, function()
				if os.clock() >= confirmUntil then
					panelRefresh.Rebirth()
				end
			end)
		end
	end)
	keeps.Text = "• All your Goobers\n• Your stands (More Stands)\n• Your Level\n• Your Goober-dex\n• Every gamepass"
	resets.Text = "• Slop Coins (wallet and Cash Pad)\n• Zoomies\n• Slop Pipes\n• Base Lock upgrades"
	panelRefresh.Rebirth = function()
		local s = State.data
		if not s then
			return
		end
		local r = s.rebirths
		if r >= Config.Rebirth.max then
			title.Text = "MAX REBIRTHS REACHED ★" .. r
			req.Text = "You are as reborn as a Goober can be."
			btn.Visible = false
			return
		end
		title.Text = ("Rebirth #%d"):format(r + 1)
		local lvlOk = s.level >= s.rebirthLevel
		local coinOk = s.coins >= s.rebirthCost
		req.Text = ("<font color=\"#%s\">Level %d</font>    <font color=\"#%s\">$%s Slop Coins</font>"):format(if lvlOk then "7BE35A" else "FF6B7A", s.rebirthLevel, if coinOk then "7BE35A" else "FF6B7A", Util.Short(s.rebirthCost))
		local nowMult = 1 + Config.Rebirth.incomeBonus * r
		local nextMult = 1 + Config.Rebirth.incomeBonus * (r + 1)
		gains.Text = ("• Income x%.1f → x%.1f forever\n• +1 stand\n• +10%% Personal Drop luck\n• Rebirth star ★\n• Start with $%d"):format(nowMult, nextMult, Config.Rebirth.startCoins)
		btn.Visible = true
		local ok = lvlOk and coinOk and not s.carry
		btn.Text = if ok then "REBIRTH" else "NOT YET"
		btn.BackgroundColor3 = if ok then Color3.fromRGB(190, 100, 255) else C.gray
		btn.Active = ok
		why.Visible = true
	end
end

-- ---------------------------------------------------------------- odds
local function buildOdds()
	local _, body = panelShell("Odds", "ODDS INFO", Color3.fromRGB(60, 150, 140), "swirl")
	local cols = { "Rarity", "Slop Line", "Gold Line", "Your Personal Drop", "With Lucky Goober" }
	local w = { 0.18, 0.18, 0.18, 0.23, 0.23 }
	local rows = {}
	local y = 0
	local function row(values, color, h)
		local x = 0
		local labels = {}
		for i, v in ipairs(values) do
			labels[i] = Theme.label({ Position = UDim2.new(x, 0, 0, y), Size = UDim2.new(w[i], -4, 0, h), Text = v, TextColor3 = if i == 1 then color else C.text, MaxText = 17, Parent = body })
			x += w[i]
		end
		y += h + 4
		return labels
	end
	row(cols, C.sub, 40)
	for _, r in ipairs(Config.RarityOrder) do
		rows[r] = row({ r, "", "", "", "" }, rarityColor(r), 30)
	end
	local note = Theme.label({ Position = UDim2.fromOffset(0, y + 4), Size = UDim2.new(1, -10, 0, 96), Text = "", TextWrapped = true, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Body, MaxText = 15, Parent = body })
	panelRefresh.Odds = function()
		local s = State.data
		local luck = s and s.personalLuck or 1
		local base = Util.PersonalLuck(s and s.rebirths or 0, false)
		local withLucky = Util.PersonalLuck(s and s.rebirths or 0, true)
		local main = Util.Odds("Main", 1)
		local gold = Util.Odds("Gold", 1)
		local mine = Util.Odds("Main", luck)
		local lucky = Util.Odds("Main", withLucky)
		local function pct(v)
			if v == 0 then
				return "0%"
			elseif v < 1 then
				return string.format("%.2f%%", v)
			end
			return string.format("%.1f%%", v)
		end
		for _, r in ipairs(Config.RarityOrder) do
			rows[r][2].Text = pct(main[r])
			rows[r][3].Text = pct(gold[r])
			rows[r][4].Text = pct(mine[r])
			rows[r][5].Text = pct(lucky[r])
		end
		note.Text = ("Each column adds up to 100%%. Inside a rarity, every Goober is equally likely. Personal Drops land on the Slop Line every %ds and only you can snag them. Your luck: x%.2f (from rebirths x%.2f). Lucky Goober adds +%.1f luck, which multiplies the chance of Rare, Epic, Legendary and Secret Goobers. GOLDEN HOUR events multiply luck by %.1f for everyone. The Chaos Goob can only appear during a CHAOS RIFT (%.0f%% per spawn).")
			:format(Config.PersonalDrop.interval, luck, base, Config.PersonalDrop.luckyPassLuck, Config.Chaos.types.GoldenHour.luck, Config.Chaos.types.ChaosRift.chaosGoobChance * 100)
	end
end

-- ---------------------------------------------------------------- shop
local quote = {}
-- live Robux prices from the marketplace (falls back to Config while loading)
local livePrice: { [string]: number } = {}
local function loadLivePrices()
	for key, p in pairs(Config.GamePasses) do
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.id, Enum.InfoType.GamePass)
			if ok and info and info.PriceInRobux then
				livePrice[key] = info.PriceInRobux
			end
		end)
	end
	for key, p in pairs(Config.Products) do
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.id, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				livePrice[key] = info.PriceInRobux
			end
		end)
	end
end
local function buildShop()
	local _, body = panelShell("Shop", "SHOP", Color3.fromRGB(230, 150, 30), "shop")
	local holder = Theme.frame({ Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	local order = 0
	local function section(text)
		order += 1
		Theme.label({ Size = UDim2.new(1, 0, 0, 30), Text = text, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, MaxText = 24, LayoutOrder = order, Parent = holder })
	end
	local function grid()
		order += 1
		local g = Theme.frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = holder })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.5, -6, 0, 206) -- tall enough that descriptions stay readable on phones
		gl.CellPadding = UDim2.fromOffset(8, 8)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = g
		return g
	end
	local cards = {}
	local function card(parent, i, icon, name, desc, onBuy, extra, image)
		local f = Theme.frame({ BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = parent })
		Theme.corner(f, 14)
		if image then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Position = UDim2.fromOffset(4, 4)
			img.Size = UDim2.fromOffset(64, 64)
			img.Image = image
			img.ScaleType = Enum.ScaleType.Fit
			img.Parent = f
		else
			Theme.icon(icon, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(60, 60), Parent = f })
		end
		Theme.label({ Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -78, 0, 28), Text = name, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 21, Parent = f })
		local d = Theme.label({ Position = UDim2.fromOffset(70, 38), Size = UDim2.new(1, -78, 0, 106), Text = desc, TextWrapped = true, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Body, MaxText = 17, Parent = f })
		local buy = Theme.button({ Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, if extra then -122 else -16, 0, 44), Text = "", Color = C.robux, MaxText = 22, Parent = f }, onBuy)
		local ex
		if extra then
			ex = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 1, -52), Size = UDim2.fromOffset(106, 44), Text = extra.text, Color = Color3.fromRGB(60, 150, 140), MaxText = 16, Parent = f }, extra.fn)
		end
		return { frame = f, desc = d, buy = buy, extra = ex }
	end
	section("Game Passes  •  permanent")
	local pg = grid()
	for i, key in ipairs(Config.PassOrder) do
		local p = Config.GamePasses[key]
		cards[key] = card(pg, i, PASS_ICON[key], p.name, p.desc, function()
			local s = State.data
			if p.id > 0 and s and not s.passes[key] then
				Effects.Play("Click")
				Net.Event("PromptPass"):FireServer(key)
			end
		end, if p.randomModifier then { text = "ODDS INFO", fn = function()
			UI.Open("Odds")
			UI.returnTo = "Shop"
		end } else nil, p.icon)
	end
	section("Slop Coins & Boosts  •  one-time")
	local cg = grid()
	for i, key in ipairs(Config.ProductOrder) do
		local p = Config.Products[key]
		cards[key] = card(cg, i, PRODUCT_ICON[key], p.name, "", function()
			if p.id > 0 then
				Effects.Play("Click")
				Net.Event("PromptProduct"):FireServer(key)
			end
		end, nil, p.icon)
	end
	panelRefresh.Shop = function()
		local s = State.data
		if not s then
			return
		end
		task.spawn(function()
			local ok, q = pcall(function()
				return Net.Function("GetQuote"):InvokeServer()
			end)
			if ok and q then
				quote = q
				panelRefresh.ShopProducts()
			end
		end)
		for _, key in ipairs(Config.PassOrder) do
			local p = Config.GamePasses[key]
			local c = cards[key]
			if s.passes[key] then
				c.buy.Text = "OWNED"
				c.buy.BackgroundColor3 = C.gray
			elseif p.randomModifier and s.restrictedRandom then
				c.buy.Text = "Not available here"
				c.buy.BackgroundColor3 = C.gray
			elseif p.id <= 0 then
				c.buy.Text = "Not on sale yet"
				c.buy.BackgroundColor3 = C.gray
			else
				c.buy.Text = "R$ " .. (livePrice[key] or p.price)
				c.buy.BackgroundColor3 = C.robux
			end
		end
		panelRefresh.ShopProducts()
	end
	panelRefresh.ShopProducts = function()
		local s = State.data
		for _, key in ipairs(Config.ProductOrder) do
			local p = Config.Products[key]
			local c = cards[key]
			if p.minutes then
				local amount = quote[key] or Util.ProductCoins(key, s and s.rate or 0)
				c.desc.Text = ("You get <font color=\"#FFC93C\">$%s Slop Coins</font>\n(%d min of your current income, at least $%s)"):format(Util.Comma(amount), p.minutes, Util.Short(p.minCoins))
			else
				local left = s and s.boostLeft or 0
				c.desc.Text = "Doubles ALL your income for 15 minutes. Buying again adds 15 more minutes."
					.. (if left > 0 then ("\n<font color=\"#7BE35A\">Active: %s left</font>"):format(Util.Time(left)) else "")
			end
			if p.id <= 0 then
				c.buy.Text = "Not on sale yet"
				c.buy.BackgroundColor3 = C.gray
			else
				c.buy.Text = "R$ " .. (livePrice[key] or p.price)
				c.buy.BackgroundColor3 = C.robux
			end
		end
	end
end

-- ------------------------------------------------------------ settings
local function buildSettings()
	local _, body = panelShell("Settings", "SETTINGS", C.panel2, "gear")
	local function toggle(y, label, key)
		Theme.label({ Position = UDim2.fromOffset(10, y), Size = UDim2.new(0.6, 0, 0, 50), Text = label, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, Parent = body })
		local b
		b = Theme.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, y), Size = UDim2.fromOffset(140, 50), Text = "ON", Parent = body }, function()
			local s = State.data
			if not s then
				return
			end
			local v = not (s.settings[key] ~= false)
			Net.Event("SetSetting"):FireServer(key, v)
			s.settings[key] = v
			Effects.SetSettings(s.settings)
			panelRefresh.Settings()
		end)
		return b
	end
	local music = toggle(10, "Music", "music")
	local sfx = toggle(70, "Sound effects", "sfx")
	local skip = Theme.button({ Position = UDim2.fromOffset(10, 140), Size = UDim2.fromOffset(260, 50), Text = "Skip tutorial", Color = C.panel, Parent = body }, function()
		Net.Event("TutorialSkip"):FireServer()
		UI.Close()
	end)
	local note = Theme.label({ Position = UDim2.fromOffset(10, 200), Size = UDim2.new(1, -20, 0, 60), Text = "", TextWrapped = true, TextColor3 = C.sub, Font = Theme.Body, MaxText = 15, Parent = body })
	panelRefresh.Settings = function()
		local s = State.data
		if not s then
			return
		end
		local hasMusic = Config.Audio.Music ~= ""
		local hasSfx = Config.Audio.Sprite ~= ""
		for b, key in pairs({ [music] = "music", [sfx] = "sfx" }) do
			local on = s.settings[key] ~= false
			local available = if key == "music" then hasMusic else hasSfx
			b.Text = if not available then "N/A" elseif on then "ON" else "OFF"
			b.BackgroundColor3 = if on and available then C.lime else C.gray
			b.Active = available
		end
		skip.Visible = s.tutorial ~= Tutorial.DONE
		note.Text = if s.temporary then "Studio test session: progress is NOT saved." else "Your progress saves automatically."
	end
end

-- -------------------------------------------------------------- update
local shownCoins = 0
local targetCoins = 0

local function nextUnlockText(level: number): string
	local best
	for lvl, text in pairs(Config.LevelUnlocks) do
		if lvl > level and (not best or lvl < best) then
			best = lvl
		end
	end
	return if best then ("Lv %d: %s"):format(best, Config.LevelUnlocks[best]) else ""
end

local function onState(s, prev)
	targetCoins = s.coins
	local mult = s.multiplier
	refs.rate.Text = ("+%s/s%s"):format(Util.Short(s.rate), if mult > 1.001 then ("  <font color=\"#FFC93C\">x%.1f</font>"):format(mult) else "")
	refs.level.Text = ("Lv %d  •  %s/%s XP"):format(s.level, Util.Short(s.xp), Util.Short(s.xpNeeded))
	Theme.tween(refs.xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(s.xp / s.xpNeeded, 0.02, 1), 1) })
	refs.nextUnlock.Text = nextUnlockText(s.level)
	refs.playerStats.Text = ("Lv %d  •  %s%s"):format(s.level, if s.rebirths > 0 then ("★%d  •  "):format(s.rebirths) else "", if s.title ~= "" and s.title then s.title else "Goober Snagger")
	local ev = s.event
	if ev then
		refs.candy.Text = Util.Comma(ev.candy)
		refs.eventTimer.Text = if ev.eventEndsIn > 0 then ("Event %s"):format(Util.Time(ev.eventEndsIn)) else "Event over"
	end
	-- quest card (the Halloween quest chain)
	local q = s.quests
	local cq = q and q.chain
	if cq then
		local done = cq.progress >= cq.target
		refs.questHead.Text = ("QUEST %d/%d"):format(q.chainIndex, q.chainTotal)
		refs.questText.Text = cq.text
		refs.questCount.Text = ("%s/%s"):format(Util.Short(cq.progress), Util.Short(cq.target))
		Theme.tween(refs.questFill, 0.3, { Size = UDim2.fromScale(math.clamp(cq.progress / math.max(1, cq.target), 0.03, 1), 1) })
		refs.questReward.Text = "Reward: " .. UI.RewardText(cq.reward)
		refs.questClaim.Visible = done
		refs.questStroke.Color = if done then C.lime else C.ink
		refs.quest.Visible = true
	elseif q then
		refs.questHead.Text = "QUESTS DONE!"
		refs.questText.Text = "Check the daily quests"
		refs.questCount.Text = ""
		refs.questFill.Size = UDim2.fromScale(1, 1)
		refs.questReward.Text = ""
		refs.questClaim.Visible = false
	end
	if UI.OnStateExtra then
		UI.OnStateExtra(s, prev)
	end
	-- status pills
	refs.boostPill.Visible = s.boostLeft > 0
	refs.boostText.Text = "2x Income  " .. Util.Time(s.boostLeft)
	if s.lockLeft > 0 then
		refs.lockText.Text = "Locked " .. Util.Time(s.lockLeft)
		refs.lockPill.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
	elseif s.lockReadyIn > 0 then
		refs.lockText.Text = "Lock in " .. Util.Time(s.lockReadyIn)
		refs.lockPill.BackgroundColor3 = C.gray
	else
		refs.lockText.Text = "Lock ready (red pad)"
		refs.lockPill.BackgroundColor3 = Color3.fromRGB(200, 70, 90)
	end
	refs.lockPill.Visible = s.level >= Config.StealLevel or s.lockLeft > 0
	refs.dropText.Text = "Personal Drop in " .. Util.Time(s.nextDropIn)
	refs.dropPill.Visible = s.tutorial == Tutorial.DONE
	-- carry bar
	if s.carry then
		local def = GooberData.ById[s.carry.id]
		refs.carry.Visible = true
		if s.carry.source == "steal" then
			refs.carryText.Text = ("<font color=\"#FF6B7A\">STOLEN %s!</font> Run home before %s tags you!"):format(def.name, s.carry.victim or "the owner")
			refs.carryStroke.Color = C.red
			refs.dropBtn.Text = "GIVE UP"
		else
			refs.carryText.Text = ("Carrying <font color=\"#%s\">%s</font> - bring it home!"):format(rarityColor(def.rarity):ToHex(), def.name)
			refs.carryStroke.Color = C.ink
			refs.dropBtn.Text = "DROP"
		end
	else
		refs.carry.Visible = false
	end
	-- rebirth badge
	local canRebirth = s.level >= s.rebirthLevel and s.coins >= s.rebirthCost and s.rebirths < Config.Rebirth.max
	refs.menuRebirth.Badge.Visible = canRebirth and UI.openPanel ~= "Rebirth"
	-- affordable upgrade badge
	local anyUpgrade = false
	for _, def in ipairs(Config.Upgrades) do
		local lvl = s.upgrades[def.key]
		if lvl < def.max and s.coins >= Util.UpgradeCost(def, lvl) and not (def.key == "Lock" and s.level < Config.LockLevel) then
			anyUpgrade = true
		end
	end
	refs.menuUpgrades.Badge.Visible = anyUpgrade and UI.openPanel ~= "Upgrades"
	Effects.SetSettings(s.settings)
	if UI.openPanel and panelRefresh[UI.openPanel] and UI.openPanel ~= "Shop" and UI.openPanel ~= "Dex" then
		panelRefresh[UI.openPanel]()
	elseif UI.openPanel == "Dex" and prev and (prev.dex ~= s.dex) then
		panelRefresh.Dex()
	end
end

local function chaosTick()
	local typ = ReplicatedStorage:GetAttribute("ChaosType") or ""
	local now = Workspace:GetServerTimeNow()
	if typ ~= "" then
		local def = Config.Chaos.types[typ]
		local left = (ReplicatedStorage:GetAttribute("ChaosEndsAt") or now) - now
		refs.chaosText.Text = ("%s!  %s"):format(def.title, Util.Time(left))
		refs.chaosPill.BackgroundColor3 = def.color:Lerp(Color3.new(0, 0, 0), 0.25)
	else
		local nextAt = ReplicatedStorage:GetAttribute("ChaosNextAt") or now
		local nextType = ReplicatedStorage:GetAttribute("ChaosNextType")
		local def = nextType and Config.Chaos.types[nextType]
		refs.chaosText.Text = ("GOOBER CHAOS in %s\n<font size=\"13\" color=\"#CDBEEB\">Next: %s</font>"):format(Util.Time(nextAt - now), def and def.title or "?")
		refs.chaosPill.BackgroundColor3 = C.panel
	end
end

function UI.Start()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SAG_HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg
	local root = Theme.frame({ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = Instance.new("UIScale")
	scale.Parent = root
	UI.root = root
	local function rescale()
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(900, 500)
		local s = math.clamp(math.min(vp.X / 900, vp.Y / 500), 0.62, 1.35)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	loadLivePrices()
	buildHUD(root)
	buildUpgrades()
	buildDex()
	buildRebirth()
	buildOdds()
	buildShop()
	buildSettings()
	for _, p in pairs(panels) do
		zify(p, 21)
	end

	State.Changed.Event:Connect(onState)
	if State.data then
		onState(State.data, nil)
	end
	-- coin counter animation + timers
	RunService.RenderStepped:Connect(function(dt)
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			if math.abs(diff) < 1 then
				shownCoins = targetCoins
			else
				shownCoins += diff * math.min(1, dt * 8)
			end
			refs.coins.Text = "$" .. Util.Comma(shownCoins + 0.5)
		end
	end)
	task.spawn(function()
		while true do
			chaosTick()
			task.wait(0.25)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, _id, purchased)
		if plr == player and UI.openPanel == "Shop" then
			task.wait(0.5)
			panelRefresh.Shop()
		end
	end)
end

UI.refs = refs
UI.panelRefresh = panelRefresh
UI.panels = panels
UI.panelShell = panelShell
UI.zify = zify

return UI

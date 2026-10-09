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
local UPGRADE_ICON = { Speed = "👟", Slots = "🪑", Income = "🧪", Lock = "🔒" }
local PASS_ICON = { VIP = "👑", DoubleCoins = "💰", ExtraSlots = "🪑", SprintBoots = "👟", AutoCollect = "🧲", Lucky = "🍀" }
local PRODUCT_ICON = { CoinsSmall = "💰", CoinsMedium = "🛢️", CoinsLarge = "🚛", Boost = "⚡" }

local function rarityColor(r: string): Color3
	return Config.Rarities[r].color
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
local function buildHUD(root: Frame)
	-- coins pill
	local coins = Theme.frame({
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(290, 58),
		BackgroundColor3 = C.panel,
		Parent = root,
	})
	Theme.corner(coins, 29)
	Theme.stroke(coins, 3)
	local icon = Theme.frame({ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.gold, Parent = coins })
	Theme.corner(icon, 23)
	Theme.stroke(icon, 2.5)
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = "$", MaxText = 34, Parent = icon })
	refs.coins = Theme.label({ Position = UDim2.fromOffset(60, 2), Size = UDim2.new(1, -70, 0, 34), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 34, Parent = coins })
	refs.rate = Theme.label({ Position = UDim2.fromOffset(60, 34), Size = UDim2.new(1, -70, 0, 20), Text = "+0/s", TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = coins })

	-- level bar
	local bar = Theme.frame({ Name = "Level", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(290, 26), BackgroundColor3 = C.ink, Parent = root })
	Theme.corner(bar, 13)
	Theme.stroke(bar, 2.5)
	refs.xpFill = Theme.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.lime, Parent = bar })
	Theme.corner(refs.xpFill, 13)
	refs.level = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "Lv 1", MaxText = 18, ZIndex = 2, Parent = bar })
	refs.nextUnlock = Theme.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.fromOffset(320, 18), Text = "", TextColor3 = C.sub, MaxText = 16, Parent = root })

	-- menu buttons (2x2, top-left)
	local menu = Theme.frame({ Name = "Menu", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(152, 152), BackgroundTransparency = 1, Parent = root })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(72, 72)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menu
	local function menuButton(name, emoji, label, color, order)
		local b = Theme.button({ Name = name, Text = "", Color = color, LayoutOrder = order, Parent = menu }, function()
			Effects.Play("Click")
			UI.Toggle(name)
		end)
		Theme.label({ Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Text = emoji, Stroke = false, MaxText = 36, Parent = b })
		Theme.label({ Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0, 2, 0.66, 0), Text = label, MaxText = 15, Parent = b })
		local badge = Theme.frame({ Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.red, Visible = false, Parent = b })
		Theme.corner(badge, 9)
		Theme.stroke(badge, 2)
		refs["menu" .. name] = b
		return b
	end
	menuButton("Upgrades", "⬆️", "UPGRADES", Color3.fromRGB(90, 200, 90), 1)
	menuButton("Dex", "📖", "DEX", Color3.fromRGB(80, 160, 255), 2)
	menuButton("Rebirth", "♻️", "REBIRTH", Color3.fromRGB(190, 100, 255), 3)
	menuButton("Shop", "🛒", "SHOP", Color3.fromRGB(255, 170, 40), 4)
	Theme.button({ Name = "SettingsBtn", Position = UDim2.fromOffset(8, 164), Size = UDim2.fromOffset(56, 56), Text = "⚙️", Color = C.panel2, MaxText = 28, Parent = root }, function()
		UI.Toggle("Settings")
	end)

	-- top-right status column
	local status = Theme.frame({ Name = "Status", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(240, 220), BackgroundTransparency = 1, Parent = root })
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = status
	local function pill(name, order, color, h)
		local f = Theme.frame({ Name = name, Size = UDim2.fromOffset(240, h or 40), BackgroundColor3 = color, LayoutOrder = order, Parent = status })
		Theme.corner(f, 12)
		Theme.stroke(f, 2.5)
		local t = Theme.label({ Name = "Text", Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", MaxText = 18, Parent = f })
		return f, t
	end
	refs.chaosPill, refs.chaosText = pill("Chaos", 1, C.panel, 48)
	refs.boostPill, refs.boostText = pill("Boost", 2, Color3.fromRGB(230, 150, 20))
	refs.lockPill, refs.lockText = pill("Lock", 3, Color3.fromRGB(70, 110, 200))
	refs.dropPill, refs.dropText = pill("Drop", 4, Color3.fromRGB(60, 140, 70))

	-- carry bar (bottom centre, above mobile controls)
	local carry = Theme.frame({ Name = "Carry", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(430, 58), BackgroundColor3 = C.panel, Visible = false, Parent = root })
	Theme.corner(carry, 16)
	refs.carryStroke = Theme.stroke(carry, 3)
	refs.carryText = Theme.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -130, 1, -8), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = carry })
	refs.dropBtn = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(108, 44), Text = "DROP", Color = C.red, MaxText = 20, Parent = carry }, function()
		Net.Event("Drop"):FireServer()
	end)
	refs.carry = carry

	-- tutorial hint
	local hint = Theme.frame({ Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(460, 52), BackgroundColor3 = C.lime, Visible = false, Parent = root })
	Theme.corner(hint, 16)
	Theme.stroke(hint, 3)
	refs.hintText = Theme.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -110, 1, -8), Text = "", MaxText = 22, Parent = hint })
	Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(92, 42), Text = "Skip", Color = C.panel2, MaxText = 18, Parent = hint }, function()
		Net.Event("TutorialSkip"):FireServer()
	end)
	refs.hint = hint

	-- toasts
	local toasts = Theme.frame({ Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 178), Size = UDim2.fromOffset(460, 200), BackgroundTransparency = 1, Parent = root })
	local tl = Instance.new("UIListLayout")
	tl.Padding = UDim.new(0, 6)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = toasts
	refs.toasts = toasts

	-- banner
	local banner = Theme.frame({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(620, 110), BackgroundTransparency = 1, Visible = false, Parent = root })
	refs.bannerTitle = Theme.label({ Size = UDim2.new(1, 0, 0.62, 0), Text = "", MaxText = 64, Stroke = 4, Parent = banner })
	refs.bannerSub = Theme.label({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.new(1, 0, 0.36, 0), Text = "", MaxText = 28, Stroke = 3, Parent = banner })
	refs.banner = banner
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

function UI.Toast(text: string, color: string?, seconds: number?)
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
	local f = Theme.frame({ Size = UDim2.fromOffset(440, 38), BackgroundColor3 = TOAST_COLORS[color or "purple"] or C.panel2, LayoutOrder = toastOrder, Parent = refs.toasts })
	Theme.corner(f, 12)
	Theme.stroke(f, 2.5)
	Theme.label({ Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 1, -6), Text = text, MaxText = 19, Parent = f })
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
local function panelShell(name: string, title: string, accent: Color3): (Frame, ScrollingFrame)
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
	local p = Theme.frame({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(620, 440), BackgroundColor3 = C.panel, ZIndex = 21, Active = true, Parent = dim })
	Theme.corner(p, 20)
	Theme.stroke(p, 4)
	local sizer = Instance.new("UISizeConstraint")
	sizer.MaxSize = Vector2.new(620, 440)
	sizer.Parent = p
	local head = Theme.frame({ Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = accent, ZIndex = 22, Parent = p })
	Theme.corner(head, 20)
	Theme.frame({ Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = accent, ZIndex = 22, Parent = head })
	Theme.label({ Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -90, 1, -12), Text = title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 34, ZIndex = 23, Stroke = 3, Parent = head })
	local x = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(46, 46), Text = "X", Color = C.red, ZIndex = 24, MaxText = 26, Parent = head }, function()
		Effects.Play("Click")
		UI.Close()
	end)
	x.ZIndex = 24
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(14, 66)
	body.Size = UDim2.new(1, -28, 1, -78)
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

function UI.Open(name: string)
	if UI.openPanel and UI.openPanel ~= name then
		UI.Close()
	end
	local p = panels[name]
	if not p then
		return
	end
	UI.openPanel = name
	p.Visible = true
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
	UI.openPanel = nil
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
	local _, body = panelShell("Upgrades", "⬆️  UPGRADES", Color3.fromRGB(70, 170, 70))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local rows = {}
	for i, def in ipairs(Config.Upgrades) do
		local row = Theme.frame({ Size = UDim2.new(1, -12, 0, 86), BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = body })
		Theme.corner(row, 14)
		Theme.label({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(70, 70), Text = UPGRADE_ICON[def.key], Stroke = false, MaxText = 44, Parent = row })
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
	local _, body = panelShell("Dex", "📖  GOOBER-DEX", Color3.fromRGB(60, 130, 230))
	local header = Theme.label({ Size = UDim2.new(1, -10, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24, LayoutOrder = 0, Parent = body })
	local sub = Theme.label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -10, 0, 22), Text = "", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = body })
	local info = Theme.label({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, -10, 0, 40), Text = "Tap a Goober to see its details.", TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = body })
	local gridHolder = Theme.frame({ Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
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
						if def.eventOnly then "only appears during a CHAOS RIFT event!" else "keep snagging to discover it!")
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
		local count = 0
		for _, def in ipairs(GooberData.List) do
			local found = s.dex[def.id] ~= nil
			if found then
				count += 1
			end
			local c = cards[def.id]
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
		header.Text = ("Discovered %d / %d Goobers"):format(count, GooberData.Count)
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

-- ------------------------------------------------------------- rebirth
local function buildRebirth()
	local _, body = panelShell("Rebirth", "♻️  REBIRTH", Color3.fromRGB(150, 80, 220))
	local title = Theme.label({ Size = UDim2.new(1, -10, 0, 34), Text = "", MaxText = 28, Parent = body })
	local req = Theme.label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, -10, 0, 50), Text = "", TextWrapped = true, MaxText = 19, Parent = body })
	local cols = Theme.frame({ Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, -10, 0, 170), BackgroundTransparency = 1, Parent = body })
	local function col(i, head, color)
		local f = Theme.frame({ Position = UDim2.new((i - 1) / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.panel2, Parent = cols })
		Theme.corner(f, 12)
		Theme.label({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 26), Text = head, TextColor3 = color, MaxText = 20, Parent = f })
		return Theme.label({ Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -36), Text = "", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Font = Theme.Body, Parent = f })
	end
	local resets = col(1, "RESETS", C.red)
	local keeps = col(2, "YOU KEEP", C.lime)
	local gains = col(3, "YOU GAIN", C.gold)
	local why = Theme.label({ Position = UDim2.fromOffset(0, 270), Size = UDim2.new(1, -10, 0, 22), Text = "Why? Your Goobers earn more forever, so every future run is faster.", TextColor3 = C.sub, MaxText = 16, Parent = body })
	local confirmUntil = 0
	local btn
	btn = Theme.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 298), Size = UDim2.fromOffset(300, 56), Text = "REBIRTH", Color = Color3.fromRGB(190, 100, 255), Parent = body }, function()
		local s = State.data
		if not s then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.Event("Rebirth"):FireServer()
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
		req.Text = ("%s Level %d   %s $%s Slop Coins"):format(if lvlOk then "✅" else "❌", s.rebirthLevel, if coinOk then "✅" else "❌", Util.Short(s.rebirthCost))
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
	local _, body = panelShell("Odds", "🎲  ODDS INFO", Color3.fromRGB(60, 150, 140))
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
	local _, body = panelShell("Shop", "🛒  SHOP", Color3.fromRGB(230, 150, 30))
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
		gl.CellSize = UDim2.new(0.5, -6, 0, 168)
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
			Theme.label({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(56, 56), Text = icon, Stroke = false, MaxText = 40, Parent = f })
		end
		Theme.label({ Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -78, 0, 28), Text = name, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 21, Parent = f })
		local d = Theme.label({ Position = UDim2.fromOffset(70, 38), Size = UDim2.new(1, -78, 0, 66), Text = desc, TextWrapped = true, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Body, MaxText = 14, Parent = f })
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
				c.buy.Text = "OWNED ✔"
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
	local _, body = panelShell("Settings", "⚙️  SETTINGS", C.panel2)
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
		local hasMusic = Config.Sounds.Music ~= ""
		local hasSfx = Config.Sounds.Coin ~= ""
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
	-- status pills
	refs.boostPill.Visible = s.boostLeft > 0
	refs.boostText.Text = "⚡ 2x Income  " .. Util.Time(s.boostLeft)
	if s.lockLeft > 0 then
		refs.lockText.Text = "🔒 Base locked  " .. Util.Time(s.lockLeft)
		refs.lockPill.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
	elseif s.lockReadyIn > 0 then
		refs.lockText.Text = "🔓 Lock ready in " .. Util.Time(s.lockReadyIn)
		refs.lockPill.BackgroundColor3 = C.gray
	else
		refs.lockText.Text = "🔓 Lock ready - step on the red pad"
		refs.lockPill.BackgroundColor3 = Color3.fromRGB(200, 70, 90)
	end
	refs.lockPill.Visible = s.level >= Config.StealLevel or s.lockLeft > 0
	refs.dropText.Text = "🎁 Personal Drop in " .. Util.Time(s.nextDropIn)
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
		refs.chaosText.Text = ("🌀 %s!  %s"):format(def.title, Util.Time(left))
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

return UI

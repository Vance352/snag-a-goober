--[[
	EventUI - the Halloween update's panels:
	  * EVENT     : event track (25 levels, claim + next-reward preview),
	                Candy Shop, Halloween collection rewards
	  * QUESTS    : the Halloween quest chain + 3 daily quests
	  * LEVELS    : player-level progression, area unlocks, milestone rewards
	  * the first-arrival Halloween Island intro (with Skip)
	All numbers come from the server snapshot (State); buttons only ask.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Halloween = require(ReplicatedStorage.Shared.Halloween)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local Effects = require(script.Parent.Effects)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local C = Theme.C
local ORANGE = Color3.fromRGB(255, 128, 30)
local PURPLE = Color3.fromRGB(120, 60, 180)

local EventUI = {}

local function trackReward(level: number)
	local t = Halloween.Track[level]
	local r = {}
	if t.kind == "candy" then
		r.candy = t.n
	elseif t.kind == "coins" then
		r.coins = t.n
	elseif t.kind == "boost" then
		r.boost = t.n
	elseif t.kind == "goober" then
		r.goober = t.id
	elseif t.kind == "title" then
		r.title = t.text
	end
	if t.title then
		r.title = t.title
	end
	return r, t
end

local KIND_ICON = { candy = "candy", coins = "coin", boost = "bolt", title = "scroll" }

local function claimState(button: GuiObject, state: string, label: string?)
	-- state: "claim" | "done" | "locked"
	button.Text = label or (if state == "claim" then "CLAIM" elseif state == "done" then "CLAIMED" else "LOCKED")
	button.BackgroundColor3 = if state == "claim" then C.lime elseif state == "done" then C.panel else C.gray
	if button:IsA("GuiButton") then
		button.Active = state == "claim"
		button.AutoButtonColor = false
	end
end

local function list(parent: Instance, pad: number?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, pad or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3)
	local b = Theme.frame({ Position = pos, Size = size, BackgroundColor3 = C.ink, Parent = parent })
	Theme.corner(b, 9)
	Theme.stroke(b, 2)
	local fill = Theme.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = b })
	Theme.corner(fill, 9)
	local text = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "", MaxText = 14, ZIndex = 2, Parent = b })
	return fill, text
end

-- ============================================================== EVENT
local function buildEvent()
	local _, body = UI.panelShell("Halloween", "HALLOWEEN EVENT", ORANGE, "pumpkin")
	local tabs = {}
	local pages = {}
	local current = "Track"
	local function select(key)
		if not pages[key] then
			return
		end
		current = key
		for k, p in pairs(pages) do
			p.Visible = k == key
			tabs[k].BackgroundColor3 = if k == key then ORANGE else C.panel2
		end
	end
	UI.tabSelect.Halloween = select
	for i, t in ipairs({ { "Track", "TRACK", "trophy" }, { "Shop", "CANDY SHOP", "candy" }, { "Collection", "COLLECTION", "book" } }) do
		local b = Theme.button({ Position = UDim2.new((i - 1) / 3, 2, 0, 0), Size = UDim2.new(1 / 3, -6, 0, 44), Text = "", Color = C.panel2, Parent = body }, function()
			Effects.Play("Click")
			select(t[1])
			UI.panelRefresh.Halloween()
		end)
		Theme.icon(t[3], { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(36, 36), Parent = b })
		Theme.label({ Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -48, 1, -10), Text = t[2], MaxText = 17, Parent = b })
		tabs[t[1]] = b
		local page = Theme.frame({ Name = t[1], Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = body })
		pages[t[1]] = page
	end

	-- ------------------------------------------------------- track page
	local tp = pages.Track
	local lvl = Theme.label({ Size = UDim2.new(0.5, 0, 0, 28), Text = "EVENT LEVEL 0", TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 26, Parent = tp })
	local timer = Theme.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, 0, 0, 28), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 16, MinText = 10, Parent = tp })
	local xpFill, xpText = bar(tp, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 22), ORANGE)
	local nextCard = Theme.frame({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(80, 40, 100), Parent = tp })
	Theme.corner(nextCard, 12)
	Theme.stroke(nextCard, 2.5, ORANGE)
	local nextIcon = Theme.icon("gift", { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(38, 38), Parent = nextCard })
	local nextText = Theme.label({ Position = UDim2.fromOffset(50, 4), Size = UDim2.new(1, -56, 1, -8), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, MinText = 10, Parent = nextCard })
	local strip = Instance.new("ScrollingFrame")
	strip.Position = UDim2.fromOffset(0, 108)
	strip.Size = UDim2.new(1, 0, 0, 176)
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = 8
	strip.ScrollBarImageColor3 = C.sub
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.CanvasSize = UDim2.new()
	strip.Parent = tp
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 8)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = strip
	local cards = {}
	for level = 1, Halloween.MaxEventLevel do
		local reward, t = trackReward(level)
		-- the whole card is the button (big touch target); the bar at the bottom shows its state
		local card = Instance.new("TextButton")
		card.Text = ""
		card.AutoButtonColor = false
		card.Size = UDim2.fromOffset(112, 164)
		card.BackgroundColor3 = C.panel2
		card.LayoutOrder = level
		card.Parent = strip
		card.Activated:Connect(function()
			Effects.Play("Click")
			Net.Event("ClaimEvent"):FireServer(level)
		end)
		Theme.corner(card, 14)
		local stroke = Theme.stroke(card, 3)
		Theme.label({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 22), Text = "LV " .. level, TextColor3 = C.gold, MaxText = 18, Parent = card })
		if t.kind == "goober" then
			local vp = UI.GooberViewport(t.id, card, UDim2.fromOffset(70, 64))
			vp.Position = UDim2.new(0.5, -35, 0, 24)
		else
			Theme.icon(KIND_ICON[t.kind] or "gift", { Position = UDim2.new(0.5, -30, 0, 26), Size = UDim2.fromOffset(60, 60), Parent = card })
		end
		local rtext = Theme.label({ Position = UDim2.fromOffset(4, 88), Size = UDim2.new(1, -8, 0, 30), Text = UI.RewardText(reward, true), TextWrapped = true, MaxText = 14, MinText = 10, Parent = card })
		local btn = Theme.label({ Position = UDim2.new(0, 6, 1, -42), Size = UDim2.new(1, -12, 0, 36), Text = "LOCKED", MaxText = 16, MinText = 10, Parent = card })
		btn.BackgroundTransparency = 0
		btn.BackgroundColor3 = C.gray
		Theme.corner(btn, 10)
		Theme.stroke(btn, 2.5)
		cards[level] = { card = card, stroke = stroke, btn = btn, rtext = rtext, reward = reward }
	end
	Theme.label({ Position = UDim2.fromOffset(0, 310), Size = UDim2.new(1, 0, 0, 40), Text = "Earn Event XP: bring Halloween Goobers home, find hidden candy, grab Candy Buckets and finish quests.", TextWrapped = true, TextColor3 = C.sub, Font = Theme.Body, MaxText = 15, Parent = tp })
	Theme.frame({ Position = UDim2.fromOffset(0, 350), Size = UDim2.fromOffset(1, 4), BackgroundTransparency = 1, Parent = tp })

	-- -------------------------------------------------------- shop page
	local sp = pages.Shop
	local wallet = Theme.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", TextColor3 = Color3.fromRGB(255, 170, 220), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = sp })
	local sg = Theme.frame({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sp })
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.5, -6, 0, 132)
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = sg
	local shopCards = {}
	for i, item in ipairs(Halloween.Shop) do
		local f = Theme.frame({ BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = sg })
		Theme.corner(f, 14)
		if item.kind == "goober" then
			local vp = UI.GooberViewport(item.id, f, UDim2.fromOffset(72, 72))
			vp.Position = UDim2.fromOffset(4, 4)
		else
			Theme.icon(if item.kind == "boost" then "bolt" else "coin", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(60, 60), Parent = f })
		end
		Theme.label({ Position = UDim2.fromOffset(80, 6), Size = UDim2.new(1, -86, 0, 26), Text = item.name, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 19, Parent = f })
		Theme.label({ Position = UDim2.fromOffset(80, 32), Size = UDim2.new(1, -86, 0, 44), Text = item.desc, TextWrapped = true, TextColor3 = C.sub, Font = Theme.Body, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxText = 14, Parent = f })
		local buy = Theme.button({ Position = UDim2.new(0, 8, 1, -46), Size = UDim2.new(1, -16, 0, 38), Text = "", Color = ORANGE, MaxText = 18, Parent = f }, function()
			Effects.Play("Click")
			Net.Event("EventBuy"):FireServer(item.key)
		end)
		Theme.icon("candy", { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(32, 32), Parent = buy })
		shopCards[item.key] = buy
	end

	-- -------------------------------------------------- collection page
	local cp = pages.Collection
	local chead = Theme.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = cp })
	local cfill, ctext = bar(cp, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 20), ORANGE)
	local mrows = Theme.frame({ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 4 * 54), BackgroundTransparency = 1, Parent = cp })
	list(mrows, 6)
	local mbtns = {}
	for i, m in ipairs(Halloween.DexRewards) do
		local row = Theme.frame({ Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = mrows })
		Theme.corner(row, 12)
		Theme.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0, 70, 1, -8), Text = ("%d/%d"):format(m.count, GooberData.HalloweenCount), TextColor3 = C.gold, MaxText = 20, Parent = row })
		Theme.label({ Position = UDim2.fromOffset(84, 4), Size = UDim2.new(1, -220, 1, -8), Text = UI.RewardText({ candy = m.candy, boost = m.boost, title = m.title }), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Parent = row })
		mbtns[m.count] = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(122, 38), Text = "", Color = C.gray, MaxText = 16, Parent = row }, function()
			Effects.Play("Click")
			Net.Event("ClaimHDex"):FireServer(m.count)
		end)
	end
	local cg = Theme.frame({ Position = UDim2.fromOffset(0, 62 + 4 * 54 + 6), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = cp })
	local cgl = Instance.new("UIGridLayout")
	cgl.CellSize = UDim2.fromOffset(92, 110)
	cgl.CellPadding = UDim2.fromOffset(6, 6)
	cgl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cgl.SortOrder = Enum.SortOrder.LayoutOrder
	cgl.Parent = cg
	local hcards = {}
	for i, def in ipairs(GooberData.PoolList.Halloween) do
		local f = Theme.frame({ BackgroundColor3 = C.panel2, LayoutOrder = i, Parent = cg })
		Theme.corner(f, 12)
		Theme.stroke(f, 2.5, Config.Rarities[def.rarity].color)
		local name = Theme.label({ Position = UDim2.new(0, 3, 1, -24), Size = UDim2.new(1, -6, 0, 22), Text = "???", MaxText = 13, Parent = f })
		hcards[def.id] = { frame = f, name = name, found = nil, vp = nil }
	end

	UI.panelRefresh.Halloween = function()
		local s = State.data
		local ev = s and s.event
		if not ev then
			return
		end
		if current == "Track" then
			lvl.Text = ("EVENT LEVEL %d"):format(ev.eventLevel)
			timer.Text = if ev.eventEndsIn > 0 then ("Ends in %s"):format(Util.Time(ev.eventEndsIn)) else "Event over - rewards stay claimable"
			if ev.eventNeed > 0 then
				xpFill.Size = UDim2.fromScale(math.clamp(ev.eventXp / ev.eventNeed, 0.02, 1), 1)
				xpText.Text = ("%d / %d Event XP"):format(ev.eventXp, ev.eventNeed)
			else
				-- track done: Event XP fills Bonus Chests
				xpFill.Size = UDim2.fromScale(math.clamp((ev.bonusXp or 0) / (ev.bonusEvery or 1), 0.02, 1), 1)
				xpText.Text = ("MAX! Bonus Chest %d / %d"):format(ev.bonusXp or 0, ev.bonusEvery or 0)
			end
			if (ev.placeLeft or 0) <= 0 and ev.active then
				timer.Text = "Daily full XP used - dailies still pay!"
			end
			-- next-reward preview: the first unclaimed level at or above your level
			local nextL
			for l = 1, Halloween.MaxEventLevel do
				if not ev.eventClaimed[tostring(l)] then
					nextL = l
					break
				end
			end
			if nextL then
				local r, t = trackReward(nextL)
				nextIcon.Image = require(ReplicatedStorage.Shared.Icons)[KIND_ICON[t.kind] or "gift"]
				nextText.Text = if nextL <= ev.eventLevel
					then ("<font color=\"#7BE35A\">READY:</font> Level %d - %s"):format(nextL, UI.RewardText(r))
					else ("NEXT: Level %d - %s"):format(nextL, UI.RewardText(r))
			else
				nextText.Text = "Every event reward claimed. Lord of Halloween!"
			end
			for l, c in pairs(cards) do
				local claimed = ev.eventClaimed[tostring(l)] == true
				local ready = l <= ev.eventLevel and not claimed
				claimState(c.btn, if claimed then "done" elseif ready then "claim" else "locked")
				c.stroke.Color = if ready then C.lime elseif l == ev.eventLevel + 1 then ORANGE else C.ink
				c.card.BackgroundColor3 = if claimed then C.panel else C.panel2
				if c.reward.coins then
					c.rtext.Text = UI.RewardText(c.reward, true) -- coins scale with your income
				end
			end
		elseif current == "Shop" then
			wallet.Text = ("You have %s Candy"):format(Util.Comma(ev.candy))
			for _, item in ipairs(Halloween.Shop) do
				local b = shopCards[item.key]
				b.Text = "      " .. Util.Comma(item.price)
				b.BackgroundColor3 = if ev.candy >= item.price then ORANGE else C.gray
			end
		else
			local n = ev.hdexCount
			chead.Text = ("Halloween Goobers found: %d / %d"):format(n, GooberData.HalloweenCount)
			cfill.Size = UDim2.fromScale(math.clamp(n / GooberData.HalloweenCount, 0.02, 1), 1)
			ctext.Text = ("%d%%"):format(math.floor(n / GooberData.HalloweenCount * 100))
			for count, b in pairs(mbtns) do
				local claimed = ev.hdexClaimed[tostring(count)] == true
				claimState(b, if claimed then "done" elseif n >= count then "claim" else "locked", if not claimed and n < count then ("Find %d"):format(count) else nil)
			end
			for gid, c in pairs(hcards) do
				local found = s.dex[gid] ~= nil
				if c.found ~= found then
					c.found = found
					if c.vp then
						c.vp:Destroy()
					end
					c.vp = UI.GooberViewport(gid, c.frame, UDim2.new(1, -8, 1, -30), not found)
					c.vp.Position = UDim2.fromOffset(4, 4)
					c.name.Text = if found then GooberData.ById[gid].name else "???"
				end
			end
		end
	end
	select("Track")
end

-- ============================================================= QUESTS
local function buildQuests()
	local _, body = UI.panelShell("Quests", "QUESTS", Color3.fromRGB(220, 70, 140), "scroll")
	local holder = Theme.frame({ Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
	list(holder, 8)
	Theme.label({ Size = UDim2.new(1, 0, 0, 28), Text = "HALLOWEEN QUEST", TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, LayoutOrder = 1, Parent = holder })
	local chain = Theme.frame({ Size = UDim2.new(1, 0, 0, 138), BackgroundColor3 = Color3.fromRGB(80, 40, 100), LayoutOrder = 2, Parent = holder })
	Theme.corner(chain, 14)
	local chainStroke = Theme.stroke(chain, 3)
	local cIdx = Theme.label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Text = "", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, Parent = chain })
	local cText = Theme.label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 28), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = chain })
	local cHint = Theme.label({ Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 20), Text = "", TextColor3 = C.sub, Font = Theme.Body, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, MaxText = 14, Parent = chain })
	local cFill, cCount = bar(chain, UDim2.fromOffset(10, 80), UDim2.new(1, -150, 0, 20), ORANGE)
	local cReward = Theme.label({ Position = UDim2.fromOffset(10, 106), Size = UDim2.new(1, -150, 0, 24), Text = "", TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Parent = chain })
	local cBtn = Theme.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(126, 48), Text = "CLAIM", Color = C.gray, MaxText = 20, Parent = chain }, function()
		Effects.Play("Click")
		Net.Event("ClaimQuest"):FireServer("chain")
	end)
	local dHead = Theme.label({ Size = UDim2.new(1, 0, 0, 28), Text = "DAILY QUESTS", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, LayoutOrder = 3, Parent = holder })
	local daily = {}
	for i = 1, Halloween.DailyCount do
		local row = Theme.frame({ Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = C.panel2, LayoutOrder = 3 + i, Parent = holder })
		Theme.corner(row, 12)
		local stroke = Theme.stroke(row, 2.5)
		local text = Theme.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 26), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = row })
		local fill, count = bar(row, UDim2.fromOffset(10, 34), UDim2.new(1, -150, 0, 18), C.lime)
		local reward = Theme.label({ Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -150, 0, 22), Text = "", TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = row })
		local btn = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(126, 48), Text = "", Color = C.gray, MaxText = 18, Parent = row }, function()
			Effects.Play("Click")
			Net.Event("ClaimQuest"):FireServer("daily", i)
		end)
		daily[i] = { row = row, stroke = stroke, text = text, fill = fill, count = count, reward = reward, btn = btn }
	end
	UI.panelRefresh.Quests = function()
		local s = State.data
		local q = s and s.quests
		if not q then
			return
		end
		local cq = q.chain
		if cq then
			local done = cq.progress >= cq.target
			cIdx.Text = ("QUEST %d OF %d"):format(q.chainIndex, q.chainTotal)
			cText.Text = cq.text
			cHint.Text = cq.hint or ""
			cFill.Size = UDim2.fromScale(math.clamp(cq.progress / math.max(1, cq.target), 0.02, 1), 1)
			cCount.Text = ("%s / %s"):format(Util.Short(cq.progress), Util.Short(cq.target))
			cReward.Text = "Reward: " .. UI.RewardText(cq.reward)
			claimState(cBtn, if done then "claim" else "locked", if done then "CLAIM" else "IN PROGRESS")
			chainStroke.Color = if done then C.lime else C.ink
		else
			cIdx.Text = "ALL DONE"
			cText.Text = "You finished every Halloween quest!"
			cHint.Text = "Daily quests still refresh every day."
			cFill.Size = UDim2.fromScale(1, 1)
			cCount.Text = "COMPLETE"
			cReward.Text = ""
			claimState(cBtn, "done", "DONE")
		end
		dHead.Text = ("DAILY QUESTS  <font color=\"#CDBEEB\">new ones in %s</font>"):format(Util.Time(q.dailyResetIn))
		for i, d in ipairs(daily) do
			local e = q.daily[i]
			d.row.Visible = e ~= nil
			if e then
				d.text.Text = e.text
				d.fill.Size = UDim2.fromScale(math.clamp(e.progress / math.max(1, e.target), 0.02, 1), 1)
				d.count.Text = ("%s / %s"):format(Util.Short(e.progress), Util.Short(e.target))
				d.reward.Text = "Reward: " .. UI.RewardText(e.reward)
				local done = e.progress >= e.target
				claimState(d.btn, if e.claimed then "done" elseif done then "claim" else "locked", if e.claimed then "CLAIMED" elseif done then "CLAIM" else "IN PROGRESS")
				d.stroke.Color = if done and not e.claimed then C.lime else C.ink
			end
		end
	end
end

-- ============================================================= LEVELS
local function buildLevels()
	local _, body = UI.panelShell("Levels", "LEVEL PROGRESSION", Color3.fromRGB(110, 80, 220), "trophy")
	local holder = Theme.frame({ Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = body })
	list(holder, 8)
	local top = Theme.frame({ Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder })
	local lv = Theme.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxText = 26, Parent = top })
	local fill, txt = bar(top, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 22), C.lime)
	local hint = Theme.label({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 16), Text = "Earn XP by bringing Goobers home, discovering new ones and stealing.", TextColor3 = C.sub, Font = Theme.Body, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 13, Parent = top })
	local _ = hint
	Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = "HALLOWEEN ISLAND AREAS", TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, LayoutOrder = 2, Parent = holder })
	local areaRows = {}
	for i, a in ipairs(Halloween.Areas) do
		local row = Theme.frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.panel2, LayoutOrder = 2 + i, Parent = holder })
		Theme.corner(row, 12)
		local ic = Theme.icon("lock", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(36, 36), Parent = row })
		Theme.label({ Position = UDim2.fromOffset(48, 3), Size = UDim2.new(1, -250, 1, -6), Text = ("<font color=\"#%s\">%s</font>"):format(a.color:ToHex(), a.name), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = row })
		local st = Theme.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 3), Size = UDim2.new(0, 190, 1, -6), Text = "", TextXAlignment = Enum.TextXAlignment.Right, MaxText = 16, MinText = 10, Parent = row })
		areaRows[i] = { icon = ic, status = st, level = a.level, eventLevel = a.eventLevel or 0 }
	end
	Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = "LEVEL REWARDS", TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, LayoutOrder = 10, Parent = holder })
	local mrows = {}
	for i, m in ipairs(Halloween.LevelMilestones) do
		local row = Theme.frame({ Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.panel2, LayoutOrder = 10 + i, Parent = holder })
		Theme.corner(row, 12)
		local stroke = Theme.stroke(row, 2.5)
		Theme.label({ Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(70, 52), Text = "LV " .. m.level, TextColor3 = C.gold, MaxText = 22, Parent = row })
		Theme.label({ Position = UDim2.fromOffset(84, 4), Size = UDim2.new(1, -222, 0, 26), Text = m.text, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 17, Parent = row })
		local rtext = Theme.label({ Position = UDim2.fromOffset(84, 30), Size = UDim2.new(1, -222, 0, 24), Text = UI.RewardText(m.reward), TextColor3 = C.lime, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = row })
		local btn = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(124, 44), Text = "", Color = C.gray, MaxText = 17, Parent = row }, function()
			Effects.Play("Click")
			Net.Event("ClaimLevel"):FireServer(m.level)
		end)
		mrows[i] = { btn = btn, stroke = stroke, level = m.level, rtext = rtext, reward = m.reward }
	end
	local Icons = require(ReplicatedStorage.Shared.Icons)
	UI.panelRefresh.Levels = function()
		local s = State.data
		if not s then
			return
		end
		lv.Text = ("LEVEL %d"):format(s.level)
		fill.Size = UDim2.fromScale(math.clamp(s.xp / math.max(1, s.xpNeeded), 0.02, 1), 1)
		txt.Text = ("%s / %s XP"):format(Util.Short(s.xp), Util.Short(s.xpNeeded))
		local evl = s.event and s.event.eventLevel or 0
		for _, r in ipairs(areaRows) do
			local open = s.level >= r.level and evl >= r.eventLevel
			r.icon.Image = if open then Icons.check else Icons.lock
			if open then
				r.status.Text = "<font color=\"#7BE35A\">OPEN</font>"
			elseif r.eventLevel > 0 then
				r.status.Text = ("<font color=\"#%s\">Lv %d</font> + <font color=\"#%s\">Event %d</font>"):format(
					if s.level >= r.level then "7BE35A" else "FFFFFF", r.level, if evl >= r.eventLevel then "7BE35A" else "FFB060", r.eventLevel)
			else
				r.status.Text = ("Level %d"):format(r.level)
			end
		end
		local claimed = s.event and s.event.levelClaimed or {}
		for _, r in ipairs(mrows) do
			local done = claimed[tostring(r.level)] == true
			local ready = s.level >= r.level and not done
			claimState(r.btn, if done then "done" elseif ready then "claim" else "locked", if not done and not ready then ("Lv %d"):format(r.level) else nil)
			r.stroke.Color = if ready then C.lime else C.ink
			r.rtext.Text = UI.RewardText(r.reward)
		end
	end
end

-- ============================================================== intro
local function buildIntro()
	local dim = Theme.frame({ Name = "IntroModal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 40, Active = true, Parent = UI.root })
	local p = Theme.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.84), BackgroundColor3 = Color3.fromRGB(46, 22, 66), ZIndex = 41, Parent = dim })
	Theme.corner(p, 22)
	Theme.stroke(p, 4, ORANGE)
	local sizer = Instance.new("UISizeConstraint")
	sizer.MaxSize = Vector2.new(560, 340)
	sizer.Parent = p
	local icon = Theme.icon("pumpkin", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(84, 84), ZIndex = 42, Parent = p })
	local title = Theme.label({ Position = UDim2.fromOffset(16, 96), Size = UDim2.new(1, -32, 0, 40), Text = "", TextColor3 = ORANGE, MaxText = 32, Stroke = 3, ZIndex = 42, Parent = p })
	local text = Theme.label({ Position = UDim2.fromOffset(24, 138), Size = UDim2.new(1, -48, 1, -226), Text = "", TextWrapped = true, Font = Theme.Body, TextYAlignment = Enum.TextYAlignment.Center, MaxText = 24, ZIndex = 42, Parent = p })
	local dots = Theme.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -66), Size = UDim2.fromOffset(120, 16), Text = "", TextColor3 = C.sub, MaxText = 14, ZIndex = 42, Parent = p })
	local PAGES = {
		{ "pumpkin", "WELCOME TO HALLOWEEN ISLAND!", "Spooky Goobers ride the island's belts. Snag one, carry it back through the portal and it joins your base, earning Slop like any other Goober." },
		{ "lock", "FIVE AREAS TO EXPLORE", "Halloween Village and the Pumpkin Patch are open to everyone. The Haunted Forest needs Level 8 + Event Level 3, the Cursed Graveyard Level 15 + Event 8, the Phantom Castle Level 25 + Event 14. Rarer Goobers live deeper in." },
		{ "candy", "CANDY, QUESTS AND REWARDS", "Find 30 hidden candies, grab Candy Buckets and finish quests. Everything gives Event XP: level up the 25-step Event Track and spend Candy in the Candy Shop by the Great Pumpkin." },
	}
	local page = 1
	local Icons = require(ReplicatedStorage.Shared.Icons)
	local nextBtn
	local function show()
		local pg = PAGES[page]
		icon.Image = Icons[pg[1]]
		title.Text = pg[2]
		text.Text = pg[3]
		dots.Text = string.rep("o ", page - 1) .. "O" .. string.rep(" o", #PAGES - page)
		nextBtn.Text = if page < #PAGES then "NEXT" else "LET'S GO!"
	end
	local function finish()
		dim.Visible = false
		Net.Event("IntroSeen"):FireServer()
	end
	Theme.button({ Name = "IntroSkip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -14), Size = UDim2.fromOffset(140, 48), Text = "SKIP", Color = C.panel2, MaxText = 20, ZIndex = 43, Parent = p }, function()
		Effects.Play("Click")
		finish()
	end).ZIndex = 43
	nextBtn = Theme.button({ Name = "IntroNext", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -14), Size = UDim2.fromOffset(180, 48), Text = "NEXT", Color = ORANGE, MaxText = 20, ZIndex = 43, Parent = p }, function()
		Effects.Play("Click")
		if page < #PAGES then
			page += 1
			show()
		else
			finish()
		end
	end)
	UI.zify(dim, 41)
	UI.ShowIntro = function()
		page = 1
		show()
		UI.Close()
		dim.Visible = true
		Effects.Pop(p)
	end
end

-- ============================================================== badges
local function badges(s)
	local refs = UI.refs
	local ev = s.event
	local q = s.quests
	if ev then
		local any = false
		for l = 1, math.min(ev.eventLevel, Halloween.MaxEventLevel) do
			if not ev.eventClaimed[tostring(l)] then
				any = true
			end
		end
		for _, m in ipairs(Halloween.DexRewards) do
			if ev.hdexCount >= m.count and not ev.hdexClaimed[tostring(m.count)] then
				any = true
			end
		end
		refs.menuHalloween.Badge.Visible = any and UI.openPanel ~= "Halloween"
		local lv = false
		for _, m in ipairs(Halloween.LevelMilestones) do
			if s.level >= m.level and not ev.levelClaimed[tostring(m.level)] then
				lv = true
			end
		end
		refs.menuLevels.Badge.Visible = lv and UI.openPanel ~= "Levels"
	end
	if q then
		local any = q.chain ~= nil and q.chain.progress >= q.chain.target
		for _, e in ipairs(q.daily) do
			if e.progress >= e.target and not e.claimed then
				any = true
			end
		end
		refs.menuQuests.Badge.Visible = any and UI.openPanel ~= "Quests"
	end
end

function EventUI.Build()
	buildEvent()
	buildQuests()
	buildLevels()
	for _, name in ipairs({ "Halloween", "Quests", "Levels" }) do
		UI.zify(UI.panels[name], 21)
	end
	buildIntro()
	UI.OnStateExtra = function(s)
		badges(s)
	end
	if State.data then
		badges(State.data)
	end
end

return EventUI

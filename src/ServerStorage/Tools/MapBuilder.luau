--[[
	MapBuilder - edit-time tool that (re)builds the static map from Config.
	Run from the Studio command bar / MCP:
	    require(game.ServerStorage.Tools.MapBuilder).Build()

	Uses Blender-made templates from ReplicatedStorage.Assets.Props when they
	exist (P_Stand, P_BeltSegment, ...), otherwise simple parts so the layout
	is always playable.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Edit-time tool: require a fresh copy so Studio's module cache never serves a
-- stale Config after a sync.
local Config = require(ReplicatedStorage.Shared.Config:Clone())

local MapBuilder = {}
local M = Config.Map

local PLOT_COLORS = {
	Color3.fromRGB(255, 179, 199),
	Color3.fromRGB(179, 229, 255),
	Color3.fromRGB(200, 247, 166),
	Color3.fromRGB(255, 227, 163),
	Color3.fromRGB(217, 184, 255),
	Color3.fromRGB(255, 201, 163),
	Color3.fromRGB(168, 240, 224),
	Color3.fromRGB(240, 240, 240),
}

local COL = {
	ground = Color3.fromRGB(126, 214, 120),
	groundDark = Color3.fromRGB(96, 186, 98),
	path = Color3.fromRGB(246, 230, 186),
	frame = Color3.fromRGB(74, 47, 122),
	belt = Color3.fromRGB(43, 40, 56),
	gold = Color3.fromRGB(255, 196, 61),
	wall = Color3.fromRGB(255, 255, 255),
	trim = Color3.fromRGB(91, 62, 140),
	cash = Color3.fromRGB(123, 227, 90),
	lock = Color3.fromRGB(255, 77, 94),
	laser = Color3.fromRGB(255, 60, 90),
}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function prop(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local t = props and props:FindFirstChild(name)
	if t then
		local c = t:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		return c
	end
	return nil
end

local function textGui(parent: Instance, face: Enum.NormalId, lines: { { name: string, text: string, size: number, color: Color3 } })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for i, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.Name = l.name
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.96, l.size)
		t.Text = l.text
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = l.color
		t.LayoutOrder = i
		local s = Instance.new("UIStroke")
		s.Thickness = 4
		s.Color = Color3.fromRGB(30, 18, 50)
		s.Parent = t
		t.Parent = gui
	end
	gui.Parent = parent
	return gui
end

local function billboard(parent: Instance, name: string, size: Vector2, offset: Vector3, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(size.X * 22, size.Y * 22) -- pixel size: readable, never screen-filling
	gui.StudsOffsetWorldSpace = offset
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.5)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = Color3.fromRGB(30, 18, 50)
	s.Parent = t
	t.Parent = gui
	local a = t:Clone()
	a.Name = "Amount"
	a.Text = ""
	a.TextColor3 = Color3.new(1, 1, 1)
	a.LayoutOrder = 2
	a.Parent = gui
	gui.Parent = parent
	return gui
end

-- --------------------------------------------------------------- stands
local STAND_COLS = { -16, -8, 8, 16 }
local STAND_ROWS = { -17, -9.5, -2, 5.5, 13, 20.5, 28 }

local function buildStand(parent: Instance, index: number, cf: CFrame)
	local stand = prop("P_Stand")
	if stand then
		stand:PivotTo(cf)
	else
		stand = Instance.new("Model")
		part({
			Name = "Base",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 3.4, 3.4),
			CFrame = cf * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(91, 62, 140),
			Parent = stand,
		})
		part({
			Name = "Top",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 3.0, 3.0),
			CFrame = cf * CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(237, 230, 255),
			Parent = stand,
		})
		part({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 3.2, 3.2),
			CFrame = cf * CFrame.new(0, 0.92, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(176, 183, 195),
			Parent = stand,
		})
	end
	stand.Name = "Stand" .. index
	stand:SetAttribute("Index", index)
	for _, d in ipairs(stand:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = d.Name == "Base"
			d:SetAttribute("BaseTransparency", d.Transparency)
		end
	end
	local top = stand:FindFirstChild("Top") :: BasePart
	local tag = Instance.new("BillboardGui")
	tag.Name = "LockedTag"
	tag.Size = UDim2.fromScale(4, 1)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	tag.MaxDistance = 40
	tag.Enabled = false
	tag.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "🔒 More Stands"
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(230, 220, 255)
	t.Parent = tag
	tag.Parent = top
	stand.PrimaryPart = top
	stand.Parent = parent
	return stand
end

-- ---------------------------------------------------------------- plots
local function buildPlot(parent: Instance, index: number, center: Vector3, look: Vector3)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerId", 0)
	local cf = CFrame.lookAt(center, center + look)
	local W, D = M.plotSize.X, M.plotSize.Y
	local color = PLOT_COLORS[index]

	part({ Name = "Bounds", Size = Vector3.new(W + 2, 24, D + 2), CFrame = cf * CFrame.new(0, 12, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })
	part({ Name = "Floor", Size = Vector3.new(W, 1, D), CFrame = cf * CFrame.new(0, 0.5, 0), Color = color, Material = Enum.Material.Plastic, Parent = plot })
	-- inner tile pattern
	for i = 0, 3 do
		part({ Name = "Tile", Size = Vector3.new(W - 4, 0.06, 0.4), CFrame = cf * CFrame.new(0, 1.02, -12 + i * 14), Color = color:Lerp(Color3.new(1, 1, 1), 0.45), CanCollide = false, Parent = plot })
	end
	-- centre aisle carpet
	part({ Name = "Aisle", Size = Vector3.new(8, 0.08, D - 4), CFrame = cf * CFrame.new(0, 1.03, 2), Color = color:Lerp(Color3.new(0, 0, 0), 0.12), CanCollide = false, Parent = plot })

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = plot
	local wallH = 4
	local function wall(size, offset)
		part({ Name = "Wall", Size = size, CFrame = cf * CFrame.new(offset), Color = COL.wall, Parent = walls })
		part({ Name = "Trim", Size = size + Vector3.new(0.3, -size.Y + 0.5, 0.3), CFrame = cf * CFrame.new(offset + Vector3.new(0, size.Y / 2, 0)), Color = color:Lerp(COL.trim, 0.55), Parent = walls })
	end
	wall(Vector3.new(W, wallH, 1), Vector3.new(0, 1 + wallH / 2, D / 2 - 0.5))
	wall(Vector3.new(1, wallH, D), Vector3.new(-W / 2 + 0.5, 1 + wallH / 2, 0))
	wall(Vector3.new(1, wallH, D), Vector3.new(W / 2 - 0.5, 1 + wallH / 2, 0))
	local gap = 16
	local seg = (W - gap) / 2
	wall(Vector3.new(seg, wallH, 1), Vector3.new(-(gap / 2 + seg / 2), 1 + wallH / 2, -D / 2 + 0.5))
	wall(Vector3.new(seg, wallH, 1), Vector3.new(gap / 2 + seg / 2, 1 + wallH / 2, -D / 2 + 0.5))

	-- gentle ramp over the floor lip at the entrance
	local ramp = Instance.new("WedgePart")
	ramp.Name = "EntranceRamp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(gap, 1, 3)
	ramp.CFrame = cf * CFrame.new(0, 0.5, -D / 2 - 1.5) -- slope rises toward +Z (into the base)
	ramp.Color = color
	ramp.Material = Enum.Material.Plastic
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.Parent = plot

	-- entrance arch + owner sign
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Pillar", Size = Vector3.new(1.6, 11, 1.6), CFrame = cf * CFrame.new(sx * (gap / 2 + 0.8), 6.5, -D / 2 + 0.5), Color = color:Lerp(COL.trim, 0.6), Parent = plot })
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(gap + 6, 3.6, 0.8), CFrame = cf * CFrame.new(0, 12.6, -D / 2 + 0.5), Color = COL.trim, Parent = plot })
	textGui(sign, Enum.NormalId.Front, {
		{ name = "Owner", text = "Empty Base", size = 0.6, color = Color3.new(1, 1, 1) },
		{ name = "Info", text = "Join to claim!", size = 0.36, color = Color3.fromRGB(160, 255, 140) },
	})

	-- stands
	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = plot
	local idx = 0
	for _, z in ipairs(STAND_ROWS) do
		for _, x in ipairs(STAND_COLS) do
			idx += 1
			buildStand(stands, idx, cf * CFrame.new(x, 1, z))
		end
	end

	-- cash pad
	local cash = part({ Name = "CashPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9, 9), CFrame = cf * CFrame.new(0, 1.15, -24) * CFrame.Angles(0, 0, math.rad(90)), Color = COL.cash, Material = Enum.Material.Neon, CanCollide = false, Parent = plot })
	part({ Name = "CashPadRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 10, 10), CFrame = cf * CFrame.new(0, 1.1, -24) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 110, 40), CanCollide = false, Parent = plot })
	billboard(cash, "Bank", Vector2.new(8, 3), Vector3.new(0, 4, 0), "CASH PAD", Color3.fromRGB(150, 255, 120))

	-- lock pad
	local lock = part({ Name = "LockPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6, 6), CFrame = cf * CFrame.new(17, 1.15, -26) * CFrame.Angles(0, 0, math.rad(90)), Color = COL.lock, Material = Enum.Material.Neon, CanCollide = false, Parent = plot })
	billboard(lock, "LockInfo", Vector2.new(7, 2.6), Vector3.new(0, 3.5, 0), "LOCK BASE", Color3.fromRGB(255, 140, 150))

	-- upgrade station
	local station = prop("P_SlopOMatic")
	if station then
		station:PivotTo(cf * CFrame.new(-17, 1, -26) * CFrame.Angles(0, math.rad(180), 0))
	else
		station = Instance.new("Model")
		part({ Name = "Body", Size = Vector3.new(5, 6, 4), CFrame = cf * CFrame.new(-17, 4, -26), Color = Color3.fromRGB(110, 70, 190), Parent = station })
		part({ Name = "Screen", Size = Vector3.new(4, 2.5, 0.2), CFrame = cf * CFrame.new(-17, 5, -28.1), Color = Color3.fromRGB(123, 227, 90), Material = Enum.Material.Neon, Parent = station })
	end
	station.Name = "UpgradeStation"
	local console = part({ Name = "Console", Size = Vector3.new(4, 4, 4), CFrame = cf * CFrame.new(-17, 3, -26), Transparency = 1, CanCollide = false, Parent = station })
	billboard(console, "StationTag", Vector2.new(8, 2.6), Vector3.new(0, 5.2, 0), "SLOP-O-MATIC", Color3.fromRGB(200, 170, 255))
	station.Parent = plot

	-- spawn marker
	part({ Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = cf * CFrame.new(0, 0.6, -14), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })

	-- shield (shown while locked)
	local shield = Instance.new("Folder")
	shield.Name = "Shield"
	shield.Parent = plot
	local curtain = part({ Name = "Curtain", Size = Vector3.new(gap, 9, 0.3), CFrame = cf * CFrame.new(0, 5.5, -D / 2 + 0.5), Color = COL.laser, Material = Enum.Material.ForceField, CanCollide = false, CanQuery = false, Transparency = 1, Parent = shield })
	curtain:SetAttribute("OnTransparency", 0.2)
	local dome = part({ Name = "Dome", Size = Vector3.new(W + 10, 26, D + 10), CFrame = cf, Color = Color3.fromRGB(120, 180, 255), Material = Enum.Material.ForceField, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1, Parent = shield })
	dome:SetAttribute("OnTransparency", 0.55)
	local domeMesh = Instance.new("SpecialMesh")
	domeMesh.MeshType = Enum.MeshType.Sphere -- squashed dome over the base
	domeMesh.Parent = dome

	-- progression decor: hidden until the owner reaches the unlock (PlotService.UpdateDecor)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = plot
	local function decorItem(name: string, unlockKind: string, unlockValue: number, cfLocal: CFrame, fallbackSize: Vector3, fallbackColor: Color3)
		local m = prop(name)
		if m then
			m:PivotTo(cf * cfLocal)
		else
			m = Instance.new("Model")
			part({ Name = "Body", Size = fallbackSize, CFrame = cf * cfLocal * CFrame.new(0, fallbackSize.Y / 2, 0), Color = fallbackColor, Parent = m })
		end
		m:SetAttribute("UnlockKind", unlockKind)
		m:SetAttribute("UnlockValue", unlockValue)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d:SetAttribute("BaseTransparency", d.Transparency)
				d:SetAttribute("BaseCollide", d.CanCollide)
				if d.Name == "Cloth" then
					d.Color = color:Lerp(Color3.new(0, 0, 0), 0.15)
				end
			end
		end
		m.Parent = decor
	end
	decorItem("P_LampPost", "level", 5, CFrame.new(-21, 1, -29) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(0.6, 9, 0.6), COL.trim)
	decorItem("P_LampPost", "level", 5, CFrame.new(21, 1, -29) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 9, 0.6), COL.trim)
	decorItem("P_Flag", "level", 10, CFrame.new(-22, 1, 30), Vector3.new(0.4, 8, 0.4), COL.trim)
	decorItem("P_Flag", "level", 10, CFrame.new(22, 1, 30) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(0.4, 8, 0.4), COL.trim)
	decorItem("P_SlopBarrel", "level", 15, CFrame.new(-21.5, 1, 8), Vector3.new(2.2, 3, 2.2), COL.cash)
	decorItem("P_SlopBarrel", "level", 15, CFrame.new(21.5, 1, 16), Vector3.new(2.2, 3, 2.2), COL.cash)
	decorItem("P_Trophy", "rebirth", 1, CFrame.new(0, 1, 30.5) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(2.5, 5, 2.5), COL.gold)
	decorItem("P_MushTree", "rebirth", 3, CFrame.new(-19, 1, 25) * CFrame.Angles(0, math.rad(40), 0), Vector3.new(2, 10, 2), Color3.fromRGB(176, 91, 255))

	-- path from the entrance to the belt
	local toBelt = math.abs(center.Z) - D / 2 - (math.abs(M.mainZ) + M.beltWidth / 2 + 2)
	part({ Name = "Path", Size = Vector3.new(12, 0.2, toBelt), CFrame = cf * CFrame.new(0, 0.1, -D / 2 - toBelt / 2), Color = COL.path, Material = Enum.Material.Plastic, CanCollide = false, Parent = plot })

	plot.PrimaryPart = plot:FindFirstChild("Floor") :: BasePart
	plot.Parent = parent
	return plot
end

-- ---------------------------------------------------------------- belts
local function buildBelt(parent: Instance, lineName: string, z: number, dir: number)
	local belt = Instance.new("Model")
	belt.Name = lineName .. "Line"
	local length = M.beltEndX - M.beltStartX
	local midX = (M.beltStartX + M.beltEndX) / 2
	local top = M.beltY
	local surf = part({
		Name = "BeltSurface",
		Size = Vector3.new(length, 0.4, M.beltWidth),
		CFrame = CFrame.new(midX, top - 0.2, z),
		Color = COL.belt,
		Material = Enum.Material.Rubber,
		Parent = belt,
	})
	surf:SetAttribute("Dir", dir)
	-- chevrons (client scrolls the texture to show motion)
	local tex = Instance.new("Texture")
	tex.Name = "Chevrons"
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = 8
	tex.StudsPerTileV = M.beltWidth
	tex.Texture = Config.Textures.Chevron
	tex.Color3 = if lineName == "Gold" then COL.gold else Color3.fromRGB(123, 227, 90)
	tex.Transparency = 0.15
	tex.Parent = surf
	-- frame tiles
	local tiles = math.floor(length / 8)
	for i = 0, tiles - 1 do
		local x = M.beltStartX + 4 + i * 8
		local seg = prop("P_BeltSegment")
		if seg then
			seg:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(90), 0))
			seg.Name = "Segment"
			seg.Parent = belt
		end
	end
	if not belt:FindFirstChild("Segment") then
		for _, sz in ipairs({ -1, 1 }) do
			part({ Name = "Frame", Size = Vector3.new(length, top + 0.3, 0.8), CFrame = CFrame.new(midX, (top + 0.3) / 2, z + sz * (M.beltWidth / 2 + 0.4)), Color = COL.frame, Parent = belt })
			part({ Name = "Rail", Size = Vector3.new(length, 0.35, 0.5), CFrame = CFrame.new(midX, top + 0.45, z + sz * (M.beltWidth / 2 + 0.4)), Color = if lineName == "Gold" then COL.gold else Color3.fromRGB(255, 201, 60), Parent = belt })
		end
		part({ Name = "Base", Size = Vector3.new(length, top - 0.4, M.beltWidth), CFrame = CFrame.new(midX, (top - 0.4) / 2, z), Color = COL.frame, Parent = belt })
	end
	belt.Parent = parent
	return belt
end

local function buildMachines(parent: Instance)
	-- Goober Gusher at the Main line start, Slop Vat at its end
	local gusher = prop("P_Gusher")
	local vat = prop("P_SlopVat")
	local startX, endX = M.beltStartX, M.beltEndX
	if gusher then
		gusher:PivotTo(CFrame.new(startX - 6, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
		gusher.Name = "GooberGusher"
		gusher.Parent = parent
	else
		local g = Instance.new("Model")
		g.Name = "GooberGusher"
		part({ Name = "Body", Size = Vector3.new(14, 16, 34), CFrame = CFrame.new(startX - 8, 8, 0), Color = COL.frame, Parent = g })
		part({ Name = "Funnel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 14, 14), CFrame = CFrame.new(startX - 8, 19, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(123, 227, 90), Parent = g })
		g.Parent = parent
	end
	if vat then
		vat:PivotTo(CFrame.new(endX + 7, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
		vat.Name = "SlopVat"
		vat.Parent = parent
	else
		local v = Instance.new("Model")
		v.Name = "SlopVat"
		part({ Name = "Tub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 30, 30), CFrame = CFrame.new(endX + 10, 4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = COL.frame, Parent = v })
		part({ Name = "Slop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 27, 27), CFrame = CFrame.new(endX + 10, 7.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = COL.cash, Material = Enum.Material.Neon, Parent = v })
		v.Parent = parent
	end
end

local function buildGoldGate(parent: Instance)
	-- low fence along both sides of the Gold line with a sign; access is
	-- checked by the server on snag (Level >= Gold levelRequired)
	local z = M.goldZ
	local length = M.beltEndX - M.beltStartX
	local midX = (M.beltStartX + M.beltEndX) / 2
	local sign = part({ Name = "GoldSign", Size = Vector3.new(30, 4, 0.6), CFrame = CFrame.new(midX, 9, z + M.beltWidth / 2 + 1.2) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(70, 45, 20), Parent = parent })
	textGui(sign, Enum.NormalId.Front, {
		{ name = "Title", text = "★ GOLD LINE ★", size = 0.6, color = COL.gold },
		{ name = "Sub", text = "Better odds • Unlocks at Level " .. Config.Lines.Gold.levelRequired, size = 0.34, color = Color3.new(1, 1, 1) },
	})
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "GoldSignPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(midX + sx * 14, 4.5, z + M.beltWidth / 2 + 1.2), Color = Color3.fromRGB(70, 45, 20), Parent = parent })
	end
	part({ Name = "MainSignDummy", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(midX, -5, 0), Transparency = 1, CanCollide = false, Parent = parent })
	local mainSign = part({ Name = "MainSign", Size = Vector3.new(30, 4, 0.6), CFrame = CFrame.new(midX, 9, M.mainZ - M.beltWidth / 2 - 1.2), Color = COL.frame, Parent = parent })
	textGui(mainSign, Enum.NormalId.Front, {
		{ name = "Title", text = "THE SLOP LINE", size = 0.6, color = Color3.fromRGB(150, 255, 120) },
		{ name = "Sub", text = "Grab a Goober • Bring it home • Get rich", size = 0.34, color = Color3.new(1, 1, 1) },
	})
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "MainSignPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = CFrame.new(midX + sx * 14, 4.5, M.mainZ - M.beltWidth / 2 - 1.2), Color = COL.frame, Parent = parent })
	end
	-- middle walkway between the two lines
	part({ Name = "MidWalk", Size = Vector3.new(length, 1.2, math.abs(M.goldZ - M.mainZ) - M.beltWidth - 1.6), CFrame = CFrame.new(midX, 0.6, (M.mainZ + M.goldZ) / 2), Color = COL.path, Material = Enum.Material.Plastic, Parent = parent })
end

local function placeProp(parent: Instance, name: string, cf: CFrame, newName: string?)
	local m = prop(name)
	if not m then
		return nil
	end
	m:PivotTo(cf)
	m.Name = newName or name
	m.Parent = parent
	return m
end

local function buildLandmarks(parent: Instance)
	-- Rebirth Shrine beyond the Gusher (west), Chaos Rift beyond the Slop Vat (east)
	local shrineCf = CFrame.new(M.beltStartX - 48, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	local shrine = placeProp(parent, "P_RebirthShrine", shrineCf, "RebirthShrine")
	if not shrine then
		shrine = Instance.new("Model")
		shrine.Name = "RebirthShrine"
		part({ Name = "Dais", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 18, 18), CFrame = CFrame.new(M.beltStartX - 48, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(237, 230, 255), Parent = shrine })
		shrine.Parent = parent
	end
	local sp = part({ Name = "RebirthPrompt", Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(M.beltStartX - 48, 4, 0), Transparency = 1, CanCollide = false, Parent = shrine })
	billboard(sp, "ShrineTag", Vector2.new(12, 3.4), Vector3.new(0, 15, 0), "♻️ REBIRTH SHRINE", Color3.fromRGB(210, 150, 255))
	local rift = placeProp(parent, "P_ChaosRift", CFrame.new(M.beltEndX + 48, 0, 0), "ChaosRift")
	if rift then
		local core = Instance.new("PointLight")
		core.Name = "RiftLight"
		core.Color = Color3.fromRGB(192, 75, 255)
		core.Range = 40
		core.Brightness = 0.5
		core.Parent = rift:FindFirstChild("Glow") or rift:FindFirstChildWhichIsA("BasePart")
		local fx = part({ Name = "RiftCore", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(M.beltEndX + 48, 8, 0), Transparency = 1, CanCollide = false, Parent = rift })
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "RiftSparks"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 61, 165), Color3.fromRGB(192, 75, 255))
		pe.Rate = 4
		pe.Speed = NumberRange.new(3, 8)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Lifetime = NumberRange.new(1, 2)
		pe.LightEmission = 0.8
		pe.Size = NumberSequence.new(1.2, 0)
		pe.Parent = fx
		billboard(fx, "RiftTag", Vector2.new(12, 3.4), Vector3.new(0, 9, 0), "🌀 CHAOS RIFT", Color3.fromRGB(255, 120, 220))
	end
	-- lamp posts lining both sides of the conveyor zone
	for x = M.beltStartX + 12, M.beltEndX - 12, 34 do
		for _, sz in ipairs({ -1, 1 }) do
			placeProp(parent, "P_LampPost", CFrame.new(x, 0, sz * 18) * CFrame.Angles(0, math.rad(sz > 0 and 90 or -90), 0), "Lamp")
		end
	end
	-- meadow dressing behind the bases and at the ends
	local rnd = Random.new(21)
	for i = 1, 14 do
		local side = if i % 2 == 0 then 1 else -1
		local x = rnd:NextNumber(-190, 190)
		local z = side * rnd:NextNumber(112, 140)
		placeProp(parent, if i % 3 == 0 then "P_SlopBarrel" else "P_MushTree", CFrame.new(x, 0, z) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0), "Meadow")
	end
	for _, x in ipairs({ -185, -150, 150, 185 }) do
		for _, z in ipairs({ -40, 40 }) do
			placeProp(parent, "P_MushTree", CFrame.new(x + rnd:NextNumber(-6, 6), 0, z + rnd:NextNumber(-8, 8)) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0), "Meadow")
		end
	end
end

local function buildGround(parent: Instance)
	part({ Name = "Ground", Size = Vector3.new(420, 4, 300), CFrame = CFrame.new(0, -2, 0), Color = COL.ground, Material = Enum.Material.Plastic, Parent = parent })
	-- darker grass bands for depth
	for i, z in ipairs({ -40, 40 }) do
		part({ Name = "GrassBand", Size = Vector3.new(400, 0.1, 14), CFrame = CFrame.new(0, 0.02, z), Color = COL.groundDark, Material = Enum.Material.Plastic, CanCollide = false, Parent = parent })
	end
	-- invisible boundary walls
	for _, w in ipairs({
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, 151) },
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, -151) },
		{ Vector3.new(2, 60, 300), Vector3.new(211, 30, 0) },
		{ Vector3.new(2, 60, 300), Vector3.new(-211, 30, 0) },
	}) do
		part({ Name = "Boundary", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1, CanQuery = false, Parent = parent })
	end
end

function MapBuilder.Lighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future -- plugins may not have permission
	end)
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 100, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 170)
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 35
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.35
	local function ensure(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	local atmo = ensure("Atmosphere", "Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(205, 225, 255)
	atmo.Decay = Color3.fromRGB(150, 120, 200)
	atmo.Glare = 0.2
	atmo.Haze = 1.2
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.6
	local cc = ensure("ColorCorrectionEffect", "Grade")
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	local sky = ensure("Sky", "Sky")
	sky.SunAngularSize = 14
end

function MapBuilder.Build()
	for _, name in ipairs({ "Map", "Plots" }) do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildGround(map)
	buildBelt(map, "Main", M.mainZ, 1)
	buildBelt(map, "Gold", M.goldZ, -1)
	buildMachines(map)
	buildGoldGate(map)
	buildLandmarks(map)

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = workspace
	local i = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, x in ipairs(M.plotXs) do
			i += 1
			local center = Vector3.new(x, 0, side * M.plotZ)
			buildPlot(plots, i, center, Vector3.new(0, 0, -side))
		end
	end

	-- neutral spawn (players are teleported to their base as soon as it is ready)
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Parent = workspace
	end
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.6, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	MapBuilder.Lighting()
	return i
end

return MapBuilder

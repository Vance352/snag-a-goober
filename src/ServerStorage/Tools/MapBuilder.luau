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
local Config = require(ReplicatedStorage.Shared:Clone().Config) -- whole folder: Config requires its siblings
local Halloween = require(ReplicatedStorage.Shared:Clone().Halloween)

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

	-- path from the entrance to the Breach Arena's edge
	local toArena = math.max(1, math.abs(center.Z) - D / 2 - 35.5)
	part({ Name = "Path", Size = Vector3.new(12, 0.2, toArena), CFrame = cf * CFrame.new(0, 0.1, -D / 2 - toArena / 2), Color = COL.path, Material = Enum.Material.Plastic, CanCollide = false, Parent = plot })

	plot.PrimaryPart = plot:FindFirstChild("Floor") :: BasePart
	plot.Parent = parent
	return plot
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
	-- Rebirth Shrine on the north-east side of Champions Plaza (out of the way of
	-- the leaderboards), Chaos Rift in the east market
	local spos = Vector3.new(-139, 0.4, -27)
	local shrineCf = CFrame.lookAt(spos, Vector3.new(-160, 0.4, 0))
	local shrine = placeProp(parent, "P_RebirthShrine", shrineCf, "RebirthShrine")
	if not shrine then
		shrine = Instance.new("Model")
		shrine.Name = "RebirthShrine"
		part({ Name = "Dais", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 18, 18), CFrame = CFrame.new(spos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(237, 230, 255), Parent = shrine })
		shrine.Parent = parent
	end
	local sp = part({ Name = "RebirthPrompt", Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(spos + Vector3.new(0, 4, 0)), Transparency = 1, CanCollide = false, Parent = shrine })
	billboard(sp, "ShrineTag", Vector2.new(12, 3.4), Vector3.new(0, 15, 0), "REBIRTH SHRINE", Color3.fromRGB(210, 150, 255))
	local rift = placeProp(parent, "P_ChaosRift", CFrame.new(164, 0, 0), "ChaosRift")
	if rift then
		local core = Instance.new("PointLight")
		core.Name = "RiftLight"
		core.Color = Color3.fromRGB(192, 75, 255)
		core.Range = 40
		core.Brightness = 0.5
		core.Parent = rift:FindFirstChild("Glow") or rift:FindFirstChildWhichIsA("BasePart")
		local fx = part({ Name = "RiftCore", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(164, 8, 0), Transparency = 1, CanCollide = false, Parent = rift })
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
		billboard(fx, "RiftTag", Vector2.new(12, 3.4), Vector3.new(0, 9, 0), "CHAOS RIFT", Color3.fromRGB(255, 120, 220))
	end
end

-- ============================================================ GOOBER HUB
-- The plaza between the two rows of bases is the Breach Arena, with the
-- Goober Breach in the middle. Champions Plaza (leaderboards + Rebirth
-- Shrine) is to the west, the Goober Mart (game passes), Chaos Rift and
-- Spooky Portal to the east.
local CollectionService = game:GetService("CollectionService")

local HUB = {
	arena = Color3.fromRGB(214, 200, 232),
	arenaDark = Color3.fromRGB(176, 158, 206),
	curb = Color3.fromRGB(110, 84, 160),
	metal = Color3.fromRGB(62, 52, 92),
	metalDark = Color3.fromRGB(40, 32, 62),
	glow = Color3.fromRGB(123, 227, 90),
	gold = Color3.fromRGB(255, 196, 61),
	wood = Color3.fromRGB(120, 78, 50),
	board = Color3.fromRGB(46, 30, 78),
}

local function weldTo(anchor: BasePart, p: BasePart)
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = p
	w.Parent = p
end

local function signBoard(parent: Instance, cf: CFrame, size: Vector3, lines, color: Color3?)
	local b = part({ Name = "Sign", Size = size, CFrame = cf, Color = color or HUB.board, Material = Enum.Material.SmoothPlastic, Parent = parent })
	local gui = textGui(b, Enum.NormalId.Front, lines)
	gui.PixelsPerStud = 30
	return b
end

-- --------------------------------------------------------------- arena
local function buildArena(parent: Instance)
	local a = Instance.new("Model")
	a.Name = "BreachArena"
	a.Parent = parent
	-- arena floor: a rounded rectangle (centre slab + round ends) between the base rows
	part({ Name = "Floor", Size = Vector3.new(196, 0.4, 72), CFrame = CFrame.new(0, 0.2, 0), Color = HUB.arena, Material = Enum.Material.Cobblestone, Parent = a })
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "FloorEnd", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 72, 72), CFrame = CFrame.new(sx * 98, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = HUB.arena, Material = Enum.Material.Cobblestone, Parent = a })
	end
	-- low curb along the long edges (gaps where each base's gate opens onto the arena)
	for _, sz in ipairs({ -1, 1 }) do
		local x = -98
		local gaps = {}
		for _, px in ipairs(M.plotXs) do
			table.insert(gaps, px)
		end
		while x < 98 do
			local x1 = math.min(98, x + 8)
			local mid = (x + x1) / 2
			local blocked = false
			for _, g in ipairs(gaps) do
				if math.abs(mid - g) < 10 then
					blocked = true
				end
			end
			if not blocked then
				part({ Name = "Curb", Size = Vector3.new(x1 - x, 0.9, 1.4), CFrame = CFrame.new(mid, 0.45, sz * 36.3), Color = HUB.curb, Material = Enum.Material.SmoothPlastic, Parent = a })
			end
			x = x1
		end
	end
	-- rune circle around the Breach: two neon rings and spokes
	for _, r in ipairs({ 19, 24 }) do
		local seg = 36
		for i = 0, seg - 1 do
			local ang = i / seg * math.pi * 2
			local len = 2 * math.pi * r / seg + 0.15
			part({ Name = "Rune", Size = Vector3.new(len, 0.06, 0.6), CFrame = CFrame.new(math.cos(ang) * r, 0.43, math.sin(ang) * r) * CFrame.Angles(0, -ang + math.pi / 2, 0),
				Color = HUB.glow, Material = Enum.Material.Neon, CanCollide = false, Parent = a })
		end
	end
	for i = 0, 7 do
		local ang = i / 8 * math.pi * 2 + math.pi / 8
		part({ Name = "Rune", Size = Vector3.new(4.4, 0.06, 0.5), CFrame = CFrame.new(math.cos(ang) * 21.5, 0.43, math.sin(ang) * 21.5) * CFrame.Angles(0, -ang, 0),
			Color = HUB.glow, Material = Enum.Material.Neon, CanCollide = false, Parent = a })
	end
	-- benches and lamps on the arena edge
	for _, x in ipairs({ -56, 0, 56 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local b = Instance.new("Model")
			b.Name = "Bench"
			b.Parent = a
			local cf = CFrame.new(x, 0.4, sz * 33.2) * CFrame.Angles(0, if sz > 0 then math.pi else 0, 0)
			part({ Name = "Seat", Size = Vector3.new(6, 0.5, 1.6), CFrame = cf * CFrame.new(0, 1.3, 0), Color = HUB.wood, Material = Enum.Material.Wood, Parent = b })
			part({ Name = "Back", Size = Vector3.new(6, 1.4, 0.4), CFrame = cf * CFrame.new(0, 2.2, 0.7), Color = HUB.wood, Material = Enum.Material.Wood, Parent = b })
			for _, lx in ipairs({ -2.5, 2.5 }) do
				part({ Name = "Leg", Size = Vector3.new(0.4, 1.1, 1.2), CFrame = cf * CFrame.new(lx, 0.55, 0), Color = HUB.metal, Parent = b })
			end
		end
	end
	for _, x in ipairs({ -84, -28, 28, 84 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local lx = x + (if x > 0 then -14 else 14)
			placeProp(parent, "P_LampPost", CFrame.new(lx, 0.4, sz * 34.5) * CFrame.Angles(0, if sz > 0 then math.pi else 0, 0), "Lamp")
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		placeProp(parent, "P_LampPost", CFrame.new(sx * 130, 0.4, -14), "Lamp")
		placeProp(parent, "P_LampPost", CFrame.new(sx * 130, 0.4, 14), "Lamp")
	end
	return a
end

-- --------------------------------------------------------------- breach
-- The Goober Breach. Named parts the client animates (BreachFx):
--   RingCenter (anchored; the ring segments are welded to it and spin with it),
--   Core (neon ball; grows and glows as it charges), Glow (type-coloured strips),
--   Gather / Sparks particle emitters. A Blender model replaces the stand-in
--   frame when ReplicatedStorage.Assets.Props.P_GooberBreach exists.
local function buildBreach(parent: Instance, name: string, center: Vector3, scale: number, site: string)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Site", site)
	local s = scale
	local frame = prop("P_GooberBreach")
	if frame then
		frame:ScaleTo(s)
		frame:PivotTo(CFrame.new(center))
		frame.Name = "Frame"
		frame.Parent = m
	else
		-- base platform: stacked discs and a lip
		part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6 * s, 26 * s, 26 * s), CFrame = CFrame.new(center + Vector3.new(0, 0.8 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = HUB.metalDark, Material = Enum.Material.DiamondPlate, Parent = m })
		part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2 * s, 20 * s, 20 * s), CFrame = CFrame.new(center + Vector3.new(0, 2.1 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = HUB.metal, Material = Enum.Material.Metal, Parent = m })
		part({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, 20.6 * s, 20.6 * s), CFrame = CFrame.new(center + Vector3.new(0, 1.55 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = HUB.glow, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		-- six curved claws holding the ring up
		for i = 0, 5 do
			local ang = i / 6 * math.pi * 2
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local foot = center + dir * 9.5 * s + Vector3.new(0, 2.6 * s, 0)
			local look = CFrame.lookAt(foot, foot - dir)
			part({ Name = "Claw", Size = Vector3.new(2 * s, 9 * s, 2 * s), CFrame = look * CFrame.new(0, 4 * s, 0) * CFrame.Angles(math.rad(-18), 0, 0), Color = HUB.metal, Material = Enum.Material.Metal, Parent = m })
			part({ Name = "ClawTip", Size = Vector3.new(1.6 * s, 5 * s, 1.6 * s), CFrame = look * CFrame.new(0, 9.4 * s, -2.6 * s) * CFrame.Angles(math.rad(-48), 0, 0), Color = HUB.metal, Material = Enum.Material.Metal, Parent = m })
			part({ Name = "Glow", Size = Vector3.new(0.5 * s, 7 * s, 0.3 * s), CFrame = look * CFrame.new(0, 4 * s, -1.05 * s) * CFrame.Angles(math.rad(-18), 0, 0), Color = HUB.glow, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		end
	end
	-- the spinning ring (always built here so it can be animated)
	local ringY = 12.5 * s
	local rc = part({ Name = "RingCenter", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center + Vector3.new(0, ringY, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = m })
	local ringModel = prop("P_BreachRing")
	if ringModel then
		ringModel:ScaleTo(s)
		ringModel:PivotTo(rc.CFrame)
		ringModel.Name = "Ring"
		for _, d in ipairs(ringModel:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				weldTo(rc, d)
			end
		end
		ringModel.Parent = m
	end
	local segs = if ringModel then 0 else 22
	local R = 7.2 * s
	for i = 0, segs - 1 do
		local ang = i / segs * math.pi * 2
		local seg = part({ Name = "RingSeg", Size = Vector3.new(2 * math.pi * R / segs + 0.1, 1.1 * s, 1.1 * s), CFrame = rc.CFrame * CFrame.new(math.cos(ang) * R, 0, math.sin(ang) * R) * CFrame.Angles(0, -ang + math.pi / 2, 0),
			Color = if i % 2 == 0 then HUB.gold else HUB.metal, Material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Metal, CanCollide = false, CanQuery = false, Parent = m })
		if i % 2 == 0 then
			seg.Name = "Glow"
		end
		weldTo(rc, seg)
	end
	-- core
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(5 * s, 5 * s, 5 * s), CFrame = CFrame.new(center + Vector3.new(0, ringY, 0)), Color = HUB.glow, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false, Parent = m })
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1
	light.Color = HUB.glow
	light.Shadows = false
	light.Parent = core
	local att = Instance.new("Attachment")
	att.Parent = core
	local gather = Instance.new("ParticleEmitter")
	gather.Name = "Gather"
	gather.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	gather.LightEmission = 1
	gather.Size = NumberSequence.new(0.9 * s, 0)
	gather.Lifetime = NumberRange.new(0.5, 0.9)
	gather.Speed = NumberRange.new(4, 9)
	gather.SpreadAngle = Vector2.new(180, 180)
	gather.Rate = 25
	gather.Enabled = false
	gather.Parent = att
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.4 * s, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(20, 34)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 40
	sparks.Enabled = false
	sparks.Parent = att
	m.PrimaryPart = rc
	CollectionService:AddTag(m, "BreachSite")
	m.Parent = parent
	return m
end
MapBuilder.BuildBreach = buildBreach

-- ------------------------------------------------- Champions Plaza (west)
local LB_CATEGORIES = require(ReplicatedStorage.Shared:Clone().Leaderboards).Categories

local function leaderboardBoard(parent: Instance, cf: CFrame, cat)
	local m = Instance.new("Model")
	m.Name = "Leaderboard_" .. cat.key
	m:SetAttribute("Category", cat.key)
	local W, H = 16, 22 -- (big rows: readable from across the plaza)
	-- frame: posts, top crest
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = Vector3.new(1, H + 3, 1), CFrame = cf * CFrame.new(sx * (W / 2 + 0.5), (H + 3) / 2, 0), Color = HUB.metalDark, Material = Enum.Material.Metal, Parent = m })
	end
	part({ Name = "Crest", Size = Vector3.new(W + 2.4, 1.6, 1.4), CFrame = cf * CFrame.new(0, H + 3, 0), Color = cat.color, Material = Enum.Material.Neon, Parent = m })
	local board = part({ Name = "Board", Size = Vector3.new(W, H, 0.6), CFrame = cf * CFrame.new(0, 2.5 + H / 2, 0), Color = HUB.board, Parent = m })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	local function lbl(parent2, name, pos, size, text, color, align)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = pos
		t.Size = size
		t.Text = text
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = color
		t.TextXAlignment = align or Enum.TextXAlignment.Center
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(24, 14, 40)
		s.Parent = t
		t.Parent = parent2
		return t
	end
	lbl(gui, "Title", UDim2.fromScale(0.04, 0.015), UDim2.fromScale(0.92, 0.085), cat.title, cat.color)
	lbl(gui, "Sub", UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.04), cat.stat, Color3.fromRGB(220, 205, 245))
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.04, 0.155)
	rows.Size = UDim2.fromScale(0.92, 0.78)
	rows.Parent = gui
	local medal = { Color3.fromRGB(255, 201, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }
	for i = 1, 10 do
		local r = Instance.new("Frame")
		r.Name = "Row" .. i
		r.BackgroundColor3 = if i <= 3 then Color3.fromRGB(70, 48, 110) else Color3.fromRGB(58, 40, 92)
		r.Position = UDim2.fromScale(0, (i - 1) / 10)
		r.Size = UDim2.new(1, 0, 0.1, -6)
		r.Visible = false
		r.Parent = rows
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.25, 0)
		c.Parent = r
		local rank = lbl(r, "Rank", UDim2.fromScale(0.01, 0.1), UDim2.fromScale(0.1, 0.8), tostring(i), medal[i] or Color3.new(1, 1, 1))
		local _ = rank
		local av = Instance.new("ImageLabel")
		av.Name = "Avatar"
		av.BackgroundTransparency = 1
		av.Position = UDim2.fromScale(0.12, 0.05)
		av.Size = UDim2.fromScale(0.11, 0.9)
		av.SizeConstraint = Enum.SizeConstraint.RelativeYY
		av.Parent = r
		lbl(r, "Name_", UDim2.fromScale(0.25, 0.12), UDim2.fromScale(0.45, 0.76), "", Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
		lbl(r, "Value", UDim2.fromScale(0.68, 0.12), UDim2.fromScale(0.3, 0.76), "", medal[i] or Color3.fromRGB(255, 233, 120), Enum.TextXAlignment.Right)
	end
	lbl(gui, "Status", UDim2.fromScale(0.04, 0.94), UDim2.fromScale(0.92, 0.045), "Loading rankings...", Color3.fromRGB(200, 185, 230))
	local empty = lbl(gui, "Empty", UDim2.fromScale(0.1, 0.4), UDim2.fromScale(0.8, 0.1), "No rankings yet - be the first!", Color3.fromRGB(220, 205, 245))
	empty.Visible = false
	gui.Parent = board
	-- back face: a plain back panel so it doesn't look unfinished from behind
	part({ Name = "Back", Size = Vector3.new(W + 0.6, H + 0.6, 0.3), CFrame = cf * CFrame.new(0, 2.5 + H / 2, 0.45), Color = HUB.metalDark, Parent = m })
	CollectionService:AddTag(m, "LeaderboardBoard")
	m.Parent = parent
	return m
end

local function buildChampionsPlaza(parent: Instance)
	local p = Instance.new("Model")
	p.Name = "ChampionsPlaza"
	p.Parent = parent
	local c = Vector3.new(-160, 0, 0)
	part({ Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 74, 74), CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = HUB.arenaDark, Material = Enum.Material.Cobblestone, Parent = p })
	part({ Name = "Walk", Size = Vector3.new(30, 0.4, 14), CFrame = CFrame.new(-120, 0.2, 0), Color = HUB.arenaDark, Material = Enum.Material.Cobblestone, Parent = p })
	-- five boards on an arc around the west half, all facing the plaza centre;
	-- nothing stands between them and the entrance (the shrine is off to the side)
	local n = #LB_CATEGORIES
	for i, cat in ipairs(LB_CATEGORIES) do
		local ang = math.rad(180 + (i - (n + 1) / 2) * 34)
		local pos = c + Vector3.new(math.cos(ang) * 33, 0, math.sin(ang) * 33)
		leaderboardBoard(p, CFrame.lookAt(pos, Vector3.new(c.X + 14, 0, c.Z)), cat)
	end
	-- a medal mosaic in the middle of the plaza (flat: it hides nothing)
	for i, col in ipairs({ HUB.gold, Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }) do
		part({ Name = "Medal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 16 - i * 4, 16 - i * 4), CFrame = CFrame.new(c + Vector3.new(0, 0.42 + i * 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = col, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = p })
	end
	-- (high enough that it doesn't hide the board titles from a player's camera)
	signBoard(p, CFrame.new(-128, 21, 0) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(21, 3.8, 0.5), {
		{ name = "Title", text = "CHAMPIONS PLAZA", size = 0.58, color = HUB.gold },
		{ name = "Sub", text = "Leaderboards  •  Rebirth Shrine", size = 0.3, color = Color3.new(1, 1, 1) },
	})
	for _, sz in ipairs({ -1, 1 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.8, 21, 0.8), CFrame = CFrame.new(-128, 10.5, sz * 9.9), Color = HUB.metalDark, Parent = p })
	end
end

-- ---------------------------------------------------- Goober Mart (east)
local function buildMart(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "GooberMart"
	m.Parent = parent
	local stall = prop("P_MartStall")
	local cf = CFrame.lookAt(Vector3.new(152, 0, 34), Vector3.new(100, 0, 34))
	if stall then
		stall:PivotTo(cf)
		stall.Parent = m
	else
		part({ Name = "Counter", Size = Vector3.new(16, 3.6, 4), CFrame = cf * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(255, 196, 61), Material = Enum.Material.SmoothPlastic, Parent = m })
		part({ Name = "CounterTop", Size = Vector3.new(16.6, 0.5, 4.6), CFrame = cf * CFrame.new(0, 3.85, 0), Color = Color3.fromRGB(255, 240, 200), Parent = m })
		for _, sx in ipairs({ -1, 1 }) do
			part({ Name = "Post", Size = Vector3.new(0.9, 11, 0.9), CFrame = cf * CFrame.new(sx * 7.6, 5.5, 2.2), Color = HUB.curb, Parent = m })
		end
		for i = 0, 5 do
			part({ Name = "Awning", Size = Vector3.new(16 / 6 + 0.02, 0.5, 8), CFrame = cf * CFrame.new(-8 + 16 / 12 + i * 16 / 6, 11.2, 0.6) * CFrame.Angles(math.rad(-14), 0, 0),
				Color = if i % 2 == 0 then Color3.fromRGB(255, 95, 162) else Color3.fromRGB(255, 255, 255), Parent = m })
		end
	end
	signBoard(m, cf * CFrame.new(0, 13.6, 2.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(15, 3.4, 0.5), {
		{ name = "Title", text = "GOOBER MART", size = 0.6, color = Color3.fromRGB(255, 196, 61) },
		{ name = "Sub", text = "Game passes and Slop bundles", size = 0.32, color = Color3.new(1, 1, 1) },
	})
	local trigger = part({ Name = "MartPrompt", Size = Vector3.new(6, 5, 6), CFrame = cf * CFrame.new(0, 2.5, -4), Transparency = 1, CanCollide = false, Parent = m })
	trigger:SetAttribute("OpenPanel", "Shop")
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Browse"
	pr.ObjectText = "Goober Mart"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = trigger
	-- a few display Goober stands on the counter side
	for _, sx in ipairs({ -1, 1 }) do
		placeProp(m, "P_Stand", cf * CFrame.new(sx * 11, 0, -1), "DisplayStand")
	end
end

-- ---------------------------------------------------- east market (paths)
-- Paving and paths so the Chaos Rift, the Goober Mart and the Spooky Portal sit
-- in a market square joined to the arena, instead of on bare grass.
local function buildEastMarket(parent: Instance)
	local e = Instance.new("Model")
	e.Name = "EastMarket"
	e.Parent = parent
	local function pave(name, size, cf)
		return part({ Name = name, Size = size, CFrame = cf, Color = HUB.arenaDark, Material = Enum.Material.Cobblestone, Parent = e })
	end
	local function disc(name, pos: Vector3, d: number)
		return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.38, d, d), CFrame = CFrame.new(pos.X, 0.19, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = HUB.arenaDark, Material = Enum.Material.Cobblestone, Parent = e })
	end
	local function path(name, a: Vector3, b: Vector3, w: number)
		local mid = (a + b) / 2
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		return pave(name, Vector3.new(w, 0.38, len), CFrame.lookAt(Vector3.new(mid.X, 0.19, mid.Z), Vector3.new(b.X, 0.19, b.Z)))
	end
	local rift, mart, portal = Vector3.new(164, 0, 0), Vector3.new(146, 0, 34), Halloween.MainPortal.pos
	disc("Square", rift, 46)
	disc("MartPad", mart, 34)
	disc("PortalPad", portal, 30)
	path("Path", Vector3.new(128, 0, 0), rift, 14)
	path("Path", rift, mart, 12)
	path("Path", rift, portal, 12)
	-- lamps and planters along the edges
	for _, a in ipairs({ 30, 150, 210, 330 }) do
		local r = math.rad(a)
		placeProp(parent, "P_LampPost", CFrame.new(rift.X + math.cos(r) * 21, 0.4, rift.Z + math.sin(r) * 21), "Lamp")
	end
	for _, pos in ipairs({ Vector3.new(146, 0, -24), Vector3.new(160, 0, 24), Vector3.new(134, 0, -40) }) do
		placeProp(parent, "P_LampPost", CFrame.new(pos.X, 0.4, pos.Z), "Lamp")
	end
	for i = 0, 5 do
		local r = math.rad(60 * i + 15)
		local pos = mart + Vector3.new(math.cos(r) * 17.5, 0, math.sin(r) * 17.5)
		if pos.X > mart.X - 6 then -- (the side facing away from the counter)
			part({ Name = "Planter", Size = Vector3.new(3, 1.4, 3), CFrame = CFrame.new(pos.X, 0.9, pos.Z), Color = HUB.wood, Material = Enum.Material.Wood, Parent = e })
			part({ Name = "Shrub", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), CFrame = CFrame.new(pos.X, 2.6, pos.Z), Color = Color3.fromRGB(95, 180, 70), Material = Enum.Material.Grass, Parent = e })
		end
	end
end

-- ------------------------------------------------------------- scenery
local function buildScenery(parent: Instance)
	local s = Instance.new("Folder")
	s.Name = "Scenery"
	s.Parent = parent
	local rnd = Random.new(42)
	-- rolling hills around the edge (outside the boundary walls) for a skyline
	for i = 0, 27 do
		local t = i / 28
		local x, z
		if t < 0.25 then
			x, z = -230 + t * 4 * 460, -175
		elseif t < 0.5 then
			x, z = 230, -175 + (t - 0.25) * 4 * 350
		elseif t < 0.75 then
			x, z = 230 - (t - 0.5) * 4 * 460, 175
		else
			x, z = -230, 175 - (t - 0.75) * 4 * 350
		end
		local r = rnd:NextNumber(26, 44)
		part({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 2, r * 2), CFrame = CFrame.new(x + rnd:NextNumber(-10, 10), -r * 0.55, z + rnd:NextNumber(-10, 10)),
			Color = if i % 2 == 0 then Color3.fromRGB(104, 196, 104) else Color3.fromRGB(92, 182, 98), Material = Enum.Material.Grass, CanCollide = false, CastShadow = false, Parent = s })
	end
	-- distant mountains (silhouettes in the haze)
	for i = 0, 9 do
		local ang = i / 10 * math.pi * 2 + 0.3
		local d = rnd:NextNumber(950, 1100)
		local h = rnd:NextNumber(120, 190)
		-- skip the north, where Halloween Island floats
		if math.abs(math.cos(ang)) > 0.35 or math.sin(ang) < 0 then
			part({ Name = "Mountain", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 2.4, h * 2.4, h * 2.4), CFrame = CFrame.new(math.cos(ang) * d, -h * 0.75, math.sin(ang) * d),
				Color = Color3.fromRGB(176, 186, 226), Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false, Parent = s })
		end
	end
	-- tree clusters behind the bases and in the corners
	local spots = {}
	for _, x in ipairs({ -190, -150, -110, -56, 0, 56, 110, 150, 190 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(spots, { x + rnd:NextNumber(-8, 8), sz * rnd:NextNumber(118, 140) })
		end
	end
	for _, c in ipairs({ { -190, -40 }, { -190, 40 }, { 190, -95 }, { 190, 95 }, { -125, -70 }, { -125, 70 }, { 125, 95 } }) do
		table.insert(spots, c)
	end
	for _, sp in ipairs(spots) do
		local n = rnd:NextInteger(1, 3)
		for k = 1, n do
			placeProp(s, if rnd:NextNumber() < 0.75 then "P_MushTree" else "P_SlopBarrel", CFrame.new(sp[1] + rnd:NextNumber(-6, 6), 0, sp[2] + rnd:NextNumber(-6, 6)) * CFrame.Angles(0, rnd:NextNumber(0, 6.28), 0), "Tree")
			local _ = k
		end
	end
	-- flower beds along the arena ends
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local c = Vector3.new(sx * 118, 0.3, sz * 26)
			part({ Name = "Bed", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9), CFrame = CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 84, 60), Material = Enum.Material.Ground, Parent = s })
			for f = 0, 6 do
				local a = f / 7 * math.pi * 2
				part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 2.6, 0.9, math.sin(a) * 2.6)),
					Color = ({ Color3.fromRGB(255, 95, 162), Color3.fromRGB(255, 201, 60), Color3.fromRGB(176, 120, 255) })[f % 3 + 1], CanCollide = false, Parent = s })
			end
		end
	end
	-- direction signpost at the arena ends
	for _, sx in ipairs({ -1, 1 }) do
		local cf = CFrame.new(sx * 112, 0.4, -36)
		part({ Name = "SignPost", Size = Vector3.new(0.8, 10, 0.8), CFrame = cf * CFrame.new(0, 5, 0), Color = HUB.wood, Material = Enum.Material.Wood, Parent = s })
		signBoard(s, cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, if sx > 0 then math.rad(-90) else math.rad(90), 0), Vector3.new(11, 2.4, 0.4), {
			{ name = "Title", text = if sx > 0 then "GOOBER MART  •  SPOOKY PORTAL" else "CHAMPIONS PLAZA  •  REBIRTH", size = 0.8, color = Color3.new(1, 1, 1) },
		}, HUB.wood)
	end
end

local function buildGround(parent: Instance)
	part({ Name = "Ground", Size = Vector3.new(420, 4, 300), CFrame = CFrame.new(0, -2, 0), Color = COL.ground, Material = Enum.Material.Grass, Parent = parent })
	-- the grass beyond the play area, so the edge of the world is hills, not a cliff
	part({ Name = "OuterGround", Size = Vector3.new(2400, 4, 2400), CFrame = CFrame.new(0, -2.05, 0), Color = COL.ground, Material = Enum.Material.Grass, CastShadow = false, Parent = parent })
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
	buildArena(map)
	buildBreach(map, "GooberBreach", Vector3.new(0, 0.4, 0), 1.35, "Central")
	buildLandmarks(map)
	buildChampionsPlaza(map)
	buildMart(map)
	buildEastMarket(map)
	buildScenery(map)


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
	spawn.CFrame = CFrame.new(0, 0.6, -28)
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

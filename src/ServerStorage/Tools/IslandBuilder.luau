--[[
	IslandBuilder - edit-time tool that (re)builds Halloween Island and the
	mainland Spooky Portal from Shared/Halloween + the Blender props in
	ReplicatedStorage.Assets.Props. Run from the command bar / MCP:
	    require(game.ServerStorage.Tools.IslandBuilder:Clone()).Build()
	Everything goes in workspace.HalloweenIsland (rebuilt from scratch each run);
	the main map is not touched.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- fresh copy of the whole Shared folder (Config requires its siblings, and
-- Studio's module cache would otherwise serve stale versions)
local Shared = ReplicatedStorage.Shared:Clone()
local Config = require(Shared.Config)
local Halloween = require(Shared.Halloween)

local IslandBuilder = {}
local O = Halloween.Origin
local at = Halloween.At
local BELT_Y = Config.Map.beltY

local COL = {
	ground = Color3.fromRGB(58, 40, 66),
	village = Color3.fromRGB(76, 60, 70),
	path = Color3.fromRGB(118, 78, 50),
	pumpkin = Color3.fromRGB(86, 56, 40),
	forest = Color3.fromRGB(34, 56, 48),
	graveyard = Color3.fromRGB(78, 76, 92),
	castle = Color3.fromRGB(62, 50, 82),
	belt = Color3.fromRGB(36, 30, 46),
	rail = Color3.fromRGB(255, 138, 31),
	stone = Color3.fromRGB(74, 68, 88),
	booth = Color3.fromRGB(110, 60, 150),
	roof = Color3.fromRGB(255, 120, 30),
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
	local t = ReplicatedStorage.Assets.Props:FindFirstChild(name)
	if not t then
		warn("[IslandBuilder] missing prop template " .. name)
		return nil
	end
	local c = t:Clone()
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return c
end

-- place a prop with its front (-Z) facing `facing`, optionally scaled
local function place(parent: Instance, name: string, pos: Vector3, facing: Vector3?, scale: number?, newName: string?): Model?
	local m = prop(name)
	if not m then
		return nil
	end
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	local f = facing or Vector3.new(0, 0, -1)
	m:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(f.X, 0, f.Z)))
	m.Name = newName or name
	m.Parent = parent
	return m
end

local function sign(parent: Instance, cf: CFrame, size: Vector3, lines, color: Color3?)
	local board = part({ Name = "Sign", Size = size, CFrame = cf, Color = color or Color3.fromRGB(40, 24, 56), Material = Enum.Material.Wood, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for i, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.95, l[2])
		t.Text = l[1]
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = l[3] or Color3.new(1, 1, 1)
		t.LayoutOrder = i
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(20, 10, 30)
		s.Parent = t
		t.Parent = gui
	end
	gui.Parent = board
	return board
end

local function light(p: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.6
	l.Shadows = false
	l.Parent = p
end

-- give every Glow/Window/Flame part of a placed prop a light (lanterns etc.)
local function lightUp(m: Instance?, color: Color3, range: number)
	if not m then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Glow" or d.Name == "Window" or d.Name == "Flame") then
			light(d, color, range)
			return
		end
	end
end

-- -------------------------------------------------------------- ground
local function buildGround(root: Instance)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = root
	local size = Halloween.Size
	part({ Name = "Island", Size = Vector3.new(size.X + 20, 6, size.Y + 20), CFrame = CFrame.new(O.X, O.Y - 3, O.Z), Color = COL.ground, Material = Enum.Material.Grass, Parent = g })
	-- cliff skirt so the island reads as an island from the arrival
	part({ Name = "Cliff", Size = Vector3.new(size.X + 30, 40, size.Y + 30), CFrame = CFrame.new(O.X, O.Y - 26.05, O.Z), Color = Color3.fromRGB(40, 28, 46), Material = Enum.Material.Rock, Parent = g })
	for _, a in ipairs(Halloween.Areas) do
		local col = ({ Village = COL.village, Pumpkin = COL.pumpkin, Forest = COL.forest, Graveyard = COL.graveyard, Castle = COL.castle })[a.key]
		local mat = ({ Village = Enum.Material.Cobblestone, Pumpkin = Enum.Material.Ground, Forest = Enum.Material.Grass, Graveyard = Enum.Material.Slate, Castle = Enum.Material.Cobblestone })[a.key]
		local c = (a.min + a.max) / 2
		local sz = a.max - a.min
		part({ Name = a.key .. "Floor", Size = Vector3.new(math.abs(sz.X) - 2, 0.2, math.abs(sz.Z) - 2), CFrame = CFrame.new(c.X, O.Y + 0.1, c.Z), Color = col, Material = mat, Parent = g })
	end
	-- paths: arrival -> hub, hub -> each gate
	local function path(a: Vector3, b: Vector3, w: number)
		local mid = (a + b) / 2
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		part({ Name = "Path", Size = Vector3.new(w, 0.25, len + w), CFrame = CFrame.lookAt(Vector3.new(mid.X, O.Y + 0.22, mid.Z), Vector3.new(b.X, O.Y + 0.22, b.Z)), Color = COL.path, Material = Enum.Material.Ground, Parent = g })
	end
	path(at(0, -140), at(0, 10), 12)
	path(at(-70, -60), at(70, -60), 10)
	path(at(-70, 70), at(70, 70), 10)
	path(at(0, 10), at(0, 140), 10)
	-- invisible boundary
	local bx, bz = size.X / 2 + 8, size.Y / 2 + 8
	for _, w in ipairs({
		{ Vector3.new(2, 50, size.Y + 20), Vector3.new(O.X - bx, 25, O.Z) },
		{ Vector3.new(2, 50, size.Y + 20), Vector3.new(O.X + bx, 25, O.Z) },
		{ Vector3.new(size.X + 20, 50, 2), Vector3.new(O.X, 25, O.Z - bz) },
		{ Vector3.new(size.X + 20, 50, 2), Vector3.new(O.X, 25, O.Z + bz) },
	}) do
		part({ Name = "Boundary", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1, CanQuery = false, Parent = g })
	end
end

-- ------------------------------------------------------------- fences
local function fenceRun(root: Instance, a: Vector3, b: Vector3, gaps: { { number } }?)
	-- iron fence segments (8 studs) from a to b along one axis, with gaps
	-- (gap = { centre, halfWidth } measured along the run)
	local f = Instance.new("Folder")
	f.Name = "Fence"
	f.Parent = root
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = dir.Magnitude
	local u = dir.Unit
	local n = math.floor(len / 8)
	for i = 0, n - 1 do
		local t = (i + 0.5) * 8
		local skip = false
		for _, gp in ipairs(gaps or {}) do
			if math.abs(t - gp[1]) < gp[2] + 4 then
				skip = true
			end
		end
		if not skip then
			local pos = a + u * t
			local m = place(f, "P_IronFence", Vector3.new(pos.X, O.Y, pos.Z), Vector3.new(-u.Z, 0, u.X))
			if not m then
				part({ Name = "Rail", Size = Vector3.new(8, 4, 0.4), CFrame = CFrame.lookAt(pos + Vector3.new(0, 2, 0), pos + Vector3.new(0, 2, 0) + Vector3.new(-u.Z, 0, u.X)), Color = Color3.fromRGB(30, 26, 38), Parent = f })
			end
			-- solid invisible collider (fence meshes are see-through)
			part({ Name = "Collider", Size = Vector3.new(8, 8, 0.6), CFrame = CFrame.lookAt(Vector3.new(pos.X, O.Y + 4, pos.Z), Vector3.new(pos.X, O.Y + 4, pos.Z) + Vector3.new(-u.Z, 0, u.X)), Transparency = 1, CanQuery = false, Parent = f })
		end
	end
end

local function gate(root: Instance, area, facingHub: Vector3)
	local g = Instance.new("Model")
	g.Name = area.key .. "Gate"
	g.Parent = root
	local p = area.gate
	local side = Vector3.new(-facingHub.Z, 0, facingHub.X)
	for _, s in ipairs({ -1, 1 }) do
		local pp = p + side * 9 * s
		part({ Name = "Pillar", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(pp.X, O.Y + 7, pp.Z), Color = COL.stone, Material = Enum.Material.Slate, Parent = g })
		part({ Name = "Cap", Size = Vector3.new(3.6, 1, 3.6), CFrame = CFrame.new(pp.X, O.Y + 14.5, pp.Z), Color = Color3.fromRGB(48, 42, 60), Parent = g })
		place(g, "P_Pumpkin", Vector3.new(pp.X, O.Y + 15, pp.Z), facingHub, 0.55, "CapPumpkin")
	end
	part({ Name = "Lintel", Size = Vector3.new(21, 2, 3), CFrame = CFrame.lookAt(Vector3.new(p.X, O.Y + 13, p.Z), Vector3.new(p.X, O.Y + 13, p.Z) + facingHub), Color = COL.stone, Material = Enum.Material.Slate, Parent = g })
	local locked = area.level > 1
	sign(g, CFrame.lookAt(Vector3.new(p.X, O.Y + 17.5, p.Z) + facingHub * 0.5, Vector3.new(p.X, O.Y + 17.5, p.Z) + facingHub * 2), Vector3.new(18, 5, 0.6), {
		{ string.upper(area.name), 0.55, area.color },
		{ if locked then ("Unlocks at Level %d"):format(area.level) else "Open to everyone", 0.35, Color3.fromRGB(255, 230, 160) },
	})
	if locked then
		-- the barrier: solid for everyone on the server; each client switches it
		-- off locally once the player reaches the level (and the server moves
		-- under-level players back out anyway)
		local barrier = part({ Name = "GateBarrier", Size = Vector3.new(15, 12, 1), CFrame = CFrame.lookAt(Vector3.new(p.X, O.Y + 6, p.Z), Vector3.new(p.X, O.Y + 6, p.Z) + facingHub),
			Color = area.color, Material = Enum.Material.ForceField, Transparency = 0.2, CanQuery = false, Parent = g })
		barrier:SetAttribute("Level", area.level)
		barrier:SetAttribute("Area", area.key)
		CollectionService:AddTag(barrier, "GateBarrier") -- tags survive streaming
	end
	return g
end

-- -------------------------------------------------------------- belts
local function belt(root: Instance, lineName: string, line)
	local m = Instance.new("Model")
	m.Name = lineName .. "Line"
	m.Parent = root
	local len = math.abs(line.endX - line.startX)
	local midX = (line.startX + line.endX) / 2
	local dir = if line.endX > line.startX then 1 else -1
	local surf = part({ Name = "BeltSurface", Size = Vector3.new(len + 6, 0.4, 12), CFrame = CFrame.new(midX, BELT_Y - 0.2, line.z), Color = COL.belt, Material = Enum.Material.Rubber, Parent = m })
	if dir < 0 then
		surf.CFrame *= CFrame.Angles(0, math.pi, 0)
	end
	surf:SetAttribute("Dir", 1)
	local tex = Instance.new("Texture")
	tex.Name = "Chevrons"
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = 8
	tex.StudsPerTileV = 12
	tex.Texture = Config.Textures.Chevron
	tex.Color3 = Color3.fromRGB(255, 150, 40)
	tex.Transparency = 0.15
	tex.Parent = surf
	tex:SetAttribute("Line", lineName)
	CollectionService:AddTag(tex, "BeltChevrons")
	part({ Name = "Base", Size = Vector3.new(len + 6, BELT_Y - 0.4, 12), CFrame = CFrame.new(midX, (BELT_Y - 0.4) / 2, line.z), Color = Color3.fromRGB(44, 30, 60), Parent = m })
	for _, sz in ipairs({ -1, 1 }) do
		part({ Name = "Rail", Size = Vector3.new(len + 6, 0.6, 0.6), CFrame = CFrame.new(midX, BELT_Y + 0.3, line.z + sz * 6.3), Color = COL.rail, Material = Enum.Material.Neon, Parent = m })
	end
	-- the cauldron that brews Goobers at the start, a pit at the end
	local cauldron = place(m, "P_Cauldron", Vector3.new(line.startX - dir * 9, O.Y, line.z), Vector3.new(dir, 0, 0), 0.9, "Cauldron")
	lightUp(cauldron, Color3.fromRGB(140, 255, 110), 18)
	part({ Name = "Pit", Size = Vector3.new(6, 0.3, 11), CFrame = CFrame.new(line.endX + dir * 3, BELT_Y - 0.05, line.z), Color = Color3.fromRGB(10, 6, 14), Material = Enum.Material.Neon, Parent = m })
	-- belt sign with the odds
	local area = Halloween.AreaByKey[line.area]
	local lines = { { string.upper(area.name) .. " BELT", 0.42, area.color } }
	local odds = {}
	for _, r in ipairs(Config.RarityOrder) do
		if (line.weights[r] or 0) > 0 then
			table.insert(odds, ("%s %s%%"):format(r, tostring(line.weights[r])))
		end
	end
	table.insert(lines, { table.concat(odds, "  •  "), 0.3, Color3.fromRGB(255, 230, 170) })
	local sp = Vector3.new(midX, O.Y + 9, line.z + 11)
	sign(m, CFrame.lookAt(sp, sp + Vector3.new(0, 0, if line.z > O.Z then -1 else 1)), Vector3.new(34, 5.5, 0.6), lines)
	return m
end

-- ----------------------------------------------------------- booths
local function booth(root: Instance, name: string, pos: Vector3, facing: Vector3, title: string, sub: string, color: Color3, promptText: string)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	local cf = CFrame.lookAt(pos, pos + facing)
	part({ Name = "Counter", Size = Vector3.new(12, 3.5, 4), CFrame = cf * CFrame.new(0, 1.75, 0), Color = COL.booth, Material = Enum.Material.Wood, Parent = m })
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(sx * 5.6, 4.5, 1.6), Color = Color3.fromRGB(60, 36, 24), Material = Enum.Material.Wood, Parent = m })
	end
	part({ Name = "Roof", Size = Vector3.new(14, 0.8, 7), CFrame = cf * CFrame.new(0, 9.3, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = color, Parent = m })
	sign(m, cf * CFrame.new(0, 7.2, -0.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(11, 3, 0.4), {
		{ title, 0.55, Color3.new(1, 1, 1) },
		{ sub, 0.35, Color3.fromRGB(255, 230, 160) },
	}, color)
	local trigger = part({ Name = "PromptPart", Size = Vector3.new(4, 4, 4), CFrame = cf * CFrame.new(0, 3, -3), Transparency = 1, CanCollide = false, Parent = m })
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = promptText
	pr.ObjectText = title
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Parent = trigger
	-- decorative pumpkins on the counter
	for _, sx in ipairs({ -4, 4 }) do
		place(m, "P_Pumpkin", (cf * CFrame.new(sx, 3.5, 0)).Position, facing, 0.45)
	end
	return m
end

-- ------------------------------------------------------------ portals
local function portal(parent: Instance, name: string, pos: Vector3, facing: Vector3, dest: string, title: string, scale: number)
	local m = place(parent, "P_SpookyPortal", pos, facing, scale, name)
	if not m then
		return nil
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Swirl" then
			d.CanCollide = false
			d.CanQuery = false
			light(d, Color3.fromRGB(190, 90, 255), 24, 2.4)
		elseif d:IsA("BasePart") and d.Name == "Glow" then
			d.CanCollide = false
		end
	end
	local trigger = part({ Name = "PortalTrigger", Size = Vector3.new(7, 10, 3), CFrame = CFrame.lookAt(pos + Vector3.new(0, 6, 0), pos + Vector3.new(0, 6, 0) + facing), Transparency = 1, CanCollide = false, Parent = m })
	trigger:SetAttribute("Dest", dest)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = if dest == "PortalIn" then "Travel" else "Go back"
	pr.ObjectText = title
	pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = trigger
	local _, size = m:GetBoundingBox()
	local sp = pos + facing * 1.2 + Vector3.new(0, size.Y + 2.4, 0)
	sign(m, CFrame.lookAt(sp, sp + facing), Vector3.new(16, 3.6, 0.5), {
		{ title, 0.6, Color3.fromRGB(255, 170, 60) },
		{ if dest == "PortalIn" then "Halloween Island - event!" else "Back to Goober Town", 0.35, Color3.new(1, 1, 1) },
	})
	return m
end

-- ---------------------------------------------------------- scenery
local function scatter(parent: Instance, name: string, list: { { number } }, facing: Vector3?, scaleRange: { number }?)
	local rng = Random.new(#name * 31 + #list)
	for _, xz in ipairs(list) do
		local s = if scaleRange then rng:NextNumber(scaleRange[1], scaleRange[2]) else 1
		local f = facing or Vector3.new(math.cos(rng:NextNumber(0, 6.28)), 0, math.sin(rng:NextNumber(0, 6.28)))
		place(parent, name, at(xz[1], xz[2]), f, s)
	end
end

local function grid(x0: number, z0: number, x1: number, z1: number, step: number, jitter: number, seed: number, keepOut: ((number, number) -> boolean)?)
	local rng = Random.new(seed)
	local out = {}
	local x = x0
	while x <= x1 do
		local z = z0
		while z <= z1 do
			local px, pz = x + rng:NextNumber(-jitter, jitter), z + rng:NextNumber(-jitter, jitter)
			if not keepOut or not keepOut(px, pz) then
				table.insert(out, { px, pz })
			end
			z += step
		end
		x += step
	end
	return out
end

local function nearBelt(px: number, pz: number): boolean
	for _, l in pairs(Halloween.Lines) do
		local lx0, lx1 = math.min(l.startX, l.endX) - O.X - 18, math.max(l.startX, l.endX) - O.X + 18
		if px > lx0 and px < lx1 and math.abs(pz - (l.z - O.Z)) < 16 then
			return true
		end
	end
	return false
end

local function buildScenery(root: Instance)
	local s = Instance.new("Folder")
	s.Name = "Scenery"
	s.Parent = root
	local up = Vector3.new(0, 0, 1)
	-- village
	local gp = place(s, "P_GreatPumpkin", at(0, 22), Vector3.new(0, 0, -1), 1.0, "GreatPumpkin")
	lightUp(gp, Color3.fromRGB(255, 170, 60), 40)
	for _, h in ipairs({ { -48, -105, 1 }, { 48, -105, -1 }, { -50, 100, 1 }, { 50, 100, -1 } }) do
		place(s, "P_HauntedHouse", at(h[1], h[2]), Vector3.new(h[3], 0, 0), 0.9)
	end
	place(s, "P_Crypt", at(0, 128), Vector3.new(0, 0, -1), 1.0)
	for _, z in ipairs({ -128, -100, -72, -44, -16 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local m = place(s, "P_JackLantern", at(sx * 9, z), Vector3.new(-sx, 0, 0))
			lightUp(m, Color3.fromRGB(255, 160, 60), 16)
		end
	end
	for _, x in ipairs({ -55, -30, 30, 55 }) do
		for _, z in ipairs({ -66, 74 }) do
			local m = place(s, "P_JackLantern", at(x, z), up)
			lightUp(m, Color3.fromRGB(255, 160, 60), 16)
		end
	end
	scatter(s, "P_CandyCornGiant", { { -24, -40 }, { 24, -40 }, { -60, 40 }, { 60, 40 } }, Vector3.new(0, 0, -1), { 0.8, 1.1 })
	scatter(s, "P_Lollipop", { { -36, -20 }, { 36, -20 }, { -20, 60 }, { 22, 58 } }, Vector3.new(0, 0, -1), { 0.8, 1.0 })
	scatter(s, "P_GlowShroom", { { -40, 120 }, { 40, 118 }, { -60, 5 }, { 60, 0 } }, nil, { 1.2, 1.8 })
	place(s, "P_Signpost", at(14, -20), Vector3.new(0, 0, -1), 1.2, "HubSignpost")
	-- pumpkin patch
	scatter(s, "P_Pumpkin", grid(-180, -140, -80, -10, 14, 4, 11, nearBelt), nil, { 0.7, 1.6 })
	scatter(s, "P_HayBale", { { -100, -30 }, { -170, -18 }, { -150, -132 }, { -88, -140 } }, nil, { 0.9, 1.2 })
	-- haunted forest
	scatter(s, "P_SpookyTree", grid(84, -140, 180, -12, 16, 5, 23, nearBelt), nil, { 0.9, 1.5 })
	scatter(s, "P_GlowShroom", grid(90, -136, 176, -16, 24, 7, 29, nearBelt), nil, { 0.8, 1.6 })
	-- cursed graveyard
	local graves = grid(-178, 22, -84, 140, 10, 1.5, 37, nearBelt)
	for i, g in ipairs(graves) do
		place(s, if i % 3 == 0 then "P_StoneCross" else "P_Tombstone", at(g[1], g[2]), Vector3.new(0, 0, -1), 0.9 + (i % 4) * 0.08)
	end
	place(s, "P_Crypt", at(-130, 128), Vector3.new(0, 0, -1), 1.2)
	scatter(s, "P_SpookyTree", { { -180, 145 }, { -82, 140 }, { -182, 20 } }, nil, { 1.1, 1.4 })
	-- phantom castle
	local tower = place(s, "P_CastleTower", at(140, 122), Vector3.new(0, 0, -1), 1.0, "PhantomCastle")
	lightUp(tower, Color3.fromRGB(190, 90, 255), 30)
	place(s, "P_CastleTower", at(100, 138), Vector3.new(0, 0, -1), 0.6)
	place(s, "P_CastleTower", at(180, 138), Vector3.new(0, 0, -1), 0.6)
	scatter(s, "P_GlowShroom", grid(88, 20, 182, 100, 26, 6, 41, nearBelt), nil, { 0.9, 1.4 })
	for _, xz in ipairs({ { 90, 40 }, { 186, 40 }, { 90, 100 }, { 186, 100 } }) do
		local m = place(s, "P_JackLantern", at(xz[1], xz[2]), Vector3.new(0, 0, -1))
		lightUp(m, Color3.fromRGB(190, 120, 255), 18)
	end
end

local function buildBuckets(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "Buckets"
	f.Parent = root
	for _, b in ipairs(Halloween.Buckets) do
		local m = place(f, "P_JackLantern", b.pos, Vector3.new(0, 0, -1), 0.6, b.id)
		if m then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
			lightUp(m, Color3.fromRGB(255, 200, 80), 12)
		end
		local trigger = part({ Name = "BucketPart", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(b.pos + Vector3.new(0, 2, 0)), Transparency = 1, CanCollide = false, Parent = m or f })
		trigger:SetAttribute("Bucket", b.id)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Grab candy"
		pr.ObjectText = "Candy Bucket"
		pr.HoldDuration = 0.3
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = trigger
	end
end

-- hidden candies: one model each; clients hide the ones they've already found
local function buildCandies(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "Candies"
	f.Parent = root
	for _, c in ipairs(Halloween.Candies) do
		local m = place(f, "P_CandyPickup", c.pos - Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), 1.0, c.id)
		if not m then
			m = Instance.new("Model")
			m.Name = c.id
			part({ Name = "Wrapper", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(c.pos), Color = Color3.fromRGB(255, 120, 200), Parent = m })
			m.Parent = f
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CastShadow = false
			end
		end
		m:SetAttribute("Candy", c.id)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		CollectionService:AddTag(m, "Candy")
		local core = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		if core then
			light(core, Color3.fromRGB(255, 150, 220), 8, 1.2)
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(255, 200, 240)
			sp.Parent = core
		end
	end
end

local function buildAreaSigns(root: Instance)
	for _, a in ipairs(Halloween.Areas) do
		if a.gate then
			local towardHub = Vector3.new(if a.gate.X > O.X then -1 else 1, 0, 0)
			gate(root, a, towardHub)
		end
	end
	-- welcome board at the arrival
	local wp = at(-22, -94, 5)
	sign(root, CFrame.lookAt(wp, wp + Vector3.new(0.6, 0, -1)), Vector3.new(13, 7.5, 0.6), {
		{ "HALLOWEEN ISLAND", 0.3, Color3.fromRGB(255, 150, 40) },
		{ "Snag spooky Goobers from the belts", 0.16, Color3.new(1, 1, 1) },
		{ "Find 30 hidden candies", 0.16, Color3.new(1, 1, 1) },
		{ "Level up the Event Track!", 0.16, Color3.fromRGB(200, 160, 255) },
	})
	part({ Name = "WelcomePost", Size = Vector3.new(0.8, 6, 0.8), CFrame = CFrame.new(wp.X, O.Y + 1, wp.Z + 0.5), Color = Color3.fromRGB(60, 36, 24), Material = Enum.Material.Wood, Parent = root })
end

-- ------------------------------------------------------------- build
function IslandBuilder.Build()
	local old = workspace:FindFirstChild("HalloweenIsland")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "HalloweenIsland"
	buildGround(root)
	-- fences between areas (gaps at the gates)
	local gx, top, bot = 70, 150, -150
	for _, sx in ipairs({ -1, 1 }) do
		local x = O.X + sx * gx
		local gaps = {}
		for _, a in ipairs(Halloween.Areas) do
			if a.gate and math.abs(a.gate.X - x) < 1 then
				table.insert(gaps, { a.gate.Z - (O.Z + bot), 8 })
			end
		end
		fenceRun(root, Vector3.new(x, O.Y, O.Z + bot), Vector3.new(x, O.Y, O.Z + top), gaps)
		-- between the south and north side areas (no gap: reach them from the Village)
		fenceRun(root, Vector3.new(O.X + sx * 70, O.Y, O.Z + 10), Vector3.new(O.X + sx * 190, O.Y, O.Z + 10), nil)
	end
	-- outer fence
	fenceRun(root, at(-190, -150), at(190, -150), nil)
	fenceRun(root, at(-190, 150), at(190, 150), nil)
	fenceRun(root, at(-190, -150), at(-190, 150), nil)
	fenceRun(root, at(190, -150), at(190, 150), nil)
	buildAreaSigns(root)
	local belts = Instance.new("Folder")
	belts.Name = "Belts"
	belts.Parent = root
	for _, name in ipairs(Halloween.LineOrder) do
		belt(belts, name, Halloween.Lines[name])
	end
	buildScenery(root)
	buildBuckets(root)
	buildCandies(root)
	booth(root, "CandyShop", at(-34, -78), Vector3.new(0, 0, 1), "CANDY SHOP", "Spend your candy!", Color3.fromRGB(255, 120, 30), "Open shop")
	booth(root, "QuestBoard", at(34, -78), Vector3.new(0, 0, 1), "QUEST BOARD", "Halloween quests", Color3.fromRGB(140, 70, 220), "View quests")
	portal(root, "ReturnPortal", Halloween.IslandPortal.pos, Halloween.IslandPortal.facing, "PortalOut", "GOOBER TOWN", 1.3)
	root.Parent = workspace
	-- the mainland portal lives with the island so one rebuild covers both
	local mainPortal = portal(root, "SpookyPortal", Halloween.MainPortal.pos, Halloween.MainPortal.facing, "PortalIn", "SPOOKY PORTAL", 1.3)
	local _ = mainPortal
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return IslandBuilder

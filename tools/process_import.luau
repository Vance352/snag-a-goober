--[[
	process_import.luau - turn the Studio 3D-Importer result of
	Assets/Exports/SAG_AllAssets.fbx (or SAG_Halloween.fbx) into game templates.

	Run in Edit mode (MCP execute_luau / command bar) with the local http server
	running. Finds every imported MeshPart named <AssetId>__<Slot>, groups them
	by asset, then for each asset:
	  * colours + materials each part from palette.json (Blender materials)
	  * fixes orientation (faces -Z) using the Goobers' eyes as a compass
	  * fixes scale against the Blender dimensions in palette.json
	  * Goobers: normalises to GooberData height x rarity scale and builds the
	    Root/Pivot/Anim skeleton ModelService expects
	  * stores templates in ReplicatedStorage.Assets.Goobers / .Props
	Returns a JSON report. Leaves the raw import untouched (delete it after
	checking the report).
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local palette = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:34873/Assets/AssetDocumentation/palette.json?t=" .. os.clock(), true))
-- Eyes/pupils are NOT uploaded meshes (Roblox moderation false-positives on
-- paired spheres); they are rebuilt here from Blender specs as native parts.
local nativeSpec = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:34873/Assets/AssetDocumentation/native_parts.json?t=" .. os.clock(), true))
-- (also every other paired round face feature: cheeks, sockets, buttons, glowing eyes)
local NATIVE_SLOTS = { Eye = true, Pupil = true, Cheek = true, Socket = true, Button = true, EyeGlow = true }
-- Blender (x, y, z) -> Roblox (-x, z, y)   (verified on the imported P_Gusher)
local function b2r(v)
	return Vector3.new(-v[1], v[3], v[2])
end
local GooberData = require(RS.Shared.GooberData:Clone())
local Config = require(RS.Shared.Config:Clone())

local MATERIAL = {
	Glass = { Enum.Material.Glass, 0.45 },
	Jelly = { Enum.Material.Glass, 0.25 },
	Bubble = { Enum.Material.Glass, 0.15 },
	Gold = { Enum.Material.Foil, 0 },
	GoldDark = { Enum.Material.Foil, 0 },
	Chain = { Enum.Material.Foil, 0 },
	Mirror = { Enum.Material.Foil, 0 },
	Metal = { Enum.Material.Metal, 0 },
	Roller = { Enum.Material.Metal, 0 },
	Light = { Enum.Material.Neon, 0 },
	Orb = { Enum.Material.Neon, 0 },
	Glow = { Enum.Material.Neon, 0 },
	Screen = { Enum.Material.Neon, 0 },
	Bulb = { Enum.Material.Neon, 0 },
	VoxA = { Enum.Material.Neon, 0 },
	VoxC = { Enum.Material.Neon, 0 },
	Ring = { Enum.Material.Neon, 0 },
	-- Halloween update
	Swirl = { Enum.Material.Neon, 0.15 },
	Window = { Enum.Material.Neon, 0 },
	Flame = { Enum.Material.Neon, 0 },
	Fire = { Enum.Material.Neon, 0 },
	Carve = { Enum.Material.Neon, 0 },
	GlowB = { Enum.Material.Neon, 0 },
	Brew = { Enum.Material.Neon, 0 },
	Iron = { Enum.Material.Metal, 0 },
	Gem = { Enum.Material.Glass, 0.1 },
	Slop = { Enum.Material.SmoothPlastic, 0 },
	-- Goober Breach update
	Slime = { Enum.Material.Neon, 0.1 },
	Trim = { Enum.Material.Foil, 0 },
	MetalDark = { Enum.Material.Metal, 0 },
	Jar = { Enum.Material.Glass, 0.2 },
}
-- collidable prop slots (everything else is decoration)
local SOLID_PROPS = { P_Gusher = true, P_SlopVat = true, P_SlopOMatic = true, P_RebirthShrine = true, P_ChaosRift = true, P_LampPost = true, P_SlopBarrel = true, P_MushTree = true, P_Trophy = true,
	-- Halloween Island (convex-hull collisions; the portal swirl stays walk-through)
	P_SpookyPortal = true, P_HauntedHouse = true, P_Crypt = true, P_CastleTower = true, P_GreatPumpkin = true, P_Cauldron = true,
	P_Tombstone = true, P_StoneCross = true, P_IronFence = true, P_Pumpkin = true, P_HayBale = true, P_CandyCornGiant = true,
	P_Lollipop = true, P_Signpost = true, P_JackLantern = true,
	-- Goober Breach update (the Breach frame and the Mart stall are solid; the ring and the blaster aren't)
	P_GooberBreach = true, P_MartStall = true }
local HULL_PROPS = { P_Gusher = true, P_SlopVat = true, P_RebirthShrine = true }
for k in pairs(SOLID_PROPS) do
	if k:sub(1, 2) == "P_" and not ({ P_SlopOMatic = 1, P_ChaosRift = 1, P_LampPost = 1, P_SlopBarrel = 1, P_MushTree = 1, P_Trophy = 1 })[k] then
		HULL_PROPS[k] = true
	end
end

-- 1) gather imported parts
local groups = {}
local count = 0
-- raw imports live in Workspace right after Import 3D, and are kept in
-- ServerStorage.RawImport afterwards so the processor can be re-run anytime
local sources = { workspace }
if game.ServerStorage:FindFirstChild("RawImport") then
	table.insert(sources, game.ServerStorage.RawImport)
end
local all = {}
for _, src in ipairs(sources) do
	for _, d in ipairs(src:GetDescendants()) do
		table.insert(all, d)
	end
end
for _, d in ipairs(all) do
	if d:IsA("MeshPart") then
		local aid, slot = d.Name:match("^([GHP][%w_]-)__(%w+)$")
		if aid and palette.palette[aid] and not NATIVE_SLOTS[slot] then
			groups[aid] = groups[aid] or {}
			table.insert(groups[aid], { part = d, slot = slot })
			count += 1
		end
	end
end
assert(count > 0, "no imported MeshParts named <Asset>__<Slot> found in Workspace")

local function bbox(parts)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, e in ipairs(parts) do
		local p = e.part
		local cf, sz = p.CFrame, p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz2 in ipairs({ -1, 1 }) do
					local w = cf * Vector3.new(sx * sz.X, sy * sz.Y, sz2 * sz.Z)
					mn = mn:Min(w)
					mx = mx:Max(w)
				end
			end
		end
	end
	return mn, mx
end

-- 2) global orientation from the Goobers' eyes (Eye parts sit on the -Y face in Blender)
local yawVotes = {}
for aid, parts in pairs(groups) do
	if aid:sub(1, 1) == "G" or aid:sub(1, 1) == "H" then
		local mn, mx = bbox(parts)
		local center = (mn + mx) / 2
		for _, e in ipairs(parts) do
			if e.slot == "Eye" then
				local dir = (e.part.Position - center) * Vector3.new(1, 0, 1)
				if dir.Magnitude > 0.05 then
					table.insert(yawVotes, math.atan2(-dir.X, -dir.Z)) -- yaw that maps dir onto -Z
				end
			end
		end
	end
end
table.sort(yawVotes)
-- (Eye meshes are skipped now, so votes may be empty; the verified mapping
-- already faces -Z, i.e. yaw 0)
local yaw = yawVotes[math.max(1, math.floor(#yawVotes / 2))] or 0
-- snap to the nearest 90 degrees (the exporter only swaps axes)
yaw = math.round(yaw / (math.pi / 2)) * (math.pi / 2)
local fix = CFrame.Angles(0, -yaw, 0)

local assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = RS
local function sub(name)
	local f = assets:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = assets
	return f
end
local gFolder, pFolder = sub("Goobers"), sub("Props")

local report = { parts = count, assets = 0, yawDeg = math.deg(yaw), scale = {}, missing = {} }

for aid, parts in pairs(groups) do
	local isGoober = aid:sub(1, 1) == "G" or aid:sub(1, 1) == "H" -- H = Halloween Goobers
	local model = Instance.new("Model")
	model.Name = aid
	-- copy + colour
	local copies = {}
	for _, e in ipairs(parts) do
		local p = e.part:Clone()
		p.Name = e.slot
		for _, ch in ipairs(p:GetChildren()) do
			if not ch:IsA("SurfaceAppearance") then
				ch:Destroy()
			end
		end
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy()
		end
		local rgb = palette.palette[aid][e.slot]
		if rgb then
			p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
		local m = MATERIAL[e.slot]
		p.Material = if m then m[1] else Enum.Material.SmoothPlastic
		p.Transparency = if m then m[2] else 0
		p.TextureID = ""
		p.Anchored = true
		p.CanTouch = false
		p.CastShadow = true
		p.CollisionFidelity = Enum.CollisionFidelity.Box
		p.RenderFidelity = Enum.RenderFidelity.Automatic
		p.Parent = model
		table.insert(copies, { part = p, slot = e.slot })
	end
	-- native eyes/pupils, placed relative to a reference mesh in import space
	local specs = nativeSpec.native[aid]
	local centers = nativeSpec.slotCenters[aid]
	if specs and #specs > 0 and centers then
		local ref
		for _, e in ipairs(copies) do
			if centers[e.slot] and (not ref or e.part.Size.Magnitude > ref.part.Size.Magnitude) then
				ref = e
			end
		end
		assert(ref, "no reference slot for " .. aid)
		local refB = centers[ref.slot]
		for _, spec in ipairs(specs) do
			local d = { spec.center[1] - refB[1], spec.center[2] - refB[2], spec.center[3] - refB[3] }
			local p = Instance.new("Part")
			p.Name = spec.slot
			p.Size = b2r({ spec.size[1], spec.size[2], spec.size[3] }):Abs()
			p.CFrame = CFrame.new(ref.part.Position + b2r(d))
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			if spec.shape == "ball" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			end
			local rgb = palette.palette[aid][spec.slot]
			p.Color = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else Color3.new(1, 1, 1)
			p.Material = if spec.slot == "EyeGlow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = model
			table.insert(copies, { part = p, slot = spec.slot })
		end
		report.native = (report.native or 0) + #specs
	end

	-- orient: rotate about the bbox centre, then sit on the origin facing -Z
	local mn, mx = bbox(copies)
	local center = (mn + mx) / 2
	for _, e in ipairs(copies) do
		e.part.CFrame = CFrame.new(center) * fix * CFrame.new(-center) * e.part.CFrame
	end
	mn, mx = bbox(copies)
	local size = mx - mn
	-- scale
	local target
	if isGoober then
		local def = GooberData.ById[aid]
		target = def.height * Config.Rarities[def.rarity].scale
	else
		target = palette.dims[aid].size[3] -- Blender Z height in studs
	end
	local s = target / size.Y
	table.insert(report.scale, ("%s x%.3f"):format(aid, s))
	local base = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	for _, e in ipairs(copies) do
		local p = e.part
		local rel = p.CFrame - base
		p.Size *= s
		p.CFrame = CFrame.new(rel.Position * s) * (rel - rel.Position)
	end
	if isGoober then
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(1, 0.2, 1)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CFrame = CFrame.new(0, 0.1, 0)
		root.Parent = model
		local pivot = root:Clone()
		pivot.Name = "Pivot"
		pivot.Parent = model
		for _, e in ipairs(copies) do
			local w = Instance.new("WeldConstraint")
			w.Part0 = pivot
			w.Part1 = e.part
			w.Parent = e.part
			e.part.CanCollide = false
			e.part.CanQuery = false
			e.part.Anchored = false
			e.part.Massless = true
		end
		local anim = Instance.new("Weld")
		anim.Name = "Anim"
		anim.Part0 = root
		anim.Part1 = pivot
		anim.Parent = root
		pivot.Anchored = false
		model.PrimaryPart = root
		model.WorldPivot = CFrame.new()
		local old = gFolder:FindFirstChild(aid)
		if old then
			old:Destroy()
		end
		model.Parent = gFolder
	else
		for _, e in ipairs(copies) do
			e.part.CanCollide = (SOLID_PROPS[aid] == true or e.slot == "Base" or e.slot == "Frame") and e.slot ~= "Swirl"
			if e.part.CanCollide and HULL_PROPS[aid] then
				e.part.CollisionFidelity = Enum.CollisionFidelity.Hull
			end
		end
		model.WorldPivot = CFrame.new()
		local old = pFolder:FindFirstChild(aid)
		if old then
			old:Destroy()
		end
		model.Parent = pFolder
	end
	report.assets += 1
end
for aid in pairs(palette.palette) do
	if not groups[aid] then
		table.insert(report.missing, aid)
	end
end
return HS:JSONEncode(report)

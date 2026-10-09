--[[
	ModelService - builds Goober models.

	Every Goober model has the same skeleton so the rest of the game never cares
	whether it came from the imported Blender meshes or the fallback:

	  Model <GooberId>          attributes: GooberId, Uid, Rarity
	    Root   (Part, anchored, invisible, bottom centre, PrimaryPart)
	      Anim (Weld Root -> Pivot; the client animates its C0)
	    Pivot  (Part, invisible)
	    ...visual MeshParts, welded to Pivot

	Templates live in ReplicatedStorage.Assets.Goobers (made by
	tools/studio/process_import.luau from the Blender FBX import).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)

local ModelService = {}

local function templateFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Goobers") :: Folder?
end

local function prepParts(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.Anchored = d.Name == "Root"
			d.CastShadow = d.Name ~= "Root" and d.Name ~= "Pivot"
		end
	end
end

-- Simple stand-in used only if a template is missing.
local function fallback(def): Model
	local m = Instance.new("Model")
	local h = def.height
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Transparency = 1
	root.Parent = m
	local pivot = root:Clone()
	pivot.Name = "Pivot"
	pivot.Parent = m
	local body = Instance.new("Part")
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(h * 0.9, h * 0.9, h * 0.9)
	body.Color = Config.Rarities[def.rarity].color
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(0, h * 0.45, 0)
	body.Name = "Body"
	body.Parent = m
	for _, sx in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(h * 0.25, h * 0.25, h * 0.25)
		eye.Color = Color3.new(1, 1, 1)
		eye.CFrame = CFrame.new(sx * h * 0.18, h * 0.6, -h * 0.36)
		eye.Name = "Eye"
		eye.Parent = m
	end
	root.CFrame = CFrame.new(0, 0.1, 0)
	pivot.CFrame = root.CFrame
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p ~= root and p ~= pivot then
			local w = Instance.new("WeldConstraint")
			w.Part0 = pivot
			w.Part1 = p
			w.Parent = p
		end
	end
	local anim = Instance.new("Weld")
	anim.Name = "Anim"
	anim.Part0 = root
	anim.Part1 = pivot
	anim.Parent = root
	m.PrimaryPart = root
	return m
end

local function tagGui(def, mode: string): BillboardGui
	local rarity = Config.Rarities[def.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(150, 50) -- constant on-screen size (never fills the screen up close)
	gui.StudsOffsetWorldSpace = Vector3.new(0, def.height * rarity.scale + 1.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = if mode == "belt" then 80 else 45
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	local function label(name, text, color, height, order, font)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, height)
		t.Text = text
		t.TextColor3 = color
		t.TextScaled = true
		t.Font = font or Enum.Font.FredokaOne
		t.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 18, 50)
		stroke.Parent = t
		t.Parent = gui
		return t
	end

	label("Rarity", string.upper(def.rarity), rarity.color, 0.26, 1)
	label("Name", def.name, Color3.new(1, 1, 1), 0.36, 2)
	if mode == "belt" then
		label("Info", "$" .. Util.Short(def.price) .. "  •  +" .. Util.Short(def.income) .. "/s", Color3.fromRGB(255, 233, 120), 0.34, 3)
	else
		label("Info", "+" .. Util.Short(def.income) .. "/s", Color3.fromRGB(140, 255, 140), 0.34, 3)
	end
	return gui
end

function ModelService.Build(gooberId: string, uid: string, mode: string): Model
	local def = GooberData.ById[gooberId]
	local folder = templateFolder()
	local template = folder and folder:FindFirstChild(gooberId)
	local model: Model
	if template then
		model = (template :: Model):Clone()
	else
		model = fallback(def)
	end
	model.Name = gooberId
	model:SetAttribute("GooberId", gooberId)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Anim", def.anim)
	model:SetAttribute("Mode", mode)
	prepParts(model)
	local root = model:FindFirstChild("Root") :: BasePart
	model.PrimaryPart = root
	tagGui(def, mode).Parent = root
	CollectionService:AddTag(model, "Goober")
	return model
end

function ModelService.SetMode(model: Model, mode: string)
	local def = GooberData.ById[model:GetAttribute("GooberId")]
	local root = model.PrimaryPart
	if not root or not def then
		return
	end
	model:SetAttribute("Mode", mode)
	local old = root:FindFirstChild("Tag")
	if old then
		old:Destroy()
	end
	if mode ~= "carried" then
		tagGui(def, mode).Parent = root
	end
end

-- Anchored placement (belt, stand)
function ModelService.PlaceAt(model: Model, cf: CFrame)
	local root = model.PrimaryPart :: BasePart
	for _, w in ipairs(root:GetChildren()) do
		if w:IsA("Weld") and w.Name == "Carry" then
			w:Destroy()
		end
	end
	root.Anchored = true
	model:PivotTo(cf)
end

-- Welded to a character, floating above the head.
function ModelService.AttachTo(model: Model, character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local root = model.PrimaryPart :: BasePart
	if not hrp or not root then
		return false
	end
	root.Anchored = false
	model:PivotTo(hrp.CFrame * CFrame.new(0, 3.1, 0))
	local w = Instance.new("Weld")
	w.Name = "Carry"
	w.Part0 = hrp
	w.Part1 = root
	w.C0 = CFrame.new(0, 3.1, 0)
	w.Parent = root
	model.Parent = character
	return true
end

return ModelService

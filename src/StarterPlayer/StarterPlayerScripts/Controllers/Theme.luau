--[[
	Theme - UI colours and small constructors so every panel looks the same.
	Layout is authored at a 960x540 reference size and scaled by UIScale
	(see UI.luau), so touch targets stay >= ~44px on phones.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.Body = Enum.Font.GothamBold

Theme.C = {
	panel = Color3.fromRGB(42, 26, 69),
	panel2 = Color3.fromRGB(60, 38, 98),
	ink = Color3.fromRGB(24, 14, 40),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(205, 190, 235),
	lime = Color3.fromRGB(123, 227, 90),
	limeDark = Color3.fromRGB(62, 150, 52),
	gold = Color3.fromRGB(255, 201, 60),
	pink = Color3.fromRGB(255, 95, 162),
	red = Color3.fromRGB(255, 77, 94),
	blue = Color3.fromRGB(61, 165, 255),
	gray = Color3.fromRGB(120, 110, 140),
	robux = Color3.fromRGB(0, 176, 111),
}

function Theme.corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Theme.C.ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.textStroke(parent: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = Theme.C.ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function Theme.pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.frame(props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Theme.C.panel
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(f :: any)[k] = v
		end
	end
	f.Parent = props.Parent
	return f
end

function Theme.label(props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Theme.Font
	t.TextColor3 = Theme.C.text
	t.TextScaled = true
	t.RichText = true
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Stroke" and k ~= "MaxText" and k ~= "MinText" then
			(t :: any)[k] = v
		end
	end
	if props.Stroke ~= false then
		Theme.textStroke(t, if type(props.Stroke) == "number" then props.Stroke else 2)
	end
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = props.MaxText or 40
	lim.MinTextSize = props.MinText or 12
	lim.Parent = t
	t.Parent = props.Parent
	return t
end

-- Chunky button with a pressed animation. onClick is called on Activated.
function Theme.button(props, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.TextColor3 = Theme.C.text
	b.TextScaled = true
	b.BackgroundColor3 = props.Color or Theme.C.lime
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Color" and k ~= "Radius" and k ~= "MaxText" then
			(b :: any)[k] = v
		end
	end
	Theme.corner(b, props.Radius or 12)
	Theme.stroke(b, 3)
	Theme.textStroke(b, 2)
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = props.MaxText or 30
	lim.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	local function up()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = props.Parent
	return b
end

-- an original icon (Shared/Icons) as an ImageLabel
function Theme.icon(name: string, props): ImageLabel
	local Icons = require(game:GetService("ReplicatedStorage").Shared.Icons)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = Icons[name] or ""
	i.ScaleType = Enum.ScaleType.Fit
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(i :: any)[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

function Theme.tween(obj: Instance, t: number, goal, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

return Theme

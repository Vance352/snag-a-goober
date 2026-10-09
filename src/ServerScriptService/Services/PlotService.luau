--[[
	PlotService - assigns each player one of the 8 bases and keeps the base's
	visible state (owner sign, unlocked stands, shield, rarity rims) in sync.

	Plot layout (built by ServerStorage.Tools.MapBuilder):
	  Plots/Plot<n>            attributes Index, OwnerId
	    Bounds                 invisible region; its LookVector faces the belt
	    Stands/Stand<i>        Model, attribute Index, child part "Top"
	    CashPad, LockPad       floor pads
	    UpgradeStation         model with part "Console"
	    Sign                   part with SurfaceGui "SignGui"
	    Spawn                  invisible spawn marker
	    Shield                 folder of parts shown while locked
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local PlotService = {}

local plotsFolder: Folder
local owners: { [Model]: Player } = {}
local byPlayer: { [Player]: Model } = {}

local RIM_DEFAULT = Color3.fromRGB(176, 183, 195)

function PlotService.Init()
	plotsFolder = workspace:WaitForChild("Plots") :: Folder
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		plot:SetAttribute("OwnerId", 0)
		PlotService.SetShield(plot :: Model, false)
		PlotService.UpdateStands(plot :: Model, 0, {})
		PlotService.ResetSign(plot :: Model)
	end
end

function PlotService.All(): { Model }
	local list = {}
	for _, p in ipairs(plotsFolder:GetChildren()) do
		table.insert(list, p :: Model)
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	return list
end

function PlotService.Assign(player: Player): Model?
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in ipairs(PlotService.All()) do
		if not owners[plot] then
			owners[plot] = player
			byPlayer[player] = plot
			plot:SetAttribute("OwnerId", player.UserId)
			player:SetAttribute("PlotIndex", plot:GetAttribute("Index"))
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	owners[plot] = nil
	plot:SetAttribute("OwnerId", 0)
	PlotService.SetShield(plot, false)
	PlotService.UpdateStands(plot, 0, {})
	PlotService.ResetSign(plot)
	local bank = plot:FindFirstChild("CashPad")
	if bank and bank:FindFirstChild("Bank") then
		(bank.Bank :: any).Amount.Text = ""
	end
end

function PlotService.Get(player: Player): Model?
	return byPlayer[player]
end

function PlotService.Owner(plot: Model): Player?
	return owners[plot]
end

function PlotService.Bounds(plot: Model): BasePart
	return plot:FindFirstChild("Bounds") :: BasePart
end

function PlotService.Inside(plot: Model, pos: Vector3, margin: number?): boolean
	local b = PlotService.Bounds(plot)
	local rel = b.CFrame:PointToObjectSpace(pos)
	local m = margin or 0
	return math.abs(rel.X) <= b.Size.X / 2 + m and math.abs(rel.Z) <= b.Size.Z / 2 + m and rel.Y > -b.Size.Y / 2 - 2 and rel.Y < b.Size.Y / 2
end

function PlotService.PlotAt(pos: Vector3): Model?
	for _, plot in ipairs(PlotService.All()) do
		if PlotService.Inside(plot, pos) then
			return plot
		end
	end
	return nil
end

function PlotService.Stand(plot: Model, index: number): Model?
	return plot.Stands:FindFirstChild("Stand" .. index) :: Model?
end

function PlotService.StandCFrame(plot: Model, index: number): CFrame
	local stand = PlotService.Stand(plot, index)
	local top = stand and stand:FindFirstChild("Top") :: BasePart
	local b = PlotService.Bounds(plot)
	-- Goobers on stands face the plot entrance (toward the belt)
	local pos = top.Position + Vector3.new(0, top.Size.Y / 2, 0)
	return CFrame.lookAt(pos, pos + b.CFrame.LookVector)
end

function PlotService.SpawnCFrame(player: Player): CFrame?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	local spawn = plot:FindFirstChild("Spawn") :: BasePart
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

-- capacity: unlocked stand count. rims: { [standIndex] = rarity name }
function PlotService.UpdateStands(plot: Model, capacity: number, rims: { [number]: string })
	for _, stand in ipairs(plot.Stands:GetChildren()) do
		local idx = stand:GetAttribute("Index") or 0
		local unlocked = idx <= capacity
		-- show the next two locked stands as "ghosts" so players see room to grow
		local ghost = not unlocked and idx <= capacity + 2 and capacity > 0
		for _, p in ipairs(stand:GetDescendants()) do
			if p:IsA("BasePart") then
				local base = p:GetAttribute("BaseTransparency") or 0
				if unlocked then
					p.Transparency = base
				elseif ghost then
					p.Transparency = math.max(base, 0.75)
				else
					p.Transparency = 1
				end
				if p.Name:match("Rim$") then
					local r = rims[idx]
					p.Color = if r then Config.Rarities[r].color else RIM_DEFAULT
					p.Material = if r == "Legendary" or r == "Secret" then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
			elseif p:IsA("BillboardGui") and p.Name == "LockedTag" then
				p.Enabled = ghost
			end
		end
		stand:SetAttribute("Unlocked", unlocked)
	end
end

function PlotService.SetShield(plot: Model, on: boolean)
	local shield = plot:FindFirstChild("Shield")
	if not shield then
		return
	end
	for _, p in ipairs(shield:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = if on then (p:GetAttribute("OnTransparency") or 0.4) else 1
		elseif p:IsA("ParticleEmitter") or p:IsA("Beam") then
			p.Enabled = on
		end
	end
	plot:SetAttribute("Locked", on)
end

local function signLabels(plot: Model)
	local sign = plot:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	return gui
end

function PlotService.ResetSign(plot: Model)
	local gui = signLabels(plot)
	if gui then
		gui.Owner.Text = "Empty Base"
		gui.Info.Text = "Join to claim!"
		gui.Owner.TextColor3 = Color3.new(1, 1, 1)
	end
end

function PlotService.UpdateSign(player: Player, income: number, rebirths: number, level: number, vip: boolean)
	local plot = byPlayer[player]
	local gui = plot and signLabels(plot)
	if not gui then
		return
	end
	local stars = if rebirths > 0 then ("  " .. string.rep("★", math.min(rebirths, 5)) .. (if rebirths > 5 then "+" else "")) else ""
	gui.Owner.Text = player.DisplayName .. "'s Base" .. stars
	gui.Owner.TextColor3 = if vip then Color3.fromRGB(255, 214, 80) else Color3.new(1, 1, 1)
	gui.Info.Text = ("Lv %d  •  %s Slop/s"):format(level, Util.Short(income))
end

function PlotService.SetBankText(player: Player, amount: number, auto: boolean)
	local plot = byPlayer[player]
	local pad = plot and plot:FindFirstChild("CashPad")
	local bank = pad and pad:FindFirstChild("Bank")
	if bank then
		(bank :: any).Amount.Text = if auto then "AUTO COLLECT" else ("$" .. Util.Short(amount))
	end
end

Players.PlayerRemoving:Connect(function(player)
	-- release happens from GameService after data is settled; this is a safety net
	task.defer(function()
		if byPlayer[player] then
			PlotService.Release(player)
		end
	end)
end)

return PlotService

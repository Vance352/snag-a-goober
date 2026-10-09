--[[
	Feedback - turns server Notify/Effect messages into toasts, banners,
	sounds and particles. Every important action gets its own distinct
	feedback (snag != upgrade != Legendary != steal != rebirth).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Feedback = {}

local alarmBeam: Beam? = nil

local function nameOf(id: string): string
	local d = GooberData.ById[id]
	return d and d.name or "Goober"
end

local function rarityHex(id: string): string
	local d = GooberData.ById[id]
	return if d then Config.Rarities[d.rarity].color:ToHex() else "FFFFFF"
end

local function myHrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart
end

local HALLOWEEN = require(ReplicatedStorage.Shared.Halloween)
local function onIsland(): boolean
	local hrp = myHrp()
	if not hrp then
		return false
	end
	local o, size = HALLOWEEN.Origin, HALLOWEEN.Size
	return math.abs(hrp.Position.X - o.X) <= size.X / 2 + 12 and math.abs(hrp.Position.Z - o.Z) <= size.Y / 2 + 12
end

local function pointAt(userId: number?)
	if alarmBeam then
		alarmBeam:Destroy()
		alarmBeam = nil
	end
	if not userId then
		return
	end
	local other = Players:GetPlayerByUserId(userId)
	local hrp = myHrp()
	local ohrp = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not ohrp then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Parent = ohrp
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 0.8
	b.Width1 = 0.8
	b.FaceCamera = true
	b.LightEmission = 1
	b.Color = ColorSequence.new(Color3.fromRGB(255, 60, 80))
	b.Transparency = NumberSequence.new(0.2)
	b.Parent = hrp
	alarmBeam = b
	task.delay(Config.Steal.timeout, function()
		if alarmBeam == b then
			pointAt(nil)
		end
		a0:Destroy()
		a1:Destroy()
	end)
end

local NOTIFY = {}

function NOTIFY.Toast(p)
	UI.Toast(p.text, p.color)
end

function NOTIFY.Error(p)
	UI.Toast(p.text, "red", 2.6)
	Effects.Play("Error")
end

function NOTIFY.LevelUp(p)
	UI.Banner("LEVEL " .. p.level .. "!", ("+$%s bonus%s"):format(Util.Short(p.reward), if p.unlock then "  •  " .. p.unlock else ""), Color3.fromRGB(150, 255, 110), 3.5)
	Effects.Play("LevelUp")
	local hrp = myHrp()
	if hrp then
		Effects.Burst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(150, 255, 110), 40, 1)
	end
end

function NOTIFY.Discovered(p)
	local halloween = p.pool == "Halloween"
	UI.Toast(("NEW%s: <font color=\"#%s\">%s</font> (%d/%d)"):format(if halloween then " HALLOWEEN" else "", rarityHex(p.id), nameOf(p.id), p.count, p.total), if halloween then "gold" else "blue", 3.5, if halloween then "pumpkin" else "book")
	UI.dexBadgeWanted = true
	UI.CapBadges()
end

function NOTIFY.DexMilestone(p)
	UI.Banner("DEX MILESTONE!", ("%d Goobers found  •  +$%s  •  Title: %s"):format(p.count, Util.Short(p.coins), p.title), Color3.fromRGB(110, 190, 255), 4)
	Effects.Play("LevelUp", 1.2)
end

function NOTIFY.Upgraded(p)
	UI.Toast(("%s → Lv %d"):format(p.name, p.level), "green", 2, "upgrade")
	Effects.Play("Upgrade")
	local hrp = myHrp()
	if hrp then
		Effects.Burst(hrp.Position, Color3.fromRGB(150, 255, 110), 20, 0.6)
	end
end

function NOTIFY.StealAlert(p)
	UI.Banner("THIEF!", ("%s is stealing your %s! Tag them to get it back!"):format(p.thief, nameOf(p.id)), Color3.fromRGB(255, 70, 90), 4)
	Effects.Play("StealAlarm")
	Effects.Kick(0.6)
	pointAt(p.thiefId)
end

function NOTIFY.StealStart(p)
	UI.Banner("RUN HOME!", ("You grabbed %s's %s! Don't let them tag you!"):format(p.victim, nameOf(p.id)), Color3.fromRGB(255, 200, 60), 3)
	Effects.Play("Snag", 0.8)
end

function NOTIFY.Caught(p)
	UI.Banner("CAUGHT!", (p.by or "The owner") .. " tagged you. The Goober went home.", Color3.fromRGB(255, 70, 90), 3)
	Effects.Play("Caught")
	Effects.Kick(0.8)
end

function NOTIFY.CaughtThief(p)
	pointAt(nil)
	UI.Banner("GOT 'EM!", "You tagged " .. p.thief .. "! Your Goober is safe.", Color3.fromRGB(150, 255, 110), 3)
	Effects.Play("Caught", 1.2)
end

function NOTIFY.StealFailed(p)
	pointAt(nil)
	UI.Toast("Phew! " .. p.thief .. " couldn't get away with it.", "green")
end

function NOTIFY.StealSuccess(p)
	UI.Banner("STOLEN!", ("%s is yours now!"):format(nameOf(p.id)), Color3.fromRGB(255, 200, 60), 3)
	Effects.Play("StealSuccess")
end

function NOTIFY.StolenFrom(p)
	pointAt(nil)
	local insurance = if p.compensation > 0 then ("You got $%s insurance and a"):format(Util.Short(p.compensation)) else "Your base got a"
	UI.Banner("ROBBED!", ("%s stole your %s. %s %ds shield."):format(p.thief, nameOf(p.id), insurance, p.shield), Color3.fromRGB(255, 120, 120), 4.5)
	Effects.Play("Error")
end

function NOTIFY.Purchased(p)
	UI.Banner("THANK YOU!", p.text, Color3.fromRGB(255, 214, 80), 3.5)
	Effects.Play("Rebirth", 1.3)
	local hrp = myHrp()
	if hrp then
		Effects.Coins(hrp.Position + Vector3.new(0, 3, 0), 40)
	end
end

function NOTIFY.PurchaseCancelled()
	UI.Toast("Purchase cancelled - nothing was charged.", "purple", 2.5)
end

function NOTIFY.Offline(p)
	UI.Banner("WELCOME BACK!", ("Your Goobers earned $%s while you were away (%s)."):format(Util.Short(p.amount), Util.Time(p.seconds)), Color3.fromRGB(255, 214, 80), 5)
	Effects.Play("Coin")
end

function NOTIFY.PersonalDrop(p)
	local s = State.data
	if s and s.tutorial >= 4 then
		UI.Toast(("The Breach spat out your Personal Drop: <font color=\"#%s\">%s</font>!"):format(rarityHex(p.id), nameOf(p.id)), "gold", 3, "gift")
	end
end

function NOTIFY.TutorialStep(p)
	if p.step == 2 then
		Effects.Play("Place")
	end
end

function NOTIFY.Reborn(p)
	UI.Banner("REBORN! ★" .. p.rebirths, ("Your Goobers now earn x%.1f forever!"):format(p.multiplier), Color3.fromRGB(200, 130, 255), 5)
	Effects.Play("Rebirth")
	Effects.Kick(1)
end

-- ---------------------------------------------------------- Halloween
local AREA_NAME = {}
for _, a in ipairs(require(ReplicatedStorage.Shared.Halloween).Areas) do
	AREA_NAME[a.key] = a
end

function NOTIFY.CandyFound(p)
	UI.Toast(("Candy found! <font color=\"#FFAADC\">+%d Candy</font>  (%d/%d)"):format(p.candy, p.found, p.total), "purple", 2.6, "candy")
	Effects.Play("Candy")
	local hrp = myHrp()
	if hrp then
		Effects.Burst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 130, 210), 30, 0.8)
		Effects.FloatText(hrp.Position + Vector3.new(0, 4, 0), "+" .. p.candy .. " Candy", Color3.fromRGB(255, 160, 220), true)
	end
	if p.found == p.total then
		UI.Banner("EVERY CANDY FOUND!", "You found all " .. p.total .. " hidden candies!", Color3.fromRGB(255, 150, 220), 4)
	end
end

function NOTIFY.Bucket(p)
	UI.Toast(("+%d Candy from the bucket. It refills in %s."):format(p.candy, Util.Time(p.refill)), "purple", 2.6, "candy")
	Effects.Play("Bucket")
	local hrp = myHrp()
	if hrp then
		Effects.Burst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 160, 60), 20, 0.7)
	end
end

function NOTIFY.EventLevel(p)
	local jumped = p.from and p.level - p.from > 1
	UI.Banner(if jumped then ("EVENT LEVEL %d -> %d!"):format(p.from, p.level) else "EVENT LEVEL " .. p.level .. "!",
		if jumped then "New rewards are waiting in the EVENT menu" else "A new reward is waiting in the EVENT menu", Color3.fromRGB(255, 150, 40), 3.5)
	Effects.Play("EventLevel")
	local b = UI.refs.menuHalloween and UI.refs.menuHalloween:FindFirstChild("Badge")
	if b then
		b.Visible = true
	end
	local hrp = myHrp()
	if hrp then
		Effects.Burst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 150, 40), 40, 1)
	end
end

function NOTIFY.QuestDone(p)
	UI.Toast(("Quest complete: %s  Claim your reward!"):format(p.text), "green", 3.5, "scroll")
	Effects.Play("Quest")
	local b = UI.refs.menuQuests and UI.refs.menuQuests:FindFirstChild("Badge")
	if b then
		b.Visible = true
	end
end

function NOTIFY.Reward(p)
	UI.Banner(p.title or "REWARD!", table.concat(p.lines or {}, "  •  "), Color3.fromRGB(255, 200, 80), 3.5)
	Effects.Play("Reward")
	local hrp = myHrp()
	if hrp then
		Effects.Coins(hrp.Position + Vector3.new(0, 3, 0), 24)
	end
end

function NOTIFY.AreaEnter(p)
	local a = AREA_NAME[p.key]
	if a then
		UI.Banner(string.upper(a.name), a.blurb, a.color, 3)
		Effects.Play("Area")
	end
end

function NOTIFY.IslandIntro()
	if UI.ShowIntro then
		task.delay(0.9, UI.ShowIntro)
	end
end

-- ------------------------------------------------- Goober Breach / Blaster
function NOTIFY.HitConfirm(p)
	if p.stolen then
		UI.Toast(("SPLAT! %s's stolen Goober ran home."):format(p.target), "green", 2.6, "blaster")
	else
		UI.Toast(("SPLAT! You knocked %s's <font color=\"#%s\">%s</font> loose - GRAB IT!"):format(p.target, rarityHex(p.id), nameOf(p.id)), "green", 2.8, "blaster")
	end
	Effects.Play("HitConfirm")
end

function NOTIFY.GotBlasted(p)
	if p.stolen then
		UI.Banner("SPLAT!", p.by .. " blasted you - the stolen Goober ran home.", Color3.fromRGB(255, 120, 140), 2.5)
	else
		UI.Banner("SPLAT!", ("%s knocked your %s loose - grab it back!"):format(p.by, nameOf(p.id)), Color3.fromRGB(255, 120, 140), 2.5)
	end
end

function NOTIFY.BlastBlocked(p)
	UI.Toast(p.text, "purple", 1.6, "lock")
end

function NOTIFY.GooberTaken(p)
	UI.Toast(("%s grabbed your dropped %s - chase them!"):format(p.by, nameOf(p.id)), "red", 3, "blaster")
end

function NOTIFY.GooberLost(p)
	UI.Toast(("%s got your %s home. Get it back next time!"):format(p.by, nameOf(p.id)), "red", 3)
end

local EFFECT = {}

function EFFECT.GooberDropped(p)
	if p.pos then
		Effects.FloatText(p.pos + Vector3.new(0, 4.5, 0), "DROPPED!", Color3.fromRGB(255, 120, 140), true)
	end
	Effects.Play("Drop")
end

function EFFECT.Vanish(p)
	if p.pos then
		local cam = Workspace.CurrentCamera
		if cam and (cam.CFrame.Position - p.pos).Magnitude < 160 then
			Effects.Burst(p.pos + Vector3.new(0, 1, 0), Config.Rarities[p.rarity or "Common"].color, 14, 0.7)
		end
	end
end

function EFFECT.BreachAnnounce(p)
	local Breach = require(ReplicatedStorage.Shared.Breach)
	local typ = Breach.Types[p.typ]
	if typ and not onIsland() then
		UI.Banner(typ.title .. " INCOMING!", "The Goober Breach is about to blow - rarer Goobers!", typ.color, 2.6)
	end
end

function EFFECT.Snagged(p)
	local color = Config.Rarities[p.rarity].color
	if p.pos then
		Effects.Burst(p.pos + Vector3.new(0, 1.5, 0), color, if p.by == player.UserId then 30 else 12, 0.7)
	end
	if p.by == player.UserId then
		Effects.Play("Snag")
	end
end

function EFFECT.PlaceFx(p)
	Effects.Play(if p.delivered then "Deliver" else "Place")
	if p.delivered then
		local hrp = myHrp()
		if hrp then
			Effects.FloatText(hrp.Position + Vector3.new(0, 5, 0), "DELIVERED!", Color3.fromRGB(150, 255, 110), true)
		end
	end
end

function EFFECT.Placed(p)
	local base = Workspace:FindFirstChild("BaseGoobers")
	if not base then
		return
	end
	task.wait()
	for _, m in ipairs(base:GetChildren()) do
		if m:GetAttribute("Uid") == p.uid then
			local pos = m:GetPivot().Position
			Effects.Burst(pos + Vector3.new(0, 1.5, 0), Config.Rarities[p.rarity].color, 26, 0.8)
			if p.owner == player.UserId then
				Effects.FloatText(pos + Vector3.new(0, 4, 0), "+" .. Util.Short(GooberData.ById[p.id].income) .. "/s", Color3.fromRGB(150, 255, 110), true)
			end
		end
	end
end

function EFFECT.Collect(p)
	if p.owner ~= player.UserId then
		return
	end
	Effects.Play("Coin")
	if p.pos then
		Effects.Coins(p.pos + Vector3.new(0, 1, 0), math.clamp(math.floor(math.log10(p.amount + 1) * 8), 8, 50))
		Effects.FloatText(p.pos + Vector3.new(0, 3, 0), "+$" .. Util.Short(p.amount), Color3.fromRGB(255, 214, 80), true)
	end
end

function EFFECT.Coins(p)
	Effects.Play("Coin")
	if p.pos then
		Effects.Coins(p.pos, 16)
		Effects.FloatText(p.pos + Vector3.new(0, 2, 0), "+$" .. Util.Short(p.amount), Color3.fromRGB(255, 214, 80))
	end
end


function EFFECT.RareSpawn(p)
	local color = Config.Rarities[p.rarity].color
	-- island belts only announce to players on the island who can use that belt
	local spawnLine = Config.Lines[p.line or "Main"]
	if spawnLine and spawnLine.pool == "Halloween" then
		local s = State.data
		local area = HALLOWEEN.AreaByKey[spawnLine.area]
		local evl = s and s.event and s.event.eventLevel or 0
		if not onIsland() or not s or s.level < spawnLine.levelRequired or (area and evl < (area.eventLevel or 0) and HALLOWEEN.Active()) then
			return
		end
	elseif onIsland() and p.rarity == "Epic" then
		return -- a Slop Line Epic is no use to you on the island
	end
	if p.rarity == "Legendary" or p.rarity == "Secret" then
		local line = Config.Lines[p.line or "Main"]
		UI.Banner(("%s SPOTTED!"):format(p.rarity:upper()), ("%s just burst out of %s!"):format(nameOf(p.id), if line and line.area then "the " .. line.displayName .. " cauldron" else "the Goober Breach"), color, 4)
		Effects.Play(if p.rarity == "Secret" then "Legendary" else "Rare")
	else
		local line = Config.Lines[p.line or "Main"]
		local where = if line and line.area then "the " .. line.displayName .. " cauldron" else "the Goober Breach"
		UI.Toast(("EPIC <font color=\"#%s\">%s</font> flew out of %s!"):format(color:ToHex(), nameOf(p.id), where), "purple", 2.5, "swirl")
	end
end

function EFFECT.ThiefCaught(p)
	-- bystanders see a pop over the thief
	local thief = Players:GetPlayerByUserId(p.thief)
	local hrp = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		Effects.Burst(hrp.Position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 70, 90), 30, 1)
		Effects.FloatText(hrp.Position + Vector3.new(0, 5, 0), "CAUGHT!", Color3.fromRGB(255, 90, 100), true)
	end
end

function EFFECT.StealDone(p)
	local thief = Players:GetPlayerByUserId(p.thief)
	local hrp = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
	if hrp and p.thief ~= player.UserId and p.victim ~= player.UserId then
		Effects.FloatText(hrp.Position + Vector3.new(0, 5, 0), "STOLEN!", Color3.fromRGB(255, 200, 60), true)
	end
end

local savedLighting = nil
function EFFECT.ChaosStart(p)
	local def = Config.Chaos.types[p.type]
	UI.Banner("GOOBER CHAOS: " .. p.title .. "!", p.desc, def.color, 5)
	Effects.Play("Event")
	Effects.Kick(0.5)
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect
	if cc then
		savedLighting = savedLighting or { tint = cc.TintColor, sat = cc.Saturation }
		Theme.tween(cc, 1.5, { TintColor = Color3.new(1, 1, 1):Lerp(def.color, 0.25), Saturation = 0.35 })
	end
end

function EFFECT.ChaosEnd()
	UI.Toast("Goober Chaos is over. See you next time!", "purple", 3)
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect
	if cc and savedLighting then
		Theme.tween(cc, 2, { TintColor = savedLighting.tint, Saturation = savedLighting.sat })
	end
end

function EFFECT.RebirthFx(p)
	local who = Players:GetPlayerByUserId(p.player)
	local hrp = who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		Effects.Burst(hrp.Position, Color3.fromRGB(200, 130, 255), 60, 1.4)
	end
end

function EFFECT.Locked(p)
	if p.owner == player.UserId then
		Effects.Play("Upgrade", 0.7)
	end
end

function Feedback.Start()
	Net.Event("Notify").OnClientEvent:Connect(function(kind, payload)
		local fn = NOTIFY[kind]
		if fn then
			local ok, err = pcall(fn, payload or {})
			if not ok then
				warn("[Feedback]", kind, err)
			end
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(kind, payload)
		local fn = EFFECT[kind]
		if fn then
			task.spawn(function()
				local ok, err = pcall(fn, payload or {})
				if not ok then
					warn("[Feedback]", kind, err)
				end
			end)
		end
	end)
	-- passive income popups: every few seconds one of my Goobers shows its rate
	task.spawn(function()
		while true do
			task.wait(2.5)
			local base = Workspace:FindFirstChild("BaseGoobers")
			local s = State.data
			if base and s and s.rate > 0 then
				local mine = {}
				for _, m in ipairs(base:GetChildren()) do
					if m:GetAttribute("OwnerId") == player.UserId then
						table.insert(mine, m)
					end
				end
				if #mine > 0 then
					local m = mine[math.random(1, #mine)]
					local def = GooberData.ById[m:GetAttribute("GooberId")]
					local hrp = myHrp()
					local pos = m:GetPivot().Position
					if def and hrp and (hrp.Position - pos).Magnitude < 70 then
						Effects.FloatText(pos + Vector3.new(0, def.height + 1.5, 0), "+$" .. Util.Short(def.income * s.multiplier * 2.5), Color3.fromRGB(255, 214, 80))
					end
				end
			end
		end
	end)
end

return Feedback

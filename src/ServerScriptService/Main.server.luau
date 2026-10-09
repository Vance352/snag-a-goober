--[[
	Snag A Goober - server entry point. Wires services together and connects
	client requests. Every remote handler only forwards to a service that
	validates the request.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)

local Services = ServerScriptService:WaitForChild("Services")

local S = {
	Data = require(Services.DataService),
	Session = require(Services.Session),
	Model = require(Services.ModelService),
	Plot = require(Services.PlotService),
	Base = require(Services.BaseService),
	Breach = require(Services.BreachService),
	Combat = require(Services.CombatService),
	Leaderboard = require(Services.LeaderboardService),
	Carry = require(Services.CarryService),
	Steal = require(Services.StealService),
	Progress = require(Services.ProgressService),
	Character = require(Services.CharacterService),
	Chaos = require(Services.ChaosService),
	Monetization = require(Services.MonetizationService),
	MoveGuard = require(Services.MoveGuard),
	Hooks = require(Services.Hooks),
	Event = require(Services.EventService),
	Quest = require(Services.QuestService),
}
for _, svc in pairs(S) do
	if type(svc.Init) == "function" then
		svc.Init(S)
	end
end
S.Plot.Init()

if game:GetService("RunService"):IsStudio() then
	require(ServerScriptService.Testing.TestHarness).Start(S)
end

-- --------------------------------------------------------------- join
local function setupLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local income = Instance.new("IntValue")
	income.Name = "Slop/s"
	income.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Parent = ls
	ls.Parent = player
end

S.Data.OnLoaded(function(player: Player, data)
	if not player.Parent then
		return
	end
	local st = S.Session.Create(player, data)
	local plot = S.Plot.Assign(player)
	if not plot then
		player:Kick("This server is full of Goobers! Please join another server.")
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("Title", data.title)
	setupLeaderstats(player)
	S.Monetization.LoadPasses(player)
	S.Base.Load(player)
	-- offline earnings (a fraction of normal income, capped)
	local oe = Config.OfflineEarnings
	if data.lastOnline > 0 then
		local away = os.time() - data.lastOnline
		if away >= oe.minSeconds then
			local secs = math.min(away, oe.maxSeconds)
			local amount = math.floor(S.Session.ComputeRate(player) * oe.rate * secs)
			if amount > 0 then
				S.Session.AddCoins(player, amount)
				task.delay(3, function()
					S.Session.Notify(player, "Offline", { amount = amount, seconds = secs })
				end)
			end
		end
	end
	S.Base.LockFor(player, Config.Steal.joinGrace, false)
	st.ready = true
	S.Character.ApplySpeed(player)
	S.Character.RefreshTag(player)
	S.Character.ApplyVIP(player)
	S.Session.Push(player)
end)

S.Data.OnRemoving(function(player)
	S.Carry.OnRemoving(player)
	local st = S.Session.Get(player)
	if st then
		st.ready = false
	end
end)

S.Data.AfterRemove(function(player)
	S.Base.Unload(player)
	S.Plot.Release(player)
	S.Session.Remove(player)
end)

-- ------------------------------------------------------------- remotes
local function on(name: string, fn)
	Net.Event(name).OnServerEvent:Connect(function(player, ...)
		local st = S.Session.Get(player)
		if not st or not st.ready then
			return
		end
		local ok, err = pcall(fn, player, ...)
		if not ok then
			warn(("[Remote %s] %s"):format(name, tostring(err)))
		end
	end)
end

on("Snag", S.Breach.Snag)
on("Blast", S.Combat.Blast)
on("Steal", S.Steal.Request)
on("StealHold", S.Steal.HoldBegan)
on("Sell", S.Base.Sell)
on("Drop", S.Carry.Drop)
on("BuyUpgrade", S.Progress.BuyUpgrade)
on("Rebirth", S.Progress.Rebirth)
on("TutorialSkip", S.Progress.TutorialSkip)
on("TutorialAck", S.Progress.TutorialAck)
on("PromptPass", S.Monetization.PromptPass)
on("PromptProduct", S.Monetization.PromptProduct)
-- Halloween update
on("Travel", S.Event.Travel)
on("CollectCandy", S.Event.CollectCandy)
on("Bucket", S.Event.Bucket)
on("ClaimEvent", S.Event.ClaimTrack)
on("EventBuy", S.Event.Buy)
on("ClaimHDex", S.Event.ClaimHDex)
on("IntroSeen", S.Event.IntroSeen)
on("ClaimQuest", S.Quest.Claim)
on("ClaimLevel", S.Quest.ClaimLevel)
on("SetSetting", function(player, key, value)
	if (key == "music" or key == "sfx") and type(value) == "boolean" then
		S.Session.Get(player).data.settings[key] = value
		S.Session.MarkDirty(player)
	end
end)

-- -------------------------------------------------------------- start
S.Data.Start()
S.Session.Start()
S.Base.Start()
S.Breach.Start()
S.Combat.Start()
S.Leaderboard.Start()
S.Carry.Start()
S.Steal.Start()
S.Chaos.Start()
S.Character.Start()
S.Monetization.Start()
S.MoveGuard.Start()
S.Event.Start()
S.Quest.Start()

-- leaderstats + base signs
task.spawn(function()
	while true do
		task.wait(1)
		for player, st in pairs(S.Session.All()) do
			if st.ready then
				local ls = player:FindFirstChild("leaderstats")
				if ls then
					ls["Slop/s"].Value = math.floor(st.rate)
					ls.Rebirths.Value = st.data.rebirths
				end
				player:SetAttribute("Income", st.rate)
				S.Plot.UpdateSign(player, st.rate, st.data.rebirths, st.data.level, st.passes.VIP == true)
				local plot = S.Plot.Get(player)
				if plot then
					S.Plot.UpdateDecor(plot, st.data.level, st.data.rebirths)
				end
			end
		end
	end
end)

print(("[%s] server ready (data store %s)"):format(Config.GameName, S.Data.StoreName))

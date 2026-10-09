--[[
	BaseService - Goobers placed on a player's stands, their income, the Cash
	Pad, selling, and the base lock. Every placed Goober is a record in
	data.goobers[uid] = { id, stand } owned by exactly one player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GooberData = require(ReplicatedStorage.Shared.GooberData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local BaseService = {}
local S

local models: { [Player]: { [string]: Model } } = {}
local uidOwner: { [string]: Player } = {}
local baseFolder: Folder

local PAD_RADIUS = 5.5

function BaseService.Init(registry)
	S = registry
	baseFolder = Instance.new("Folder")
	baseFolder.Name = "BaseGoobers"
	baseFolder.Parent = workspace
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

function BaseService.OwnerOf(uid: string): Player?
	return uidOwner[uid]
end

function BaseService.ModelOf(player: Player, uid: string): Model?
	return models[player] and models[player][uid]
end

function BaseService.RefreshStands(player: Player)
	local plot = S.Plot.Get(player)
	local st = S.Session.Get(player)
	if not plot or not st then
		return
	end
	local rims = {}
	for uid, g in pairs(st.data.goobers) do
		if not st.inTransit[uid] then
			rims[g.stand] = GooberData.ById[g.id].rarity
		end
	end
	S.Plot.UpdateStands(plot, S.Session.Capacity(player), rims)
end

local function spawnModel(player: Player, uid: string, gid: string, stand: number, protectFor: number?)
	local plot = S.Plot.Get(player)
	if not plot then
		return nil
	end
	local model = S.Model.Build(gid, uid, "stand")
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Stand", stand)
	local rec = S.Session.Get(player) and S.Session.Get(player).data.goobers[uid]
	model:SetAttribute("Paid", rec and rec.paid)
	model:SetAttribute("ProtectedUntil", if protectFor then serverNow() + protectFor else 0)
	S.Model.PlaceAt(model, S.Plot.StandCFrame(plot, stand))
	model.Parent = baseFolder
	models[player] = models[player] or {}
	models[player][uid] = model
	uidOwner[uid] = player
	return model
end

function BaseService.Load(player: Player)
	local st = S.Session.Get(player)
	models[player] = {}
	for uid, g in pairs(st.data.goobers) do
		spawnModel(player, uid, g.id, g.stand, nil)
	end
	S.Session.ComputeRate(player)
	BaseService.RefreshStands(player)
end

function BaseService.Unload(player: Player)
	for uid, model in pairs(models[player] or {}) do
		model:Destroy()
		uidOwner[uid] = nil
	end
	models[player] = nil
end

function BaseService.FreeStand(player: Player): number?
	local st = S.Session.Get(player)
	if not st then
		return nil
	end
	local used = {}
	for _, g in pairs(st.data.goobers) do
		used[g.stand] = true
	end
	for i = 1, S.Session.Capacity(player) do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- Adds a Goober to the player's base. Returns uid or nil if no stand is free.
function BaseService.Place(player: Player, gid: string, opts: { uid: string?, stolen: boolean?, paid: number? }?): string?
	local st = S.Session.Get(player)
	if not st or not GooberData.ById[gid] then
		return nil
	end
	local stand = BaseService.FreeStand(player)
	if not stand then
		return nil
	end
	local uid = (opts and opts.uid) or S.Data.NewUid()
	local def0 = GooberData.ById[gid]
	-- remember what was paid so selling refunds half of *that*
	-- (discounted Personal Drops / free stolen Goobers can't be flipped for profit)
	local paid = if opts and opts.paid then opts.paid elseif opts and opts.stolen then math.floor(def0.price * 0.5) else def0.price
	st.data.goobers[uid] = { id = gid, stand = stand, paid = paid }
	spawnModel(player, uid, gid, stand, Config.Steal.placeProtection)
	S.Progress.Discover(player, gid)
	S.Session.ComputeRate(player)
	BaseService.RefreshStands(player)
	S.Session.MarkDirty(player)
	local def = GooberData.ById[gid]
	S.Session.Effect("Placed", { uid = uid, id = gid, rarity = def.rarity, owner = player.UserId })
	S.Progress.TutorialEvent(player, "Placed")
	return uid
end

function BaseService.RemoveRecord(player: Player, uid: string)
	local st = S.Session.Get(player)
	if st then
		st.data.goobers[uid] = nil
		st.inTransit[uid] = nil
	end
	local m = models[player] and models[player][uid]
	if m then
		m:Destroy()
		models[player][uid] = nil
	end
	uidOwner[uid] = nil
	if st then
		S.Session.ComputeRate(player)
		BaseService.RefreshStands(player)
		S.Session.MarkDirty(player)
	end
end

-- Theft started: the model leaves the stand but the record stays with the
-- victim (marked in transit) until the theft resolves.
function BaseService.DetachForSteal(victim: Player, uid: string): Model?
	local st = S.Session.Get(victim)
	local m = models[victim] and models[victim][uid]
	if not st or not m or st.inTransit[uid] then
		return nil
	end
	st.inTransit[uid] = true
	models[victim][uid] = nil
	S.Session.ComputeRate(victim)
	BaseService.RefreshStands(victim)
	S.Session.MarkDirty(victim)
	return m
end

function BaseService.ReturnFromSteal(victim: Player, uid: string, model: Model?)
	local st = S.Session.Get(victim)
	if model then
		model:Destroy()
	end
	if not st or not st.data.goobers[uid] then
		return
	end
	st.inTransit[uid] = nil
	local g = st.data.goobers[uid]
	spawnModel(victim, uid, g.id, g.stand, 10)
	S.Session.ComputeRate(victim)
	BaseService.RefreshStands(victim)
	S.Session.MarkDirty(victim)
end

function BaseService.Sell(player: Player, uid: string)
	if type(uid) ~= "string" or not S.Session.RateOk(player, "Sell", 4, 1) then
		return
	end
	local st = S.Session.Get(player)
	if not st then
		return
	end
	local g = st.data.goobers[uid]
	local m = models[player] and models[player][uid]
	if not g or not m or st.inTransit[uid] then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp or (hrp.Position - m:GetPivot().Position).Magnitude > Config.Steal.stealRange + 4 then
		return
	end
	local def = GooberData.ById[g.id]
	local refund = math.floor((g.paid or def.price) * Config.SellRefund)
	BaseService.RemoveRecord(player, uid)
	S.Session.AddCoins(player, refund)
	st.data.stats.sold += 1
	S.Session.Toast(player, ("Sold %s for $%s"):format(def.name, Util.Short(refund)), "gold")
	S.Session.Effect("Coins", { amount = refund, pos = m:GetPivot().Position }, player)
end

-- -------------------------------------------------------------- lock
function BaseService.IsLocked(player: Player): boolean
	local st = S.Session.Get(player)
	return st ~= nil and os.clock() < st.lockUntil
end

function BaseService.LockFor(player: Player, seconds: number, setCooldown: boolean)
	local st = S.Session.Get(player)
	local plot = S.Plot.Get(player)
	if not st or not plot then
		return
	end
	local now = os.clock()
	st.lockUntil = math.max(st.lockUntil, now + seconds)
	if setCooldown then
		st.lockReadyAt = st.lockUntil + Config.Lock.cooldown
	end
	plot:SetAttribute("LockedUntil", serverNow() + (st.lockUntil - now))
	S.Plot.SetShield(plot, true)
	S.Session.MarkDirty(player)
	BaseService.EjectIntruders(player)
end

function BaseService.EjectIntruders(owner: Player)
	local plot = S.Plot.Get(owner)
	if not plot then
		return
	end
	local b = S.Plot.Bounds(plot)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= owner then
			local char = other.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp and S.Plot.Inside(plot, hrp.Position) then
				local out = b.CFrame * CFrame.new(0, -b.Size.Y / 2, -b.Size.Z / 2 - 6) -- ground level outside the entrance
				S.MoveGuard.ServerMove(other, CFrame.new(out.Position + Vector3.new(0, 3.5, 0)))
			end
		end
	end
end

local function tryLock(player: Player, st)
	local now = os.clock()
	if now < st.lockUntil or now < st.lockReadyAt then
		return
	end
	local secs = Config.Lock.baseDuration + Config.Lock.perLevel * st.data.upgrades.Lock
	BaseService.LockFor(player, secs, true)
	S.Session.Toast(player, ("Base locked for %ds!"):format(secs), "blue")
	S.Session.Effect("Locked", { owner = player.UserId })
end

-- ------------------------------------------------------------- loops
local function nearPad(plot: Model, padName: string, pos: Vector3): boolean
	local pad = plot:FindFirstChild(padName) :: BasePart
	if not pad then
		return false
	end
	local d = pos - pad.Position
	return Vector2.new(d.X, d.Z).Magnitude <= PAD_RADIUS and math.abs(d.Y) < 8
end

function BaseService.Collect(player: Player)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	local amount = math.floor(st.data.bank)
	if amount < 1 then
		return
	end
	st.data.bank -= amount
	S.Session.AddCoins(player, amount)
	-- XP is proportional to coins collected (fractions carry over), so
	-- standing on the pad never farms XP faster than earning coins
	st.collectXpAcc = (st.collectXpAcc or 0) + amount / Config.XP.collectPer
	local xp = math.min(math.floor(st.collectXpAcc), Config.XP.collectMax)
	st.collectXpAcc -= xp
	if xp > 0 then
		S.Session.AddXP(player, xp)
	end
	local plot = S.Plot.Get(player)
	local pad = plot and plot:FindFirstChild("CashPad") :: BasePart
	S.Session.Effect("Collect", { amount = amount, pos = pad and pad.Position, owner = player.UserId })
	S.Progress.TutorialEvent(player, "Collected")
end

function BaseService.Start()
	-- income: once per second
	task.spawn(function()
		while true do
			task.wait(1)
			for player, st in pairs(S.Session.All()) do
				if st.ready then
					local rate = S.Session.ComputeRate(player)
					if rate > 0 then
						if st.passes.AutoCollect then
							S.Session.AddCoins(player, rate)
							-- Auto Collect earns the same XP a Cash Pad collect would (every 10 s)
							st.autoAcc = (st.autoAcc or 0) + rate
							st.autoTick = (st.autoTick or 0) + 1
							if st.autoTick >= 10 then
								st.autoTick = 0
								local xp = math.min(math.floor(st.autoAcc / Config.XP.collectPer), Config.XP.collectMax)
								if xp > 0 then
									S.Session.AddXP(player, xp)
								end
								st.autoAcc -= xp * Config.XP.collectPer
							end
							S.Progress.TutorialEvent(player, "Collected")
						else
							st.data.bank += rate -- totalEarned counts it when collected
						end
						st.dirty = true
					end
					S.Plot.SetBankText(player, st.data.bank, st.passes.AutoCollect == true)
					local plot = S.Plot.Get(player)
					if plot then
						local locked = os.clock() < st.lockUntil
						if plot:GetAttribute("Locked") ~= locked then
							S.Plot.SetShield(plot, locked)
						end
					end
				end
			end
		end
	end)
	-- pads + intruders: 5x a second
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, st in pairs(S.Session.All()) do
				if st.ready then
					local plot = S.Plot.Get(player)
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
					if plot and hrp then
						if nearPad(plot, "CashPad", hrp.Position) then
							BaseService.Collect(player)
						end
						if nearPad(plot, "LockPad", hrp.Position) then
							tryLock(player, st)
						end
					end
					if plot and os.clock() < st.lockUntil then
						BaseService.EjectIntruders(player)
					end
				end
			end
		end
	end)
end

return BaseService

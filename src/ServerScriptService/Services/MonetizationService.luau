--[[
	MonetizationService - gamepasses and developer products.

	* Pass ownership is always read from MarketplaceService on the server
	  (UserOwnsGamePassAsync on join, PromptGamePassPurchaseFinished for new
	  purchases). The client is never trusted about ownership.
	* ProcessReceipt is idempotent: each PurchaseId is recorded in the player's
	  save. A retried receipt that was already granted returns PurchaseGranted
	  without granting again. We only return PurchaseGranted after the save
	  containing the grant + receipt succeeds.
	* The Lucky Goober pass changes odds, so it is treated as a paid random
	  item probability modifier: exact odds are shown before purchase and the
	  offer is unavailable where PolicyService restricts paid random items.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local MonetizationService = {}
local S

local passById: { [number]: string } = {}
-- passes this server prompted, per player (purchase-finished must match one)
local prompted: { [Player]: { [number]: number } } = {}
local productById: { [number]: string } = {}
local QUOTE_TTL = 15 * 60

function MonetizationService.Init(registry)
	S = registry
	for key, p in pairs(Config.GamePasses) do
		if p.id and p.id > 0 then
			passById[p.id] = key
		end
	end
	for key, p in pairs(Config.Products) do
		if p.id and p.id > 0 then
			productById[p.id] = key
		end
	end
end

local function retry(fn, tries)
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		task.wait(i)
	end
	return false, nil
end

-- Apply the effects of an owned pass (also used right after purchase).
function MonetizationService.ApplyPass(player: Player, key: string)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	st.passes[key] = true
	if key == "SprintBoots" then
		S.Character.ApplySpeed(player)
	elseif key == "ExtraSlots" then
		S.Base.RefreshStands(player)
	elseif key == "DoubleCoins" then
		S.Session.ComputeRate(player)
	elseif key == "VIP" then
		S.Character.RefreshTag(player)
		S.Character.ApplyVIP(player)
	end
	S.Session.MarkDirty(player)
end

function MonetizationService.LoadPasses(player: Player)
	local st = S.Session.Get(player)
	if not st then
		return
	end
	for key, p in pairs(Config.GamePasses) do
		if p.id and p.id > 0 then
			local ok, owns = retry(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end, 3)
			if ok and owns then
				MonetizationService.ApplyPass(player, key)
			end
		end
	end
	local ok, policy = retry(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end, 2)
	-- if the policy lookup fails, be conservative and treat random items as restricted
	st.restrictedRandom = (not ok) or (policy and policy.ArePaidRandomItemsRestricted == true)
	S.Session.MarkDirty(player)
end

function MonetizationService.PromptPass(player: Player, key: any)
	if type(key) ~= "string" or not S.Session.RateOk(player, "Prompt", 3, 2) then
		return
	end
	local p = Config.GamePasses[key]
	local st = S.Session.Get(player)
	if not p or not st or not p.id or p.id <= 0 then
		return
	end
	if p.randomModifier and st.restrictedRandom then
		return S.Session.Notify(player, "Error", { text = "This item isn't available in your region." })
	end
	if st.passes[key] then
		return S.Session.Notify(player, "Error", { text = "You already own " .. p.name .. "!" })
	end
	prompted[player] = prompted[player] or {}
	prompted[player][p.id] = os.clock()
	MarketplaceService:PromptGamePassPurchase(player, p.id)
end

function MonetizationService.PromptProduct(player: Player, key: any)
	if type(key) ~= "string" or not S.Session.RateOk(player, "Prompt", 3, 2) then
		return
	end
	local p = Config.Products[key]
	if not p or not p.id or p.id <= 0 then
		return
	end
	MonetizationService.Quote(player) -- refresh what the store shows
	MarketplaceService:PromptProductPurchase(player, p.id)
end

-- Coins each bundle would give right now. The player is never given less
-- than the last quote they saw (within QUOTE_TTL).
function MonetizationService.Quote(player: Player)
	local st = S.Session.Get(player)
	if not st then
		return {}
	end
	local rate = S.Session.ComputeRate(player)
	local out = {}
	local now = os.clock()
	for key, p in pairs(Config.Products) do
		if p.minutes then
			local v = Util.ProductCoins(key, rate)
			out[key] = v
			local prev = st.lastQuote[key]
			if not prev or now - prev.t > QUOTE_TTL or v >= prev.value then
				st.lastQuote[key] = { value = v, t = now }
			end
		end
	end
	return out
end

local function grant(player: Player, key: string): boolean
	local st = S.Session.Get(player)
	local p = Config.Products[key]
	if not st or not p then
		return false
	end
	if p.minutes then
		local rate = S.Session.ComputeRate(player)
		local amount = Util.ProductCoins(key, rate)
		local q = st.lastQuote[key]
		if q and os.clock() - q.t <= QUOTE_TTL then
			amount = math.max(amount, q.value)
		end
		S.Session.AddCoins(player, amount)
		S.Session.Notify(player, "Purchased", { text = ("+$%s Slop Coins!"):format(Util.Comma(amount)), kind = "coins" })
		return true
	elseif p.boostSeconds then
		local now = os.time()
		st.data.boostUntil = math.max(now, st.data.boostUntil) + p.boostSeconds
		S.Session.ComputeRate(player)
		S.Session.Notify(player, "Purchased", {
			text = ("2x Income active for %s!"):format(Util.Time(st.data.boostUntil - now)),
			kind = "boost",
		})
		return true
	end
	return false
end

function MonetizationService.ProcessReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local t0 = os.clock()
	while not (S.Session.Get(player) and S.Session.Get(player).ready) do
		if os.clock() - t0 > 15 or not player.Parent then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		task.wait(0.2)
	end
	local st = S.Session.Get(player)
	local pid = tostring(receipt.PurchaseId)
	if st.data.receipts[pid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end
	local key = productById[receipt.ProductId]
	if not key then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grant(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	st.data.receipts[pid] = os.time()
	S.Session.MarkDirty(player)
	if S.Data.Save(player, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Grant + receipt are in memory, so a retry in this session won't double
	-- grant; they'll save on the next autosave/leave.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		local wasPrompted = prompted[player] and prompted[player][passId] and os.clock() - prompted[player][passId] < 900
		if purchased and key and not wasPrompted then
			-- not a purchase we started: only trust Roblox's ownership record
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			purchased = ok and owns == true
		end
		if purchased and key then
			if prompted[player] then
				prompted[player][passId] = nil
			end
			MonetizationService.ApplyPass(player, key)
			S.Session.Notify(player, "Purchased", { text = "Thanks! " .. Config.GamePasses[key].name .. " is active.", kind = "pass" })
		elseif not purchased then
			S.Session.Notify(player, "PurchaseCancelled", {})
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not purchased then
			S.Session.Notify(player, "PurchaseCancelled", {})
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		prompted[player] = nil
	end)
	Net.Function("GetQuote").OnServerInvoke = function(player)
		if not S.Session.RateOk(player, "Quote", 4, 2) then
			return nil
		end
		return MonetizationService.Quote(player)
	end
end

MonetizationService._grant = grant

return MonetizationService

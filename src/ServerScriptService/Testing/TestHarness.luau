--[[
	TestHarness - Studio-only test utilities. Never active in live servers.

	Exposes ServerStorage.SAG_Test (BindableFunction). Studio tools (command
	bar, MCP) call  SAG_Test:Invoke(command, ...)  and get a JSON string back.
	Plugin code runs in a different Lua VM from game scripts, so this is the
	bridge for inspecting and driving real server state in tests.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TestHarness = {}

function TestHarness.Start(S)
	if not RunService:IsStudio() then
		return
	end
	-- record notifications per player
	local log: { [number]: { any } } = {}
	local origNotify = S.Session.Notify
	S.Session.Notify = function(player, kind, payload)
		local l = log[player.UserId] or {}
		log[player.UserId] = l
		table.insert(l, { t = os.clock(), kind = kind, payload = payload })
		if #l > 60 then
			table.remove(l, 1)
		end
		return origNotify(player, kind, payload)
	end
	local origToast = S.Session.Toast
	S.Session.Toast = function(player, text, color)
		local l = log[player.UserId] or {}
		log[player.UserId] = l
		table.insert(l, { t = os.clock(), kind = "Toast", payload = { text = text } })
		return origToast(player, text, color)
	end

	local function P(id): Player
		if id then
			return Players:GetPlayerByUserId(id) :: Player
		end
		return Players:GetPlayers()[1]
	end

	local C = {}

	function C.players()
		local out = {}
		for _, p in ipairs(Players:GetPlayers()) do
			table.insert(out, { id = p.UserId, name = p.Name, ready = S.Session.Get(p) and S.Session.Get(p).ready })
		end
		return out
	end

	function C.state(id)
		local p = P(id)
		local snap = S.Session.Snapshot(p)
		local st = S.Session.Get(p)
		snap.goobers = st.data.goobers
		snap.inTransit = st.inTransit
		snap.lockUntilIn = st.lockUntil - os.clock()
		snap.plot = p:GetAttribute("PlotIndex")
		snap.walkSpeed = p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").WalkSpeed
		return snap
	end

	function C.notes(id, n)
		local l = log[P(id).UserId] or {}
		local out = {}
		for i = math.max(1, #l - (n or 10) + 1), #l do
			table.insert(out, l[i].kind .. ": " .. HttpService:JSONEncode(l[i].payload))
		end
		return out
	end

	function C.clearNotes(id)
		log[P(id).UserId] = {}
		return true
	end

	function C.give(amount, id)
		S.Session.AddCoins(P(id), amount)
		return S.Session.Get(P(id)).data.coins
	end

	function C.setCoins(amount, id)
		local st = S.Session.Get(P(id))
		st.data.coins = amount
		st.dirty = true
		return amount
	end

	function C.setLevel(level, id)
		local p = P(id)
		local st = S.Session.Get(p)
		st.data.level = level
		st.data.xp = 0
		p:SetAttribute("Level", level)
		S.Character.RefreshTag(p)
		st.dirty = true
		return level
	end

	function C.set(path, value, id)
		-- set a data field, e.g. set("upgrades.Slots", 4)
		local st = S.Session.Get(P(id))
		local t = st.data
		local keys = string.split(path, ".")
		for i = 1, #keys - 1 do
			t = t[keys[i]]
		end
		t[keys[#keys]] = value
		st.dirty = true
		S.Session.ComputeRate(P(id))
		S.Base.RefreshStands(P(id))
		return value
	end

	function C.unlock(id)
		local st = S.Session.Get(P(id))
		st.lockUntil = 0
		st.lockReadyAt = 0
		S.Plot.SetShield(S.Plot.Get(P(id)), false)
		return true
	end

	function C.belt()
		local out = {}
		for uid, b in pairs(S.Conveyor.All()) do
			local pos = S.Conveyor.PositionOf(b)
			table.insert(out, { uid = uid, id = b.id, line = b.line, reserved = b.reservedFor, x = math.floor(pos.X), z = pos.Z })
		end
		return out
	end

	function C.spawnBelt(gid, line, reservedId)
		local b = S.Conveyor.Spawn(gid, line or "Main", reservedId and P(reservedId) or nil)
		return b.uid
	end

	function C.place(gid, id)
		return S.Base.Place(P(id), gid)
	end

	function C.chaos(typ, seconds)
		S.Chaos.Force(typ, seconds)
		return true
	end

	function C.grantPass(key, id)
		S.Monetization.ApplyPass(P(id), key)
		return S.Session.Get(P(id)).passes
	end

	function C.revokePass(key, id)
		S.Session.Get(P(id)).passes[key] = nil
		if key == "VIP" then
			P(id):SetAttribute("VIP", false)
			local hrp = P(id).Character and P(id).Character:FindFirstChild("HumanoidRootPart")
			for _, n in ipairs({ "VIPTrail", "VIPSparkles", "VIPTrailA0", "VIPTrailA1" }) do
				local x = hrp and hrp:FindFirstChild(n)
				if x then
					x:Destroy()
				end
			end
			S.Character.RefreshTag(P(id))
		end
		S.Session.ComputeRate(P(id))
		S.Base.RefreshStands(P(id))
		S.Character.ApplySpeed(P(id))
		return S.Session.Get(P(id)).passes
	end

	-- Simulated receipt: exercises the real ProcessReceipt with a fake receipt.
	function C.receipt(productKey, purchaseId, id)
		local p = P(id)
		local prod = Config.Products[productKey]
		local fakeId = (prod.id and prod.id > 0) and prod.id or nil
		if not fakeId then
			return "product has no id configured"
		end
		local before = S.Session.Get(p).data.coins
		local decision = S.Monetization.ProcessReceipt({
			PlayerId = p.UserId,
			ProductId = fakeId,
			PurchaseId = purchaseId,
			CurrencySpent = prod.price,
			CurrencyType = Enum.CurrencyType.Robux,
			PlaceIdWherePurchased = game.PlaceId,
		})
		return { decision = tostring(decision), before = before, after = S.Session.Get(p).data.coins, boostLeft = S.Session.Get(p).data.boostUntil - os.time() }
	end

	function C.save(id)
		return S.Data.Save(P(id), false)
	end

	function C.readStore(id)
		local ds = game:GetService("DataStoreService"):GetDataStore(S.Data.StoreName)
		local v = ds:GetAsync("P_" .. P(id).UserId)
		if type(v) ~= "table" then
			return v
		end
		local d = v.data
		local n = 0
		for _ in pairs(d.goobers) do
			n += 1
		end
		return { lock = v.lock, coins = d.coins, level = d.level, rebirths = d.rebirths, goobers = n, upgrades = d.upgrades, tutorial = d.tutorial, receipts = d.receipts, dex = d.dex }
	end

	function C.wipeStore(id)
		local ds = game:GetService("DataStoreService"):GetDataStore(S.Data.StoreName)
		ds:RemoveAsync("P_" .. P(id).UserId)
		return true
	end

	function C.sanitizeTest()
		-- feed malformed data through the real sanitizer
		local d = S.Data.Defaults()
		d.coins = 0 / 0
		d.level = -5
		d.upgrades.Speed = 999
		d.goobers = {
			a = { id = "G01_Blorp", stand = 1 },
			b = { id = "G02_SirPuddle", stand = 1 }, -- duplicate stand
			c = { id = "NOT_A_GOOBER", stand = 2 },
			d = { id = "G03_Toastie", stand = 999 },
			e = "garbage",
		}
		S.Data._sanitize(d)
		local stands = {}
		for uid, g in pairs(d.goobers) do
			stands[uid] = g.stand
		end
		return { coins = d.coins, level = d.level, speed = d.upgrades.Speed, stands = stands }
	end

	function C.migrateTest()
		local old = { version = 0, coins = 123, goobers = {}, upgrades = {} }
		S.Data._migrate(old)
		S.Data._reconcile(old, S.Data.Defaults())
		return { version = old.version, coins = old.coins, hasDex = old.dex ~= nil, speed = old.upgrades.Speed }
	end

	function C.tp(x, y, z, id)
		local p = P(id)
		S.MoveGuard.ServerMove(p, CFrame.new(x, y, z))
		return true
	end

	function C.tpPlot(part, id, offsetZ)
		-- teleport to a part of the player's own plot (e.g. "CashPad")
		local p = P(id)
		local plot = S.Plot.Get(p)
		local target = plot:FindFirstChild(part, true) :: BasePart
		S.MoveGuard.ServerMove(p, CFrame.new(target.Position + Vector3.new(0, 3, offsetZ or 0)))
		return tostring(target.Position)
	end

	-- Checks every configured pass/product id against the live marketplace.
	function C.verifyMarketplace()
		local MS = game:GetService("MarketplaceService")
		local out = {}
		for key, p in pairs(Config.GamePasses) do
			local ok, info = pcall(MS.GetProductInfo, MS, p.id, Enum.InfoType.GamePass)
			out[key] = if ok then { id = p.id, name = info.Name, live = info.PriceInRobux, config = p.price, forSale = info.IsForSale, match = info.PriceInRobux == p.price } else { id = p.id, error = tostring(info) }
		end
		for key, p in pairs(Config.Products) do
			local ok, info = pcall(MS.GetProductInfo, MS, p.id, Enum.InfoType.Product)
			out[key] = if ok then { id = p.id, name = info.Name, live = info.PriceInRobux, config = p.price, match = info.PriceInRobux == p.price } else { id = p.id, error = tostring(info) }
		end
		return out
	end

	function C.stats()
		local belt = 0
		for _ in pairs(S.Conveyor.All()) do
			belt += 1
		end
		local parts = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		return { belt = belt, parts = parts, mem = math.floor(collectgarbage("count")), heartbeat = workspace:GetRealPhysicsFPS() }
	end

	local fn = ServerStorage:FindFirstChild("SAG_Test") or Instance.new("BindableFunction")
	fn.Name = "SAG_Test"
	fn.OnInvoke = function(cmd, ...)
		local f = C[cmd]
		if not f then
			return HttpService:JSONEncode({ error = "unknown command " .. tostring(cmd) })
		end
		local ok, res = pcall(f, ...)
		if not ok then
			return HttpService:JSONEncode({ error = tostring(res) })
		end
		local ok2, json = pcall(HttpService.JSONEncode, HttpService, res)
		return if ok2 then json else tostring(res)
	end
	fn.Parent = ServerStorage
	print("[TestHarness] ready (Studio only)")
end

return TestHarness

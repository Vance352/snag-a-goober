--[[
	Config - every tunable number in Snag A Goober lives here.
	Server and client both read this module; the server is the only side that
	acts on it for anything economic.
]]

local Config = {}

Config.GameName = "Snag A Goober"
Config.CurrencyName = "Slop Coins"
Config.DataVersion = 1

-- ------------------------------------------------------------------ rarity
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }

Config.Rarities = {
	Common = { color = Color3.fromRGB(201, 206, 214), xp = 5, scale = 1.0 },
	Uncommon = { color = Color3.fromRGB(91, 212, 91), xp = 12, scale = 1.05 },
	Rare = { color = Color3.fromRGB(61, 165, 255), xp = 30, scale = 1.1 },
	Epic = { color = Color3.fromRGB(176, 91, 255), xp = 80, scale = 1.15 },
	Legendary = { color = Color3.fromRGB(255, 182, 39), xp = 200, scale = 1.25 },
	Secret = { color = Color3.fromRGB(255, 61, 165), xp = 500, scale = 1.25 },
}

-- Spawn weights per line. They are percentages and each table sums to 100.
Config.Lines = {
	Main = {
		weights = { Common = 55, Uncommon = 27, Rare = 12.5, Epic = 4.3, Legendary = 1.0, Secret = 0.2 },
		interval = 2.2, -- seconds between spawns
		speed = 7, -- studs per second
		levelRequired = 1,
	},
	Gold = {
		weights = { Common = 0, Uncommon = 40, Rare = 35, Epic = 18, Legendary = 6, Secret = 1 },
		interval = 6,
		speed = 6,
		levelRequired = 10,
	},
}

-- Luck multiplies the weights of Rare and better, then odds are renormalised.
Config.LuckyRarities = { Rare = true, Epic = true, Legendary = true, Secret = true }

-- Personal Drops: every player periodically gets a Goober on the Main line
-- that only they can snag. Rolled with the player's personal luck.
Config.PersonalDrop = {
	interval = 45,
	baseLuck = 1.0,
	luckPerRebirth = 0.1,
	maxRebirthLuck = 0.5,
	luckyPassLuck = 0.5, -- Lucky Goober gamepass adds +0.5 (x1.5 at 0 rebirths)
	discount = 0.5, -- Personal Drops cost their owner half price
}

-- ----------------------------------------------------------------- economy
Config.StartingCoins = 50
Config.SellRefund = 0.5 -- selling returns 50% of the Goober's snag price
Config.OfflineEarnings = { rate = 0.25, maxSeconds = 4 * 3600, minSeconds = 120 }

Config.Upgrades = {
	{
		key = "Speed",
		name = "Zoomies",
		desc = "+1.5 walk speed",
		max = 10,
		baseCost = 50,
		growth = 2.2,
		resetsOnRebirth = true,
	},
	{
		key = "Slots",
		name = "More Stands",
		desc = "+1 Goober stand",
		max = 12,
		baseCost = 150,
		growth = 2.0,
		resetsOnRebirth = false,
	},
	{
		key = "Income",
		name = "Slop Pipes",
		desc = "+10% income",
		max = 20,
		baseCost = 300,
		growth = 1.8,
		resetsOnRebirth = true,
	},
	{
		key = "Lock",
		name = "Base Lock",
		desc = "+15s lock time",
		max = 5,
		baseCost = 500,
		growth = 3.0,
		resetsOnRebirth = true,
	},
}

Config.BaseWalkSpeed = 16
Config.SpeedPerLevel = 1.5
Config.SprintBootsBonus = 4
Config.BaseSlots = 6
Config.MaxStands = 28 -- physical stands built per plot
Config.IncomePerLevel = 0.10
Config.ExtraSlotsPass = 4

Config.Lock = { baseDuration = 30, perLevel = 15, cooldown = 120 }

-- ------------------------------------------------------------------ levels
Config.XP = {
	collectPer = 50, -- 1 XP per 50 coins collected (min 1, max 50 per collect)
	collectMax = 50,
	upgrade = 10,
	steal = 25,
	discovery = 25,
}

function Config.XPForLevel(level: number): number
	return math.floor(40 * level ^ 1.45)
end

Config.LevelUnlocks = {
	[3] = "Stealing unlocked",
	[5] = "Base Lock upgrades",
	[10] = "Gold Line unlocked",
	[15] = "Rebirth unlocked",
}

Config.StealLevel = 3
Config.LockLevel = 5

function Config.LevelReward(level: number): number
	return math.floor(15 * level ^ 1.5)
end

-- ----------------------------------------------------------------- rebirth
Config.Rebirth = {
	max = 10,
	incomeBonus = 0.5, -- +50% income per rebirth (additive)
	extraSlot = 1, -- +1 stand per rebirth
	maxExtraSlots = 4,
	startCoins = 500,
}

function Config.RebirthCost(rebirths: number): number
	return 1_000_000 * 3 ^ rebirths
end

function Config.RebirthLevel(rebirths: number): number
	return 15 + rebirths * 5
end

-- ---------------------------------------------------------------- stealing
Config.Steal = {
	holdDuration = 1.2,
	placeProtection = 45, -- seconds a newly placed Goober cannot be stolen
	joinGrace = 60, -- base is locked for this long after joining
	thiefCooldown = 60, -- after any steal attempt
	failedCooldown = 90, -- after getting caught
	pairCooldown = 300, -- same thief -> same victim
	victimShield = 120, -- victim base auto-locks after a successful theft
	catchRadius = 7,
	timeout = 45,
	carrySpeedMult = 0.85,
	stunTime = 2,
	compensation = 0.25, -- victim receives 25% of the stolen Goober's price
	compensationCooldown = 600, -- ...at most once per 10 minutes
	minCarryTime = 3, -- a theft can't complete faster than this (owner gets a chance)
	stealRange = 12,
}

Config.SnagRange = 14

-- ----------------------------------------------------------------- events
Config.Chaos = {
	period = 480, -- an event starts every 8 minutes (aligned to the clock)
	duration = 60,
	order = { "SlopStorm", "GoldenHour", "ChaosRift" },
	types = {
		SlopStorm = {
			title = "SLOP STORM",
			desc = "Goobers are pouring out 3x faster!",
			intervalMult = 0.33,
			luck = 1,
			color = Color3.fromRGB(123, 227, 90),
		},
		GoldenHour = {
			title = "GOLDEN HOUR",
			desc = "Rare-or-better Goobers are 2.5x more likely!",
			intervalMult = 1,
			luck = 2.5,
			color = Color3.fromRGB(255, 196, 61),
		},
		ChaosRift = {
			title = "CHAOS RIFT",
			desc = "The Chaos Goob can appear! Secrets x5!",
			intervalMult = 0.8,
			luck = 1,
			secretMult = 5,
			chaosGoobChance = 0.02,
			color = Color3.fromRGB(166, 76, 255),
		},
	},
}

-- --------------------------------------------------------------- dex goals
Config.DexMilestones = {
	{ count = 5, coins = 500, title = "Goober Spotter" },
	{ count = 10, coins = 5_000, title = "Goober Wrangler" },
	{ count = 15, coins = 50_000, title = "Goober Expert" },
	{ count = 20, coins = 500_000, title = "Goober Master" },
	{ count = 25, coins = 5_000_000, title = "Goober Legend" },
}

-- ------------------------------------------------------------ monetization
-- IDs are filled in after the passes/products are created on the Creator Hub.
-- A 0 id means "not configured": the store hides that offer.
Config.GamePasses = {
	VIP = {
		id = 2022824311,
		icon = "rbxassetid://79845686634010",
		name = "VIP Club",
		price = 249,
		desc = "Gold VIP name tag, sparkle trail, golden base sign and a VIP chat tag. Cosmetic only.",
	},
	DoubleCoins = {
		id = 2022452299,
		icon = "rbxassetid://75572407927419",
		name = "Double Slop Coins",
		price = 399,
		desc = "Permanently doubles all Goober income. Multiplies with upgrades, rebirths and boosts.",
	},
	ExtraSlots = {
		id = 2023412292,
		icon = "rbxassetid://108582372704823",
		name = "+4 Goober Stands",
		price = 199,
		desc = "Permanently adds 4 extra stands to your base.",
	},
	SprintBoots = {
		id = 2022320299,
		icon = "rbxassetid://109009677275707",
		name = "Sprint Boots",
		price = 99,
		desc = "Permanently +4 walk speed on top of your Zoomies upgrade.",
	},
	AutoCollect = {
		id = 2023184287,
		icon = "rbxassetid://113500650816678",
		name = "Auto Collect",
		price = 149,
		desc = "Your Goobers' coins go straight into your wallet - no need to step on the Cash Pad.",
	},
	Lucky = {
		id = 2021996302,
		icon = "rbxassetid://131853608626044",
		name = "Lucky Goober",
		price = 199,
		desc = "Adds +0.5 luck to your Personal Drops, making Rare-or-better Goobers more likely (e.g. 18% -> 24.8% with no rebirths). Exact odds shown before you buy.",
		randomModifier = true,
	},
}
Config.PassOrder = { "DoubleCoins", "AutoCollect", "ExtraSlots", "Lucky", "SprintBoots", "VIP" }

Config.Products = {
	CoinsSmall = {
		id = 3717345239,
		icon = "rbxassetid://80220919951547",
		name = "Slop Sack",
		price = 25,
		minutes = 5,
		minCoins = 500,
	},
	CoinsMedium = {
		id = 3717345325,
		icon = "rbxassetid://139106282248592",
		name = "Slop Barrel",
		price = 99,
		minutes = 30,
		minCoins = 2_500,
	},
	CoinsLarge = {
		id = 3717345363,
		icon = "rbxassetid://125386312850544",
		name = "Slop Tanker",
		price = 299,
		minutes = 120,
		minCoins = 10_000,
	},
	Boost = {
		id = 3717345400,
		icon = "rbxassetid://88092692009443",
		name = "2x Income (15 min)",
		price = 49,
		boostSeconds = 15 * 60,
	},
}
Config.ProductOrder = { "CoinsSmall", "CoinsMedium", "CoinsLarge", "Boost" }

-- --------------------------------------------------------------------- map
Config.Textures = {
	Chevron = "rbxassetid://87951433941492",
}

Config.Map = {
	beltY = 2.4, -- top surface of the belt
	beltStartX = -116,
	beltEndX = 116,
	mainZ = -8,
	goldZ = 8,
	beltWidth = 12,
	plotSize = Vector2.new(48, 64),
	plotXs = { -84, -28, 28, 84 },
	plotZ = 72, -- plot centres sit at z = +-72
}

-- --------------------------------------------------------------------- sfx
-- All sound effects live in one original synthesized "sound sprite"
-- (Assets/Audio/SAG_SFX.wav, made by tools/make_audio.py); each effect plays
-- its time region. Regions come from Assets/Audio/SAG_SFX.json.
Config.Audio = {
	Sprite = "rbxassetid://105795631759143",
	Music = "rbxassetid://85469046329980",
	Regions = {
		Snag = { 0.0, 0.32 },
		Place = { 0.62, 1.1701 },
		Coin = { 1.4701, 1.9901 },
		Upgrade = { 2.2901, 2.9701 },
		LevelUp = { 3.2701, 4.3501 },
		Rare = { 4.6501, 5.4501 },
		Legendary = { 5.7501, 7.1501 },
		StealAlarm = { 7.4501, 8.2302 },
		Caught = { 8.5302, 8.9102 },
		StealSuccess = { 9.2102, 9.9502 },
		Rebirth = { 10.2502, 12.1503 },
		Event = { 12.4503, 13.8503 },
		Click = { 14.1503, 14.1853 },
		Error = { 14.4853, 14.7453 },
	},
}

return Config

--[[
	Halloween - every tunable for the Halloween update: the island layout, the
	spooky conveyor lines, candy, the event track, the event shop, quests and
	level milestones. Server and client both read it; only the server acts on
	it for anything that grants rewards.

	Island coordinates are world positions. The island sits north of the main
	map (main map spans z -151..151), centred on ORIGIN.
]]

local Halloween = {}

Halloween.Enabled = true
-- event runs until this UTC time (shown as a countdown; rewards stay claimable)
Halloween.EndsAt = 1794268800 -- 2026-11-10 00:00 UTC

local O = Vector3.new(0, 0, 700)
Halloween.Origin = O
Halloween.Size = Vector2.new(380, 300) -- x, z extents of the island ground
Halloween.GroundY = 0

local function at(x: number, z: number, y: number?): Vector3
	return Vector3.new(O.X + x, O.Y + (y or 0), O.Z + z)
end
Halloween.At = at

-- ---------------------------------------------------------------- travel
-- Main-world portal (east of the Slop Line, by the Chaos Rift) and the island
-- arrival. Spawns sit a few studs in front of each portal so nobody lands inside one.
Halloween.MainPortal = { pos = Vector3.new(150, 0, -60), facing = Vector3.new(-1, 0, 0) }
Halloween.MainArrival = Vector3.new(128, 3, -60)
Halloween.IslandPortal = { pos = at(0, -132), facing = Vector3.new(0, 0, 1) }
Halloween.IslandArrival = at(0, -106, 3)
Halloween.PlazaArrival = Vector3.new(0, 3, -26) -- "Belt" shortcut (in front of the Slop Line)
Halloween.TravelCooldown = 4

-- ----------------------------------------------------------------- areas
-- Rectangles in world x/z. Locked areas are fenced; the gate is walk-through
-- only for players at the level (client collision) and the server moves
-- under-level players back out to the gate (so nobody can skip it).
Halloween.Areas = {
	{ key = "Village", name = "Halloween Village", level = 1, min = at(-70, -150), max = at(70, 150), color = Color3.fromRGB(255, 140, 40),
		blurb = "The event hub: the Great Pumpkin, the Candy Shop and the Quest Board." },
	{ key = "Pumpkin", name = "Pumpkin Patch", level = 1, min = at(-190, -150), max = at(-70, 10), gate = at(-70, -60), color = Color3.fromRGB(255, 138, 31),
		blurb = "Cosy pumpkins and the friendliest Halloween Goobers." },
	{ key = "Forest", name = "Haunted Forest", level = 8, min = at(70, -150), max = at(190, 10), gate = at(70, -60), color = Color3.fromRGB(91, 255, 160),
		blurb = "Glowing mushrooms, twisted trees - and rarer Goobers." },
	{ key = "Graveyard", name = "Cursed Graveyard", level = 15, min = at(-190, 10), max = at(-70, 150), gate = at(-70, 70), color = Color3.fromRGB(150, 140, 190),
		blurb = "Spooky Goobers rise from the graves. Epic and Legendary finds." },
	{ key = "Castle", name = "Phantom Castle", level = 25, min = at(70, 10), max = at(190, 150), gate = at(70, 70), color = Color3.fromRGB(176, 75, 255),
		blurb = "The Phantom King's domain. Secret Goobers lurk here." },
}
Halloween.AreaByKey = {}
for _, a in ipairs(Halloween.Areas) do
	Halloween.AreaByKey[a.key] = a
end

-- ------------------------------------------------------------ spooky lines
-- Extra conveyor lines (merged into Config.Lines by Config). Odds are
-- percentages summing to 100; each line only rolls Halloween Goobers.
Halloween.Lines = {
	Pumpkin = {
		weights = { Common = 62, Uncommon = 30, Rare = 7, Epic = 1, Legendary = 0, Secret = 0 },
		interval = 3.0, speed = 6, levelRequired = 1, area = "Pumpkin", pool = "Halloween",
		startX = O.X - 172, endX = O.X - 82, z = O.Z - 62,
	},
	Forest = {
		weights = { Common = 20, Uncommon = 45, Rare = 28, Epic = 6.5, Legendary = 0.5, Secret = 0 },
		interval = 4.0, speed = 6, levelRequired = 8, area = "Forest", pool = "Halloween",
		startX = O.X + 172, endX = O.X + 82, z = O.Z - 62,
	},
	Graveyard = {
		weights = { Common = 0, Uncommon = 25, Rare = 42, Epic = 25, Legendary = 7.5, Secret = 0.5 },
		interval = 5.5, speed = 5, levelRequired = 15, area = "Graveyard", pool = "Halloween",
		startX = O.X - 172, endX = O.X - 82, z = O.Z + 62,
	},
	Castle = {
		weights = { Common = 0, Uncommon = 0, Rare = 35, Epic = 40, Legendary = 21, Secret = 4 },
		interval = 8.0, speed = 5, levelRequired = 25, area = "Castle", pool = "Halloween",
		startX = O.X + 172, endX = O.X + 82, z = O.Z + 62,
	},
}
Halloween.LineOrder = { "Pumpkin", "Forest", "Graveyard", "Castle" }

-- ----------------------------------------------------------------- candy
-- 30 hidden candies (each found once per player) + candy buckets that refill.
Halloween.CandyValue = 10
Halloween.CandyXP = 20
Halloween.CandyRadius = 9 -- how close (studs) the server requires the player to be
Halloween.Candies = {
	-- village
	{ id = "C01", pos = at(-52, -128, 2) }, { id = "C02", pos = at(55, -110, 2) }, { id = "C03", pos = at(-20, 40, 2) },
	{ id = "C04", pos = at(38, 92, 2) }, { id = "C05", pos = at(-60, 130, 2) }, { id = "C06", pos = at(0, 138, 2) },
	{ id = "C07", pos = at(62, 20, 2) }, { id = "C08", pos = at(-46, -10, 2) },
	-- pumpkin patch
	{ id = "C09", pos = at(-180, -140, 2) }, { id = "C10", pos = at(-120, -20, 2) }, { id = "C11", pos = at(-95, -130, 2) },
	{ id = "C12", pos = at(-150, -95, 2) }, { id = "C13", pos = at(-176, -30, 2) }, { id = "C14", pos = at(-84, -100, 2) },
	-- haunted forest
	{ id = "C15", pos = at(180, -140, 2) }, { id = "C16", pos = at(120, -20, 2) }, { id = "C17", pos = at(96, -128, 2) },
	{ id = "C18", pos = at(150, -100, 2) }, { id = "C19", pos = at(178, -30, 2) }, { id = "C20", pos = at(88, -95, 2) },
	-- cursed graveyard
	{ id = "C21", pos = at(-178, 140, 2) }, { id = "C22", pos = at(-120, 120, 2) }, { id = "C23", pos = at(-96, 30, 2) },
	{ id = "C24", pos = at(-160, 100, 2) }, { id = "C25", pos = at(-180, 30, 2) },
	-- phantom castle
	{ id = "C26", pos = at(178, 140, 2) }, { id = "C27", pos = at(105, 128, 2) }, { id = "C28", pos = at(96, 30, 2) },
	{ id = "C29", pos = at(180, 30, 2) }, { id = "C30", pos = at(140, 92, 2) },
}
Halloween.CandyById = {}
for _, c in ipairs(Halloween.Candies) do
	Halloween.CandyById[c.id] = c
end

Halloween.Buckets = {
	{ id = "B1", pos = at(-26, -84, 0) }, { id = "B2", pos = at(26, -84, 0) },
	{ id = "B3", pos = at(-120, -110, 0) }, { id = "B4", pos = at(120, -110, 0) },
	{ id = "B5", pos = at(-120, 100, 0) }, { id = "B6", pos = at(120, 100, 0) },
}
Halloween.BucketById = {}
for _, b in ipairs(Halloween.Buckets) do
	Halloween.BucketById[b.id] = b
end
Halloween.BucketCandy = 4
Halloween.BucketXP = 5
Halloween.BucketCooldown = 300 -- per player, per bucket

-- ------------------------------------------------------------ event track
Halloween.MaxEventLevel = 25
function Halloween.EventXPFor(level: number): number -- XP to go from `level` to `level + 1`
	return 60 + 25 * level
end
-- event XP for bringing a Halloween Goober home (snag+drop can't farm it)
Halloween.PlaceXP = { Common = 15, Uncommon = 30, Rare = 60, Epic = 120, Legendary = 250, Secret = 500 }

-- reward kinds: candy (n), coins (n = seconds of your income, min 1000), boost
-- (seconds of 2x income), goober (id), title (text)
Halloween.Track = {
	[1] = { kind = "candy", n = 30 },
	[2] = { kind = "coins", n = 120 },
	[3] = { kind = "candy", n = 40 },
	[4] = { kind = "boost", n = 300 },
	[5] = { kind = "goober", id = "H03_BooBlob" },
	[6] = { kind = "candy", n = 60 },
	[7] = { kind = "coins", n = 240 },
	[8] = { kind = "title", text = "Trick-or-Treater" },
	[9] = { kind = "candy", n = 80 },
	[10] = { kind = "goober", id = "H05_Midnight" },
	[11] = { kind = "boost", n = 600 },
	[12] = { kind = "coins", n = 480 },
	[13] = { kind = "candy", n = 120 },
	[14] = { kind = "goober", id = "H08_Zomblob" },
	[15] = { kind = "title", text = "Pumpkin Prince" },
	[16] = { kind = "coins", n = 720 },
	[17] = { kind = "candy", n = 160 },
	[18] = { kind = "boost", n = 900 },
	[19] = { kind = "goober", id = "H11_ScarecrowSam" },
	[20] = { kind = "candy", n = 220 },
	[21] = { kind = "coins", n = 1200 },
	[22] = { kind = "goober", id = "H13_DollyDread" },
	[23] = { kind = "boost", n = 1800 },
	[24] = { kind = "candy", n = 400 },
	[25] = { kind = "goober", id = "H16_GrimGoober", title = "Lord of Halloween" },
}

-- ------------------------------------------------------------ event shop
Halloween.Shop = {
	{ key = "Boost10", name = "Spooky Boost", desc = "2x income for 10 minutes", price = 120, kind = "boost", n = 600 },
	{ key = "PumpkinPip", name = "Pumpkin Pip", desc = "A Common Halloween Goober, delivered to your base", price = 60, kind = "goober", id = "H01_PumpkinPip" },
	{ key = "BatBrat", name = "Bat Brat", desc = "An Uncommon Halloween Goober", price = 180, kind = "goober", id = "H04_BatBrat" },
	{ key = "Hex", name = "Hex", desc = "A Rare Halloween Goober", price = 600, kind = "goober", id = "H09_Hex" },
	{ key = "CountGoobula", name = "Count Goobula", desc = "An Epic Halloween Goober", price = 1800, kind = "goober", id = "H10_CountGoobula" },
	{ key = "Coins", name = "Bag of Slop", desc = "10 minutes of your income in coins", price = 90, kind = "coins", n = 600 },
}
Halloween.ShopByKey = {}
for _, it in ipairs(Halloween.Shop) do
	Halloween.ShopByKey[it.key] = it
end

-- ----------------------------------------------------- halloween collection
Halloween.DexRewards = {
	{ count = 4, candy = 100, title = nil },
	{ count = 8, candy = 300, boost = 900, title = "Ghost Hunter" },
	{ count = 12, candy = 600, boost = 1800, title = "Monster Keeper" },
	{ count = 16, candy = 1500, boost = 3600, title = "Phantom Collector" },
}

-- ------------------------------------------------------------------ quests
-- Quest goals ("type"):
--   visit       : arrive on Halloween Island
--   area        : walk into area `area`
--   halloween   : bring `n` Halloween Goobers home (rarity >= `rarity` if set)
--   candy       : find `n` hidden candies
--   bucket      : grab candy from `n` buckets
--   eventlevel  : reach event level `n`
--   snag        : bring `n` Goobers of any kind home
--   collect     : collect `n` coins from your Cash Pad
--   steal       : steal `n` Goobers
-- Rewards: candy, coins (seconds of income), xp (player XP), exp (event XP)
Halloween.QuestChain = {
	{ type = "visit", n = 1, text = "Step through the Spooky Portal", hint = "The glowing purple portal is by the Slop Vat, east of the belts.", reward = { candy = 20, exp = 40 } },
	{ type = "halloween", n = 1, text = "Bring a Halloween Goober home", hint = "Snag one off the Pumpkin Patch belt and walk it back through the portal.", reward = { candy = 30, exp = 60 } },
	{ type = "candy", n = 3, text = "Find 3 hidden candies", hint = "Wrapped candies are hidden all over the island. Look behind things!", reward = { candy = 30, exp = 60 } },
	{ type = "bucket", n = 2, text = "Grab candy from 2 Candy Buckets", hint = "Pumpkin buckets refill every 5 minutes.", reward = { candy = 25, exp = 50 } },
	{ type = "halloween", n = 5, text = "Bring 5 Halloween Goobers home", hint = "Every Halloween Goober you bring home gives Event XP too.", reward = { candy = 50, coins = 300, exp = 100 } },
	{ type = "eventlevel", n = 5, text = "Reach Event Level 5", hint = "Open the Halloween menu to claim your track rewards.", reward = { candy = 50, exp = 80 } },
	{ type = "area", area = "Forest", n = 1, text = "Enter the Haunted Forest", hint = "The Haunted Forest gate opens at player Level 8.", reward = { candy = 60, exp = 120 } },
	{ type = "candy", n = 12, text = "Find 12 hidden candies", hint = "Each area hides its own candies.", reward = { candy = 80, exp = 150 } },
	{ type = "halloween", n = 1, rarity = "Epic", text = "Bring home an Epic Halloween Goober", hint = "The Forest and Graveyard belts roll more Epics.", reward = { candy = 120, coins = 900, exp = 200 } },
	{ type = "area", area = "Graveyard", n = 1, text = "Enter the Cursed Graveyard", hint = "Unlocks at player Level 15.", reward = { candy = 150, exp = 250 } },
	{ type = "eventlevel", n = 15, text = "Reach Event Level 15", hint = "Keep collecting candy and Halloween Goobers.", reward = { candy = 200, exp = 300 } },
	{ type = "candy", n = 30, text = "Find all 30 hidden candies", hint = "Some are tucked away in the Graveyard and the Castle.", reward = { candy = 500, coins = 3600, exp = 600 } },
}

-- daily quests: 3 a day, picked from this pool (same three for everyone on a given UTC day)
Halloween.DailyPool = {
	{ id = "d_snag", type = "snag", n = 8, text = "Bring 8 Goobers home", reward = { candy = 25, coins = 180, exp = 40 } },
	{ id = "d_hal", type = "halloween", n = 4, text = "Bring 4 Halloween Goobers home", reward = { candy = 35, exp = 70 } },
	{ id = "d_bucket", type = "bucket", n = 3, text = "Grab candy from 3 Candy Buckets", reward = { candy = 30, exp = 50 } },
	{ id = "d_collect", type = "collect", n = 1, scale = 300, text = "Collect 5 minutes of income from your Cash Pad", reward = { candy = 20, coins = 120, exp = 40 } },
	{ id = "d_rare", type = "halloween", n = 1, rarity = "Rare", text = "Bring home a Rare+ Halloween Goober", reward = { candy = 40, exp = 80 } },
	{ id = "d_steal", type = "steal", n = 1, text = "Steal a Goober from another base", reward = { candy = 30, coins = 240, exp = 60 } },
}
Halloween.DailyCount = 3

-- --------------------------------------------------------- level milestones
-- Claimable from the Progression screen (player level, not event level).
Halloween.LevelMilestones = {
	{ level = 3, text = "Stealing unlocked", reward = { candy = 20 } },
	{ level = 5, text = "Base Lock upgrades", reward = { candy = 30, coins = 300 } },
	{ level = 8, text = "Haunted Forest opens", reward = { candy = 50 } },
	{ level = 10, text = "Gold Line unlocked", reward = { candy = 60, coins = 600 } },
	{ level = 15, text = "Cursed Graveyard opens + Rebirth", reward = { candy = 100, boost = 900 } },
	{ level = 20, text = "Big Goober boss", reward = { candy = 150, coins = 1200 } },
	{ level = 25, text = "Phantom Castle opens", reward = { candy = 250, boost = 1800 } },
	{ level = 30, text = "Goober tycoon", reward = { candy = 300, coins = 2400 } },
	{ level = 40, text = "Slop legend", reward = { candy = 500, boost = 3600 } },
	{ level = 50, text = "Goober royalty", reward = { candy = 1000, coins = 7200 } },
}

-- ------------------------------------------------------------------ looks
Halloween.Night = {
	ClockTime = 0.6,
	Brightness = 1.6,
	Ambient = Color3.fromRGB(70, 45, 95),
	OutdoorAmbient = Color3.fromRGB(95, 60, 120),
	FogColor = Color3.fromRGB(40, 22, 60),
	FogStart = 80,
	FogEnd = 420,
	ColorShift = Color3.fromRGB(255, 140, 60),
}

return Halloween

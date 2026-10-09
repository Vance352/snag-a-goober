--[[
	GooberData - the launch roster. Model files live in
	Assets/BlenderSource/scripts/goobers.py under the same ids.

	income = Slop Coins per second (before multipliers)
	price  = Slop Coins to snag it when the Goober Breach spits it out
	anim   = idle animation style used by the client animator
	eventOnly = only spawns during a CHAOS RIFT event
	pool   = which conveyors can roll it: "Classic" (the Slop and Gold lines) or
	         "Halloween" (the Halloween Island lines). Defaults to Classic.
]]

export type Goober = {
	id: string,
	name: string,
	rarity: string,
	income: number,
	price: number,
	height: number,
	anim: string,
	blurb: string,
	eventOnly: boolean?,
	pool: string?,
	order: number,
}

local list: { Goober } = {
	-- Common
	{ id = "G01_Blorp", name = "Blorp", rarity = "Common", income = 1, price = 10, height = 2.2, anim = "wobble", blurb = "Its eyes have never agreed on anything." },
	{ id = "G02_SirPuddle", name = "Sir Puddle", rarity = "Common", income = 2, price = 25, height = 1.9, anim = "slide", blurb = "A gentleman. A puddle. A gentleman puddle." },
	{ id = "G03_Toastie", name = "Toastie", rarity = "Common", income = 2, price = 30, height = 2.4, anim = "hop", blurb = "Lightly toasted. Heavily confident." },
	{ id = "G04_Gumbo", name = "Gumbo", rarity = "Common", income = 3, price = 45, height = 2.1, anim = "bounce", blurb = "Chewed on once. Never forgot." },
	{ id = "G05_PebblePete", name = "Pebble Pete", rarity = "Common", income = 3, price = 50, height = 1.9, anim = "sleepy", blurb = "Has been napping since the Stone Age." },
	{ id = "G06_Nugget", name = "Nugget", rarity = "Common", income = 4, price = 70, height = 2.2, anim = "waddle", blurb = "Wears its dipping sauce with pride." },
	-- Uncommon
	{ id = "G07_Wobblesworth", name = "Wobblesworth", rarity = "Uncommon", income = 8, price = 200, height = 2.9, anim = "jelly", blurb = "Cannot stop wobbling. Has tried." },
	{ id = "G08_ConeHead", name = "Cone Head", rarity = "Uncommon", income = 10, price = 280, height = 3.0, anim = "waddle", blurb = "Found a traffic cone. Became the traffic cone." },
	{ id = "G09_Snorkel", name = "Snorkel", rarity = "Uncommon", income = 12, price = 350, height = 2.4, anim = "swim", blurb = "Always ready for a swim. Has never seen water." },
	{ id = "G10_Mushy", name = "Mushy", rarity = "Uncommon", income = 14, price = 450, height = 2.6, anim = "bounce", blurb = "A fun guy. Literally." },
	{ id = "G11_BeanBoi", name = "Bean Boi", rarity = "Uncommon", income = 16, price = 550, height = 2.6, anim = "wave", blurb = "Waves at everyone. Everyone." },
	-- Rare
	{ id = "G12_CaptainSpork", name = "Captain Spork", rarity = "Rare", income = 35, price = 1_500, height = 3.0, anim = "waddle", blurb = "Sails the seven sauces." },
	{ id = "G13_Fluffernaut", name = "Fluffernaut", rarity = "Rare", income = 45, price = 2_200, height = 2.8, anim = "float", blurb = "One small fluff for goober-kind." },
	{ id = "G14_DiscoDan", name = "Disco Dan", rarity = "Rare", income = 55, price = 3_000, height = 2.9, anim = "dance", blurb = "Brings his own lighting." },
	{ id = "G15_Chonk", name = "Chonk", rarity = "Rare", income = 65, price = 3_800, height = 2.6, anim = "sleepy", blurb = "Absolute unit. Doesn't move for less than a snack." },
	{ id = "G16_BubblesMcGee", name = "Bubbles McGee", rarity = "Rare", income = 80, price = 5_000, height = 2.7, anim = "bounce", blurb = "Do not pop. Please do not pop." },
	-- Epic
	{ id = "G17_GrandpaGoob", name = "Grandpa Goob", rarity = "Epic", income = 200, price = 18_000, height = 3.0, anim = "shuffle", blurb = "Back in his day, conveyors went uphill both ways." },
	{ id = "G18_MoaiGoob", name = "Moai Goob", rarity = "Epic", income = 260, price = 26_000, height = 3.4, anim = "stoic", blurb = "Has seen ten thousand sunsets. Unimpressed by all." },
	{ id = "G19_OctoGoob", name = "Octo Goob", rarity = "Epic", income = 330, price = 36_000, height = 3.0, anim = "swim", blurb = "Six arms. Calls itself Octo anyway." },
	{ id = "G20_SlimeKing", name = "Slime King", rarity = "Epic", income = 420, price = 50_000, height = 3.3, anim = "jelly", blurb = "Ruler of all things sticky." },
	-- Legendary
	{ id = "G21_Gooberzilla", name = "Gooberzilla", rarity = "Legendary", income = 1_200, price = 200_000, height = 3.6, anim = "stomp", blurb = "Terror of the tiny city. About ankle height." },
	{ id = "G22_GoldenNugget", name = "The Golden Nugget", rarity = "Legendary", income = 1_600, price = 300_000, height = 3.2, anim = "spin", blurb = "Worth its weight in itself." },
	{ id = "G23_WizardGoob", name = "Wizard Goob", rarity = "Legendary", income = 2_000, price = 420_000, height = 3.8, anim = "float", blurb = "Knows one spell. It's this one." },
	-- Secret
	{ id = "G24_Glitch", name = "Glitch", rarity = "Secret", income = 6_000, price = 1_500_000, height = 2.8, anim = "jitter", blurb = "Not supposed to exist. Please report to nobody." },
	{ id = "G25_ChaosGoob", name = "Chaos Goob", rarity = "Secret", income = 8_000, price = 2_500_000, height = 3.4, anim = "float", blurb = "Only slips through during a Chaos Rift.", eventOnly = true },

	-- ===================== HALLOWEEN UPDATE (Halloween Island lines) =====================
	-- ~10% faster payback than the matching classic tier, so the trip is worth it
	-- without making the original collection worthless.
	-- Common
	{ id = "H01_PumpkinPip", name = "Pumpkin Pip", rarity = "Common", income = 3, price = 40, height = 2.0, anim = "bounce", blurb = "Small, round, and fully convinced it's the Great Pumpkin.", pool = "Halloween" },
	{ id = "H02_CandyCorny", name = "Candy Corny", rarity = "Common", income = 4, price = 55, height = 2.9, anim = "hop", blurb = "Three flavours. All of them are 'sugar'.", pool = "Halloween" },
	{ id = "H03_BooBlob", name = "Boo Blob", rarity = "Common", income = 5, price = 72, height = 2.5, anim = "float", blurb = "Tries to be scary. Mostly waves.", pool = "Halloween" },
	-- Uncommon
	{ id = "H04_BatBrat", name = "Bat Brat", rarity = "Uncommon", income = 13, price = 360, height = 2.6, anim = "float", blurb = "Hangs upside down to think. Thinks about snacks.", pool = "Halloween" },
	{ id = "H05_Midnight", name = "Midnight", rarity = "Uncommon", income = 16, price = 470, height = 2.3, anim = "waddle", blurb = "Crosses your path on purpose. For luck. Probably.", pool = "Halloween" },
	{ id = "H06_MummyWrap", name = "Mummy Wrap", rarity = "Uncommon", income = 19, price = 580, height = 2.4, anim = "shuffle", blurb = "Ten thousand years old. Still loses its bandage.", pool = "Halloween" },
	-- Rare
	{ id = "H07_Bonejangles", name = "Bonejangles", rarity = "Rare", income = 50, price = 2_400, height = 3.0, anim = "wave", blurb = "Dances like nobody's watching. Has no eyes, so nobody is.", pool = "Halloween" },
	{ id = "H08_Zomblob", name = "Zomblob", rarity = "Rare", income = 70, price = 3_600, height = 2.4, anim = "shuffle", blurb = "Wants brains. Will settle for slop.", pool = "Halloween" },
	{ id = "H09_Hex", name = "Hex", rarity = "Rare", income = 90, price = 5_000, height = 3.2, anim = "float", blurb = "Her only spell turns frowns into Goober grins.", pool = "Halloween" },
	-- Epic
	{ id = "H10_CountGoobula", name = "Count Goobula", rarity = "Epic", income = 240, price = 22_000, height = 2.7, anim = "stoic", blurb = "Vants to snag your slop. Ah ah ah.", pool = "Halloween" },
	{ id = "H11_ScarecrowSam", name = "Scarecrow Sam", rarity = "Epic", income = 340, price = 34_000, height = 3.2, anim = "wobble", blurb = "Terrible at scaring crows. The crow is his best friend.", pool = "Halloween" },
	{ id = "H12_LanternLurker", name = "Lantern Lurker", rarity = "Epic", income = 460, price = 50_000, height = 3.0, anim = "float", blurb = "A cursed flame that just wants a warm hug.", pool = "Halloween" },
	-- Legendary
	{ id = "H13_DollyDread", name = "Dolly Dread", rarity = "Legendary", income = 1_500, price = 250_000, height = 3.1, anim = "jitter", blurb = "Her eyes follow you. They're buttons. How?", pool = "Halloween" },
	{ id = "H14_HeadlessGoobman", name = "Headless Goobman", rarity = "Legendary", income = 2_200, price = 400_000, height = 3.0, anim = "stomp", blurb = "Lost his head once. Now he carries it everywhere.", pool = "Halloween" },
	-- Secret
	{ id = "H15_PhantomKing", name = "Phantom King", rarity = "Secret", income = 5_000, price = 1_300_000, height = 3.6, anim = "float", blurb = "Rules the Phantom Castle. Mostly from the ceiling.", pool = "Halloween" },
	{ id = "H16_GrimGoober", name = "Grim Goober", rarity = "Secret", income = 6_000, price = 1_600_000, height = 3.4, anim = "float", blurb = "It's not here for you. It's here for your Goobers' bedtime.", pool = "Halloween" },
}

local GooberData = {}
GooberData.List = list
GooberData.ById = {}
GooberData.ByRarity = {} -- classic pool only (the Slop and Gold lines)
GooberData.ByPool = { Classic = {}, Halloween = {} } -- pool -> rarity -> { Goober }
GooberData.PoolList = { Classic = {}, Halloween = {} } -- pool -> every Goober in it (Dex tabs)

for i, g in ipairs(list) do
	g.order = i
	g.pool = g.pool or "Classic"
	GooberData.ById[g.id] = g
	table.insert(GooberData.PoolList[g.pool], g)
	if not g.eventOnly then
		local byRarity = GooberData.ByPool[g.pool]
		byRarity[g.rarity] = byRarity[g.rarity] or {}
		table.insert(byRarity[g.rarity], g)
	end
end
GooberData.ByRarity = GooberData.ByPool.Classic

GooberData.Count = #list
GooberData.ClassicCount = #GooberData.PoolList.Classic
GooberData.HalloweenCount = #GooberData.PoolList.Halloween

return GooberData

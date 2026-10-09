--[[
	GooberData - the launch roster. Model files live in
	Assets/BlenderSource/scripts/goobers.py under the same ids.

	income = Slop Coins per second (before multipliers)
	price  = Slop Coins to snag it off the conveyor
	anim   = idle animation style used by the client animator
	eventOnly = only spawns during a CHAOS RIFT event
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
}

local GooberData = {}
GooberData.List = list
GooberData.ById = {}
GooberData.ByRarity = {}

for i, g in ipairs(list) do
	g.order = i
	GooberData.ById[g.id] = g
	GooberData.ByRarity[g.rarity] = GooberData.ByRarity[g.rarity] or {}
	if not g.eventOnly then
		table.insert(GooberData.ByRarity[g.rarity], g)
	end
end

GooberData.Count = #list

return GooberData

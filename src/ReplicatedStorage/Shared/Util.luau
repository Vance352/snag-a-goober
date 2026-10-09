--[[
	Util - small shared helpers: number formatting, odds maths, economy formulas.
	Odds and income formulas live here so the store/odds UI always shows exactly
	what the server uses.
]]

local Config = require(script.Parent.Config)

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Util.Short(n: number): string
	n = math.floor(n + 0.5)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s
	if math.abs(v) >= 100 then
		s = string.format("%d", math.floor(v))
	elseif math.abs(v) >= 10 then
		s = string.format("%.1f", math.floor(v * 10) / 10)
	else
		s = string.format("%.2f", math.floor(v * 100) / 100)
	end
	if s:find("%.") then
		s = s:gsub("0+$", "")
		s = s:gsub("%.$", "")
	end
	return s .. SUFFIXES[i]
end

function Util.Comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function Util.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = seconds // 60
	local s = seconds % 60
	if m >= 48 * 60 then
		return string.format("%dd %dh", m // 1440, (m % 1440) // 60)
	elseif m >= 60 then
		return string.format("%dh %02dm", m // 60, m % 60)
	end
	return string.format("%d:%02d", m, s)
end

-- Odds for a line given a luck multiplier. Returns { [rarity] = percent }.
function Util.Odds(lineName: string, luck: number, secretMult: number?): { [string]: number }
	local line = Config.Lines[lineName]
	local raw = {}
	local total = 0
	for _, rarity in ipairs(Config.RarityOrder) do
		local w = line.weights[rarity] or 0
		if Config.LuckyRarities[rarity] then
			w *= luck
		end
		if rarity == "Secret" and secretMult then
			w *= secretMult
		end
		raw[rarity] = w
		total += w
	end
	local out = {}
	for rarity, w in pairs(raw) do
		out[rarity] = if total > 0 then w / total * 100 else 0
	end
	return out
end

function Util.UpgradeCost(def, level: number): number
	return math.floor(def.baseCost * def.growth ^ level)
end

function Util.UpgradeByKey(key: string)
	for _, def in ipairs(Config.Upgrades) do
		if def.key == key then
			return def
		end
	end
	return nil
end

-- Income multiplier from upgrades/rebirths/passes/boost.
function Util.IncomeMultiplier(incomeLevel: number, rebirths: number, doubleCoins: boolean, boosted: boolean): number
	local m = (1 + Config.IncomePerLevel * incomeLevel) * (1 + Config.Rebirth.incomeBonus * rebirths)
	if doubleCoins then
		m *= 2
	end
	if boosted then
		m *= 2
	end
	return m
end

function Util.Capacity(slotsLevel: number, rebirths: number, extraSlotsPass: boolean): number
	local cap = Config.BaseSlots
		+ slotsLevel
		+ math.min(rebirths * Config.Rebirth.extraSlot, Config.Rebirth.maxExtraSlots)
		+ (if extraSlotsPass then Config.ExtraSlotsPass else 0)
	return math.min(cap, Config.MaxStands)
end

function Util.PersonalLuck(rebirths: number, lucky: boolean): number
	local pd = Config.PersonalDrop
	return pd.baseLuck + math.min(rebirths * pd.luckPerRebirth, pd.maxRebirthLuck) + (if lucky then pd.luckyPassLuck else 0)
end

function Util.WalkSpeed(speedLevel: number, sprintBoots: boolean): number
	return Config.BaseWalkSpeed + Config.SpeedPerLevel * speedLevel + (if sprintBoots then Config.SprintBootsBonus else 0)
end

function Util.ProductCoins(productKey: string, incomePerSec: number): number
	local p = Config.Products[productKey]
	if not p or not p.minutes then
		return 0
	end
	return math.max(p.minCoins, math.floor(incomePerSec * p.minutes * 60))
end

return Util

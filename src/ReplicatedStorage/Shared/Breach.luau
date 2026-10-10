--[[
	Breach - the Goober Breach (replaces the old conveyor belts).

	A Breach is an unstable dimensional reactor. It charges up in stages
	(Charging -> Unstable -> BLAST), then flings a burst of Goobers across its
	field. They land and wait to be snagged; rarer ones keep hopping around,
	so they have to be chased. Unsnagged Goobers dive back into the Breach
	when their time is up.

	The server never moves a loose Goober. Each one carries its whole flight
	and hop plan (the "path"), so its position is a pure function of time:
	clients animate it with PositionAt and the server validates snags with
	the same function. Halloween Island's cauldrons are smaller breaches.
]]

local Breach = {}

-- --------------------------------------------------------------- timing
Breach.Stages = {
	{ key = "Cooldown", seconds = 3 },
	{ key = "Charging", seconds = 8 }, -- rings spin up, energy gathers
	{ key = "Unstable", seconds = 3 }, -- sparks, shaking, alarm
	{ key = "Blast", seconds = 1.5 }, -- Goobers fly
}
Breach.FlightMin = 0.9
Breach.HopTime = 0.45 -- seconds a hop takes
Breach.HopHeight = 3.2
Breach.Life = { Common = 38, Uncommon = 40, Rare = 42, Epic = 45, Legendary = 50, Secret = 55 } -- seconds on the ground
-- how often a Goober hops to a new spot (nil = sits still). Rare ones are slippery.
Breach.HopEvery = { Rare = { 4.5, 6 }, Epic = { 3.2, 4.5 }, Legendary = { 2.6, 3.6 }, Secret = { 2.2, 3.0 } }
Breach.HopDistance = { 7, 12 }
Breach.DropLife = 20 -- seconds a knocked-loose Goober stays grabbable
Breach.DropLockout = 1.0 -- the carrier who dropped it AND whoever blasted it can't grab for this long
Breach.DropSnagRange = 8 -- dropped Goobers must be reached (a real race, not a click from afar)
Breach.DropDistance = 11 -- a blasted Goober flies this far, off to the side of the shot

-- blast types for the main Breach (picked each cycle); weight = how often
Breach.Types = {
	Slop = { weight = 60, title = "SLOP SURGE", color = Color3.fromRGB(123, 227, 90), spawns = { Main = 5 } },
	Gold = { weight = 28, title = "GOLD RUSH", color = Color3.fromRGB(255, 201, 60), spawns = { Gold = 3, Main = 2 } },
	Rift = { weight = 12, title = "RARE RIFT", color = Color3.fromRGB(190, 90, 255), spawns = { Main = 4 }, luck = 4, announce = true },
}
Breach.TypeOrder = { "Slop", "Gold", "Rift" }

-- --------------------------------------------------------------- sites
-- center: the Breach's base position; mouth: where Goobers launch from (offset);
-- field: rectangle (x0, x1, z0, z1) Goobers land in; avoid: radius kept clear
-- around the center (the machine itself).
Breach.Sites = {
	Central = {
		center = Vector3.new(0, 0, 0),
		mouth = Vector3.new(0, 17, 0),
		field = { -104, 104, -26, 26 }, -- (stays 13+ studs clear of the plot doors)
		avoid = 21,
		types = true, -- uses Breach.Types
		personalDrops = true,
	},
}

-- Halloween Island cauldrons (filled in from Shared/Halloween)
do
	local ok, Halloween = pcall(require, script.Parent.Halloween)
	if ok and Halloween.Enabled then
		for name, line in pairs(Halloween.Lines) do
			local area = Halloween.AreaByKey[line.area]
			local inset = 10
			Breach.Sites[name] = {
				center = line.site,
				mouth = Vector3.new(0, 5, 0),
				field = { area.min.X + inset, area.max.X - inset, area.min.Z + inset, area.max.Z - inset },
				avoid = 8,
				line = name,
				count = line.count,
				cycleMult = line.cycleMult or 1,
				spooky = true,
			}
		end
	end
end

-- ----------------------------------------------------------------- path
-- path = { t0, from: Vector3, flight, apex, y, pts = { {x, z, t} ... } }
-- pts[1] is the landing spot (t = t0 + flight); each later point is a hop that
-- lands at its t (taking HopTime). The Goober leaves at path.expire.

local function arc(a: Vector3, b: Vector3, h: number, u: number): Vector3
	local p = a:Lerp(b, u)
	return p + Vector3.new(0, h * 4 * u * (1 - u), 0)
end

function Breach.PositionAt(path, t: number): (Vector3, boolean)
	-- returns the position and whether the Goober is on the ground (snaggable)
	local pts = path.pts
	if t <= path.t0 then
		return path.from, false
	end
	local land = pts[1]
	if t < land[3] then
		local u = (t - path.t0) / path.flight
		return arc(path.from, Vector3.new(land[1], path.y, land[2]), path.apex, math.clamp(u, 0, 1)), false
	end
	local i = 1
	while pts[i + 1] and pts[i + 1][3] <= t do
		i += 1
	end
	local p = pts[i]
	local nxt = pts[i + 1]
	if nxt and t > nxt[3] - Breach.HopTime then
		local u = 1 - (nxt[3] - t) / Breach.HopTime
		return arc(Vector3.new(p[1], path.y, p[2]), Vector3.new(nxt[1], path.y, nxt[2]), Breach.HopHeight, math.clamp(u, 0, 1)), true
	end
	return Vector3.new(p[1], path.y, p[2]), true
end

-- compact string form for a model attribute: "x,z,t;x,z,t"
function Breach.EncodePts(pts): string
	local out = table.create(#pts)
	for i, p in ipairs(pts) do
		out[i] = string.format("%.2f,%.2f,%.3f", p[1], p[2], p[3])
	end
	return table.concat(out, ";")
end

function Breach.DecodePts(s: string)
	local pts = {}
	for chunk in string.gmatch(s or "", "[^;]+") do
		local x, z, t = string.match(chunk, "^([-%d%.]+),([-%d%.]+),([-%d%.]+)$")
		if x then
			table.insert(pts, { tonumber(x), tonumber(z), tonumber(t) })
		end
	end
	return pts
end

-- read the path a server-made model carries
function Breach.PathOf(model: Instance)
	local s = model:GetAttribute("PathPts")
	local cached = Breach._cache and Breach._cache[model]
	if cached and cached.s == s then
		return cached.path
	end
	local path = {
		t0 = model:GetAttribute("LaunchT") or 0,
		from = model:GetAttribute("LaunchFrom") or Vector3.zero,
		flight = model:GetAttribute("Flight") or 1,
		apex = model:GetAttribute("Apex") or 8,
		y = model:GetAttribute("GroundY") or 0,
		expire = model:GetAttribute("Expire") or math.huge,
		pts = Breach.DecodePts(s),
	}
	Breach._cache = Breach._cache or setmetatable({}, { __mode = "k" })
	Breach._cache[model] = { s = s, path = path }
	return path
end

return Breach

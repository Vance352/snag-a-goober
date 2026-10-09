--[[
	Leaderboards - the ranking categories (shared so the client can label them).
	Values are computed on the server from saved, server-controlled stats
	(LeaderboardService); the client never reports a score.
]]

local Leaderboards = {}

Leaderboards.Categories = {
	{ key = "Earners", title = "TOP EARNERS", stat = "Slop earned (all time)", icon = "coin", color = Color3.fromRGB(255, 201, 60), money = true },
	{ key = "Collected", title = "GOOBERS COLLECTED", stat = "Goobers brought home", icon = "stand", color = Color3.fromRGB(123, 227, 90) },
	{ key = "Thieves", title = "MASTER THIEVES", stat = "Goobers stolen (bases + Blaster)", icon = "bolt", color = Color3.fromRGB(255, 95, 120) },
	{ key = "Level", title = "HIGHEST LEVEL", stat = "Player level", icon = "trophy", color = Color3.fromRGB(150, 110, 255) },
	{ key = "Rare", title = "RARE COLLECTORS", stat = "Epic, Legendary and Secret Goobers found", icon = "book", color = Color3.fromRGB(255, 61, 165) },
}
Leaderboards.ByKey = {}
for _, c in ipairs(Leaderboards.Categories) do
	Leaderboards.ByKey[c.key] = c
end

Leaderboards.Size = 10 -- entries per board
Leaderboards.RefreshEvery = 90 -- seconds between global reads (per category)
Leaderboards.WriteEvery = 120 -- seconds between writing a player's scores

return Leaderboards

--[[
	Tutorial steps shared by server (which advances them on real gameplay
	events) and client (which shows the arrow + hint for the current step).
]]
local Tutorial = {}

Tutorial.Grab = 0 -- snag your first Goober off the belt
Tutorial.Home = 1 -- carry it into your base
Tutorial.Collect = 2 -- step on the Cash Pad
Tutorial.Upgrade = 3 -- buy any upgrade
Tutorial.Tips = 4 -- one-time tips card, acknowledged by the client
Tutorial.DONE = 99

Tutorial.Advance = {
	[0] = "Snagged",
	[1] = "Placed",
	[2] = "Collected",
	[3] = "Upgraded",
}

Tutorial.Hints = {
	[0] = "Grab a Goober off the conveyor!",
	[1] = "Bring it home to your base!",
	[2] = "Step on the Cash Pad to collect!",
	[3] = "Buy an upgrade at the Slop-O-Matic!",
}

return Tutorial

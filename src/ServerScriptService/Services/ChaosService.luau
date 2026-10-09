--[[
	ChaosService - GOOBER CHAOS events.

	Events run on a fixed clock schedule (every Config.Chaos.period seconds of
	server time, rotating through Config.Chaos.order) so the countdown shown to
	players is real and every server agrees. State is published as attributes
	on ReplicatedStorage for clients:
	  ChaosType (string or ""), ChaosEndsAt, ChaosNextAt, ChaosNextType
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ChaosService = {}
local S
local C = Config.Chaos

local current: string? = nil
local forced: { type: string, endsAt: number }? = nil

function ChaosService.Init(registry)
	S = registry
end

local function scheduleAt(t: number)
	local idx = math.floor(t / C.period)
	local start = idx * C.period
	local typ = C.order[(idx % #C.order) + 1]
	return idx, start, typ
end

function ChaosService.Active()
	return current and C.types[current] or nil
end

function ChaosService.ActiveName(): string?
	return current
end

-- Studio test hook: start an event right now.
function ChaosService.Force(typ: string, seconds: number?)
	assert(C.types[typ], "unknown chaos type")
	forced = { type = typ, endsAt = workspace:GetServerTimeNow() + (seconds or C.duration) }
end

function ChaosService.Start()
	task.spawn(function()
		while true do
			local t = workspace:GetServerTimeNow()
			local _, start, typ = scheduleAt(t)
			local active, endsAt = nil, 0
			if forced and t < forced.endsAt then
				active, endsAt = forced.type, forced.endsAt
			elseif t - start < C.duration then
				active, endsAt = typ, start + C.duration
			end
			local nextStart = start + C.period
			local _, _, nextType = scheduleAt(nextStart + 1)
			if active ~= current then
				current = active
				if active then
					local def = C.types[active]
					S.Session.Effect("ChaosStart", { type = active, title = def.title, desc = def.desc, endsAt = endsAt })
				else
					S.Session.Effect("ChaosEnd", {})
				end
			end
			ReplicatedStorage:SetAttribute("ChaosType", active or "")
			ReplicatedStorage:SetAttribute("ChaosEndsAt", endsAt)
			ReplicatedStorage:SetAttribute("ChaosNextAt", nextStart)
			ReplicatedStorage:SetAttribute("ChaosNextType", nextType)
			task.wait(0.5)
		end
	end)
end

return ChaosService

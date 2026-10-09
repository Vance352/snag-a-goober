--[[
	Hooks - a tiny in-process event bus so progression systems (quests, the
	Halloween event track) can react to gameplay without every service
	knowing about them.

	Events fired (all server-side, after the action is validated and done):
	  "placed"    (player, { id = gooberId, source = "belt" | "steal" | "reward" | "shop" })
	  "collected" (player, { amount = coins })
	  "stolen"    (player, { id = gooberId })
	  "candy"     (player, { id = candyId })
	  "bucket"    (player, { id = bucketId })
	  "area"      (player, { key = areaKey })
	  "visit"     (player, {})
	  "eventlevel"(player, { level = n })
]]

local Hooks = {}
local listeners: { [string]: { (Player, any) -> () } } = {}

function Hooks.On(kind: string, fn: (Player, any) -> ())
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
end

function Hooks.Fire(kind: string, player: Player, payload: any?)
	for _, fn in ipairs(listeners[kind] or {}) do
		local ok, err = pcall(fn, player, payload or {})
		if not ok then
			warn(("[Hooks %s] %s"):format(kind, tostring(err)))
		end
	end
end

return Hooks

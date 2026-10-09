--[[
	studio_sync.luau - pull src/ into the open Studio place.
	Paste into the command bar (or run via MCP execute_luau) while
	`python -m http.server 34873 --bind 127.0.0.1` runs at the repo root and
	after `python tools/make_manifest.py`.

	Safety (CLAUDE.md): each synced script stores the sha1 of the source it was
	written from (attribute SyncSha). If a script's current Source no longer
	matches what was synced (someone edited it in Studio), it is NOT
	overwritten; it is reported as "studio-edited" so it can be exported first.
	Set FORCE = true only after exporting those edits.
]]
local FORCE = false
local BASE = "http://127.0.0.1:34873/"
local HS = game:GetService("HttpService")

local function fetch(path)
	return HS:GetAsync(BASE .. path .. "?t=" .. tostring(os.clock()), true)
end

local manifest = HS:JSONDecode(fetch("tools/sync_manifest.json"))
local report = { written = 0, unchanged = 0, blocked = {}, created = 0 }

for _, e in ipairs(manifest.entries) do
	local parent: Instance = game:GetService(e.path[1])
	for i = 2, #e.path do
		local child = parent:FindFirstChild(e.path[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = e.path[i]
			child.Parent = parent
		end
		parent = child
	end
	local src = fetch(e.file)
	local existing = parent:FindFirstChild(e.name)
	if existing and existing.ClassName ~= e.class then
		existing:Destroy()
		existing = nil
	end
	if existing then
		local lastSha = existing:GetAttribute("SyncSha")
		local lastSrc = existing:GetAttribute("SyncLen")
		if lastSha == e.sha1 then
			report.unchanged += 1
			continue
		end
		-- Studio-side edit detection: Source length differs from what we wrote
		if lastSrc and #existing.Source ~= lastSrc and not FORCE then
			table.insert(report.blocked, existing:GetFullName())
			continue
		end
	else
		existing = Instance.new(e.class)
		existing.Name = e.name
		report.created += 1
	end
	existing.Source = src
	existing:SetAttribute("SyncSha", e.sha1)
	existing:SetAttribute("SyncLen", #existing.Source)
	existing:SetAttribute("SyncManaged", true)
	existing.Parent = parent
	report.written += 1
end

return HS:JSONEncode(report)

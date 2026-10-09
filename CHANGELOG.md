# Changelog

Newest entry at the top.

## 2026-10-08
- Two-player theft tests (6 paths) pass in a Studio local server; audio verified loading on a client. QA/test-log.md + QA/round1-audit.md.
- Moderation fix: Roblox rejected all 10 Eye meshes (false positive). Eyes/pupils now built from native Parts from Blender specs; no rejected mesh referenced; exports contain no eye meshes.
- Blender assets imported (226 meshes -> 25 Goober + 12 prop templates via tools/process_import.luau); map rebuilt with real meshes. Original SFX sprite + music wired in.
- QA round 1 fixes: server-side movement guard (teleport snag/steal blocked), server-timed steal hold + min carry time, AutoCollect XP/tutorial, save retries, pass-grant verification, 50%-off personal drops, XP on placement, gentler level rewards, compensation cooldown, pixel-size tags, bigger touch targets, entrance ramp, server size 8.
- Fix: saves never persisted (BindableEvent copied the data table); data handoff now uses callbacks. Verified save -> rejoin.
- Real gamepasses (6) and developer products (4) created on the Creator Hub; IDs wired in; shop shows live prices; receipt replay test passes.
- All 25 Goober models + 12 props built in Blender (code-generated, inspected), exported to FBX; original SFX sprite + music synthesized.
- Core game: conveyor, carrying, bases, income, Cash Pad, upgrades, levels, rebirth, stealing, Goober Chaos events, monetization service, UI, tutorial, map builder, Studio sync + test harness; first Blender pipeline models.
- Project created: folder layout, README, working rules.

# Changelog

Newest entry at the top.

## 2026-10-09
- QA round 7 fixes: teleport-sized violations (or flying) cancel a theft at once; debt forgiveness moves the player back to their last trusted spot instead of trusting where they are; lag bank only fills on a real stall pattern (frozen position + walking velocity), spends x1.5, capped at newest bank + 0.25 s, history re-bases after a catch-up burst; tutorial hint and toasts narrowed to clear the status column on phones. Round 7 audit in QA/round7-audit.md.
- QA round 6 fixes: MoveGuard checks every position against every trusted sample (no unchecked window after a reset, closes hop-and-back), debt measured against the whole frozen history, lag "bank" so 1.5 s freezes + bursty catch-ups pass while speed hacks drain it, 10 s window; carries/thefts restart the walk clock from the last trusted spot; thefts cancel only on a 3rd separate violation; tighter MinTravelTime; Settings beside the menu; bigger tutorial Skip; Studio-only guard debug command. Round 6 audit in QA/round6-audit.md.
- QA round 5 fixes: movement debt measured from the frozen anchor (multi-hop teleports gain nothing), per-sample speed so slowing down never false-flags, 0.6 s hitch tolerance, first steal violation re-times the theft (second cancels), catch checked before path checks, stolen value/compensation from what the victim paid, bigger phone menu/close buttons, one-line lock pill, rebirth button above the fold, countdown rounding, less belt label clutter. Round 4/5 audits in QA/round4-5-audits.md.
- QA round 4 fixes: no respawn grace (trust anchors at server spawn), settle windows for server moves, time-owed debt that pays down while walking, carry speed checked over every >=1 s sub-window (+5%), action window 1-2 s, steal prompts explain why, chat bottom-left on all devices, bigger phone UI text boxes/settings, banner spacing, real walking time for waddle-home, steal XP once per victim per 30 min.

## 2026-10-08
- Store page art: title icon + 5 feature thumbnails rendered in Blender (Assets/StorePage); genre attempted (Simulation/Tycoon).
- QA round 3 fixes: MoveGuard trust-anchor debt model, lag-tolerant carry checks, reset no longer skips the walk home, sell refunds on paid price, steal prompt countdowns, chat moved off the menu.
- QA round 2 fixes: per-tick carry path validation (teleport/speed/hover cancel thefts, restart belt-carry timer), horizontal catch, VIP chat tag implemented, honest Lucky copy, unaffordable prompts disabled, proportional collect XP, client-visible pair cooldowns, tips after panels close, ground-level eject, belt Goobers face both sides, lock release on early leave, AutoCollect moves bank, bigger close buttons, experience description, RawImport removed.
- Two-player theft tests (6 paths) pass in a Studio local server; audio verified loading on a client. QA/test-log.md + QA/round1-audit.md.
- Moderation fix: Roblox rejected all 10 Eye meshes (false positive). Eyes/pupils now built from native Parts from Blender specs; no rejected mesh referenced; exports contain no eye meshes.
- Blender assets imported (226 meshes -> 25 Goober + 12 prop templates via tools/process_import.luau); map rebuilt with real meshes. Original SFX sprite + music wired in.
- QA round 1 fixes: server-side movement guard (teleport snag/steal blocked), server-timed steal hold + min carry time, AutoCollect XP/tutorial, save retries, pass-grant verification, 50%-off personal drops, XP on placement, gentler level rewards, compensation cooldown, pixel-size tags, bigger touch targets, entrance ramp, server size 8.
- Fix: saves never persisted (BindableEvent copied the data table); data handoff now uses callbacks. Verified save -> rejoin.
- Real gamepasses (6) and developer products (4) created on the Creator Hub; IDs wired in; shop shows live prices; receipt replay test passes.
- All 25 Goober models + 12 props built in Blender (code-generated, inspected), exported to FBX; original SFX sprite + music synthesized.
- Core game: conveyor, carrying, bases, income, Cash Pad, upgrades, levels, rebirth, stealing, Goober Chaos events, monetization service, UI, tutorial, map builder, Studio sync + test harness; first Blender pipeline models.
- Project created: folder layout, README, working rules.

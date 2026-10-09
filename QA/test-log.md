# Snag A Goober - builder test log

Evidence from real Roblox Studio sessions (place 90695592143707). "Harness" =
Studio-only `ServerStorage.SAG_Test` (src/ServerScriptService/Testing/TestHarness.luau).

## 2026-10-08 - two-player theft tests (Studio local server, 2-3 real clients)

Players: Player1 (-1, base 1), Player2 (-2, base 2), later Player3 (-3, base 2 reused).

| # | Test | How | Result |
|---|---|---|---|
| 1 | Placement protection | Thief forced StealHold+Steal remotes on a Goober placed <45 s ago | PASS - client prompt hidden; server: "That Goober was just placed and is protected." |
| 2 | Successful theft | Real keyboard hold E (1.5 s) on Steal prompt, thief walked home, victim far away | PASS - Captain Spork moved P1->P2, P1 got $375 (25%) insurance + 120 s shield, P2 60 s cooldown, Dex discovery, banners both sides |
| 3 | Thief caught | P1 stole from P2, owner P2 walked into thief | PASS - Goober back on stand, thief 90 s cooldown, stun then speed restored (13.6 -> 16), caught stat |
| 4 | Base lock | P2 stepped on Lock pad, P1 tried to steal | PASS - intruder ejected 6 studs outside entrance, prompt disabled, server rejected (no valid in-range hold) |
| 5 | Thief disconnects mid-theft | Server kicked thief while carrying | PASS - Goober returned to victim (same uid), thief save has only legit Goobers, lock released |
| 6 | Victim disconnects mid-theft | Server kicked victim while thief carried | PASS - thief carry cancelled ("owner left"), thief gained nothing, victim save still holds the Goober (same uid), no stray models |
| - | Pair cooldown | Repeat thief on same victim within 5 min | PASS - "You already hit this base. Try again in 0:56." |
| - | Plot reuse | Player2 left, Player3 joined | PASS - got base 2, no leftover models, sign "Player3's Base" |

## 2026-10-08 - single-player checks

- Teleport-snag exploit (client sets HRP CFrame near far belt Goober, waits for replication, fires Snag): rejected "Whoa, slow down!" (MoveGuard).
- Legit snag by walking + walk home: placed normally.
- Auto Collect pass: +22 XP in 10 s, tutorial Collect step advanced.
- Save -> stop -> rejoin: Goobers, coins, level, upgrades, tutorial, dex restored.
- Receipt replay (same PurchaseId twice): granted once.
- Marketplace: all 10 ids live, names/prices match Config.
- Audio on a client: music loaded (34.29 s, playing), SFX sprite loaded (15.05 s), 15 Sounds; audible quality not verifiable by the builder.

## Moderation check (2026-10-08)
Assets API moderation state for all 239 uploaded assets: 226 meshes (216 Approved,
10 Rejected - all "Eye" meshes), 11 images Approved, 2 audio Approved. Eye meshes
replaced with native parts; no rejected asset is referenced in the place.

## 2026-10-08 - after QA round 2
- Server size: Roblox games API `games.roblox.com/v1/games?universeIds=10769928826` returns `maxPlayers: 8` (Studio local test sessions report their own default of 60).
- Experience description set (games API returns it). Lucky pass description now states the exact example (18% -> 24.8%), verified by hand: rare+ weight 18 x 1.5 = 27 of 109 = 24.77%.
- ServerStorage.RawImport removed from the place (re-import the FBX to reprocess).

## 2026-10-08 - builder retest of round-2 exploits (new 2-client session, build 85e5891)
| Test | Result |
|---|---|
| Teleport-home theft (real hold E, wait 3.2 s, one HRP CFrame write ~45 studs into own base) | BLOCKED - carry cancelled "no shortcuts!", victim keeps Fluffernaut |
| Hover-glide theft (+11 studs, 12 st/s straight line through walls) | BLOCKED within 1.1 s, victim keeps Snorkel |
| Legit belt carry walked home | PASS - Gumbo placed |
| Steal prompt during pair cooldown | hidden on client until cooldown ended (208 s) |
| Legit theft (real hold E, walked home) | PASS - Mushy transferred, Dex discovery |

## 2026-10-08 - builder retest of round-3 exploits (2-client session, build 8f3f851)
| Exploit (auditor round 3) | Result |
|---|---|
| Teleport 55 studs to belt, wait 3.4 s, snag | snag allowed at 3.4 s = same time as walking (debt model works; tightened afterwards so teleporting is strictly slower: d/(speed*1.1)+1.5 s) |
| Teleport 48 studs into victim base, wait 3.3 s, steal | allowed at ~walking time (tightened as above) |
| Carry stolen Goober at 20 st/s along an open path | CANCELLED after 1.5 s ("no shortcuts!"), victim keeps Disco Dan |
| Snag then reset (Health = 0) immediately | "waddling home on its own (2s)", landed ~2 s later, not instantly |
| Reset after carrying for minutes | placed immediately (walk time already elapsed) - correct |
| Chat window on desktop | ChatWindowConfiguration Left/Bottom (off the HUD menu) |

## 2026-10-09 - builder retest of round-4 findings (single-player Studio Play, build after round-4 fixes)
The 2-client session could not be restarted overnight (needs the owner), so two-player paths were not re-run this time.
| Test | Result |
|---|---|
| Reset, then teleport 50 studs to the belt during the old 4 s respawn grace, snag x14 | BLOCKED - every attempt "Whoa, slow down!" (respawn now anchors at the server spawn; no grace) |
| Legit walk to belt + snag | PASS |
| Carry home by CFrame at 20.7 st/s after standing still 1.5 s (server WalkSpeed 16) | CAUGHT - "No shortcuts!", placed after 5.1 s vs ~1.5 s legit |
| Same at server WalkSpeed 20 (Sprint Boots owned) | not flagged - correct (within 5% of real speed) |
| Legit MoveTo carry at 16 | PASS, placed 1.7 s, no warning |
| Single 15-stud bump then snag | first snag succeeds at 0.6 s (was ~6 s lockout) |

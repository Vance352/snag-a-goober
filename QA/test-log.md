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

## 2026-10-09 - builder retest of round-5 findings (single-player Studio Play)
Two-player paths not re-run (2-client session needs the owner present).
| Test | Result |
|---|---|
| Two-hop teleport (hop to belt, then hop again) and snag | BLOCKED - no snag within 16 s vs a 10.2 s walk; every refusal "Whoa, slow down!" |
| Carry with a 0.5 s client freeze + catch-up (simulated hitch) | PASS - placed at 1.6 s (clean walk 1.2 s), no "No shortcuts" (MIN_AGE 0.6) |
| Reset, wait 1.2 s, teleport next to belt (spawn ~2 s walk away), snag | snag at 3.4 s after spawn >= 2.0 s walk; earlier tries "Whoa, slow down!" |
| Reset, teleport repeatedly beside the farthest belt Goober (90-140 studs), snag x13 | first success 7.8 s after spawn vs 6.9 s legit walk - never faster than walking |
| Legit Humanoid:MoveTo carry home from that far spot (WalkSpeed 20) | PASS - placed after 6.1 s, no warning |
| Console | no script errors |

## 2026-10-09 - builder retest of round-6 findings (single-player Studio Play)
Note: Studio was not rendering overnight (viewport 1x1, RenderStepped 0/s), so client belt visuals were frozen; tests use the
belt's analytic position (same formula as the server). Two-player paths not re-run.
| Test | Result |
|---|---|
| C1 hop-and-back (25-stud hop, back, teleport 147-199 studs to belt, snag spam) | BLOCKED - 3 runs no snag within 12 s; with a 0.5 s replication wait, first plausible reply 6.0-6.1 s after a 147-stud teleport (walk 7.3 s) |
| Plain teleport 147 studs after standing 2.5 s | plausible after 5.2 s vs 7.3 s walk (stated budget: up to ~2 s of credit after standing still) |
| Sustained speed 1.0x / 1.15x / 1.25x for 9 s | not flagged (within the ~2 s gain budget) |
| Sustained 1.36x / 2.0x | caught at 6.2 s / 2.6 s, then held in debt until walked off |
| Walking with 0.5 / 1.0 / 1.0 / 1.5 / 1.5 s client freeze + catch-up | PASS all, 0 refusals in 12 probes each (round 6: 1.0 s gave ~6 s of refusals) |
| Legit Humanoid carries (2 short, 1 99-stud long, 1 via entrance) | PASS, no warnings |
| Carry with 1.0 s freeze + catch-up | PASS, placed 3.1 s, no warning |
| Teleport home while carrying | "No shortcuts!" and placement held to walking time |
| 1.5x carry away from home | caught ("No shortcuts!") |
| 1.5x carry straight home | placed ~2.4 s server-side vs 2.6 s straight walk (MinTravelTime floor, tightened to d/(1.05 v) - 0.1) |
| Tutorial Skip | 112x54 design px (about 84x40 at phone scale 0.75; auditor's 57x26 was the 0.62 floor scale on a 1x1 viewport) |
| Console | no script errors |

## 2026-10-09 - builder retest of round-7 findings (single-player Studio Play, Studio not rendering)
Verified first: the server sees a walking Humanoid's replicated velocity (~20 st/s), and a stalled client as a frozen
position with walking velocity - the pattern the lag bank now requires. Two-player theft paths not re-run (CODE-REVIEWED).
| Test | Result |
|---|---|
| Stall 0.5 / 1.0 / 1.5 s (position frozen, velocity kept) + catch-up, then walking | PASS - 0 refusals in 12 probes each |
| Freeze 1.0 s with velocity 0 (not a real stall pattern) | 2 refusals (~1 s), then fine |
| Stand 2.5 s, teleport 38 studs, snag | plausible only after 2.0 s (walk 1.9 s) - no gain (round 7: snag 0.43 s) |
| Sustained 1.2x / 1.3x / 1.5x | caught at 6.2 s / 3.6 s / 2.1 s (round 7: 1.3x passed 8.1 s) |
| Hold off-map 30 s (debt forgiveness), then teleport 120 studs | server returned the character to its last trusted spot at 30.5 s; teleport refused (Whoa x6) |
| Hop-and-back then teleport 147 studs | plausible after 6.5 s (walk 7.3 s) |
| Legit Humanoid carries (short, 70 studs out) | PASS, no warnings |
| Teleport home while carrying (belt) | warning, placed at 4.0 s = walk time |
| Theft teleport home | CODE-REVIEWED: excess > 10 studs during a theft calls Fail("teleport") immediately; hovering too |
| Console | no script errors |
State: sold 6 cheap Goobers (Toastie x2, Sir Puddle, Gumbo x3) to free base space for carry tests.

## 2026-10-09 - builder retest of round-8 findings (single-player Studio Play, Studio not rendering)
| Test | Result |
|---|---|
| Theft + smooth 3x move home | CODE-REVIEWED: any MoveGuard violation during a stolen carry (debt entry or CarryStep failure) now calls Fail("teleport") - no re-time path left |
| Faked stall (pinned, velocity 20) 1.8 s + 45-stud hop | plausible 0.45 s after the hop = 2.25 s total = walking time (time-neutral; once per 10 s) |
| Hop chain 5 x (1.75 s faked stall + 48-stud hop) | 242 studs plausible only after 12.6 s vs 12.1 s walk (round 8: 9.45 s) |
| Real-stall pattern 0.5 / 1.0 / 1.5 s while walking | PASS, 0 refusals in 12 probes each |
| Tutorial hints (all 6 texts) at 0.62 scale | TextFits = true for every one |
| Legit 70-stud carry | PASS, no warnings |
| Teleport home while carrying (belt) | warning, placed at 4.1 s (walk 4.0 s) |
| Console | no script errors |

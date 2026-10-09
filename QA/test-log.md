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

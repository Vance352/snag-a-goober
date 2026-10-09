# Independent Release Audit - Round 7
Place verified: 90695592143707 / "Snag A Goober" (GameId 10769928826, Studio 99449037, Edit mode at start and end)   Build: bb15b89 (main HEAD, git clean before and after)

The Studio scripts match git. There are 30 LuaSourceContainers in Studio. Each one has the same byte length and Adler-32 as its `src/*.luau` file (CRLF normalised), so all 30 are identical.

Environment checks:
- The client reported ViewportSize 1x1, RenderStepped 0/s and Heartbeat 60/s, so nothing is being rendered.
- `screen_capture` timed out.
- Belt positions below were computed from the model attributes.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:** Humanoid:MoveTo walk from spawn to the belt, snag, walk home: placed 1.6 s after the snag with no warnings. A carry with a 1.0 s freeze and catch-up placed at 2.39 s with no warning. Cash Pad paid bank 128,224 plus accrual. Speed upgrade raised WalkSpeed 16 to 17.5. Save, stop, start restored the same 20 uids, level, passes and 20 base models. Rebirth worked when my fuzz fired it (coins reset to the start value, upgrades reset). No script errors across 2 playtests and 1,008 malformed remote calls. |
| Simplicity/enjoyment of core loop | 7.5 | The loop is quick and clear; first legit carry placed 1.6 s after the snag. Design unchanged. The loop could not be watched visually this round. |
| Replayability/progression | 7.5 | Dex 21/25, Gold Line, levels, rebirth (verified this round), chaos. Systems unchanged. |
| Visual/Blender/animation/audio | 7.5 | Assets: 25 Goobers (132 MeshParts) and 12 props (51). All 23 belt models and 20 base models use MeshParts; the map has 377 MeshParts. All 31 client Sounds are loaded, with music playing. Blender renders (store thumbnails) look clean and varied. The in-game look is UNVERIFIED (no rendering). |
| UI/UX and mobile | 7 | Code: Skip is now 112x54 design px (69x33 px at the 0.62 floor, about 81-87 px on common phones by the scale formula). Settings moved beside the menu. A possible hint/status overlap was found (m2). Not checked on a device. |
| Multiplayer/networking/performance | 7.5 | Server at 60 FPS, 2,117 parts, about 1.3 MB Lua memory. **R6 M2 fixed (verified):** 1.0 s and 1.5 s freezes while walking gave no refusals. Each guard check loops over about 100 history samples, but snag/steal remotes are rate-limited. All two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 5 | Persistence, receipts and fuzzing are solid. The hop-and-back bypass is fixed. **New problems:** teleport-home thefts are no longer cancelled (C1, code), the 30 s debt-forgiveness lets a player teleport anywhere (M1, verified), and lag credit gives about 2 s per trip (M2, verified). |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live and their prices match Config. Simulated receipt `AUDIT7-1` sent twice: coins were granted once and the replay left them unchanged. Lucky odds copy unchanged since R6. |
| Onboarding/first minute | 7.5 | With `tutorial=0` the hint "Grab a Goober off the conveyor!" shows, with Skip (TextFits=true) and one enabled guide Beam. |

Weighted total: **7.33 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7×.10 + 7.5×.10 + 5×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
**C1. A thief who teleports home with a stolen Goober is no longer stopped. The theft completes and the owner effectively cannot catch them.** CODE-REVIEWED end to end; the matching belt-carry behaviour is VERIFIED.

Code path:
- `StealService.Offence` (StealService.luau:221-244) now counts only separate offences more than 1.5 s apart and cancels on the 3rd. During a debt the ticks keep refreshing `offenceAt`, so a teleport home counts as **1** offence.
- After the debt clears, `MoveGuard.CarryStep` starts a new trail at the current spot and returns true (MoveGuard.luau:297-301).
- `succeed()` then fires once `MinTravelTime(from.pos)` has passed (StealService.luau:324-331). In round 6 the second tick cancelled the theft ("Fail teleport").

Why the owner can't catch the thief:
- The catch is purely positional (≤7 studs, StealService.luau:314), and the thief is already sitting in their own base.
- If the thief locked their base first (nothing in `CanSteal` prevents it), `EjectIntruders` pushes the chasing owner out every 0.2 s (BaseService.luau:242-256, 360-362).
- Unlocked, the owner must run to the thief's base. For d=112 they need d/16 ≈ 7 s plus reaction time. The thief is done at about d/(1.05×13.6) − 0.1 − ~1.5 s of bank credit ≈ 6.1 s.

Verified belt-carry version (same CarryStep/MinTravelTime logic):
- I snagged at (-84, -19) and set the HRP CFrame 61 studs to (-84, -80) inside the base.
- One "No shortcuts!" toast appeared, then the carry was placed 1.35 s after the server saw the jump.
- The server log showed the guard trusted an interpolated midpoint (-84, -49) as the "last trusted" sample.

Repro (needs 2 players):
1. Thief at Lv≥10 steps on their Lock pad.
2. Thief walks into the victim's base, holds E, and the theft starts.
3. Thief sets the HRP CFrame into their own base and stands still.

Expected: the theft is cancelled, as R2-R6 required ("Teleport-home theft: BLOCKED"). Actual (by code): it succeeds after about walking time, and the victim has no realistic way to catch the thief.

## Major issues
**M1. The 30 s debt-forgiveness valve accepts any position: teleport anywhere and act, once per 30 s** (VERIFIED). When forgiven, `check()` sets `g.history = {}` and returns true (MoveGuard.luau:175-179), and the sampler then trusts wherever the player is.
- Repro: hold the HRP at (2000, 3.5, -35) off-map for 29.6 s (out of reach of every frozen sample), then CFrame next to a belt Goober 138 studs from spawn (6.9 s walk) and spam Snag.
- Result: two "Whoa" replies, then `Carrying=G13_Fluffernaut` **0.35 s after the teleport**.
- Steal approach uses the same `Plausible` gate (StealService.luau:99, 116); CODE-REVIEWED.
- Fix: on forgiveness, ServerMove the player to their spawn (or keep the frozen history) instead of trusting the current spot.

**M2. Lag "bank" credit makes any player about 1.5-2.4 s faster than walking on each trip** (VERIFIED; this is R6 M1 in a new form). The header claim "nobody gets anywhere faster than walking" is false. After standing still for at least 1.6 s:
- An instant 38-stud teleport snag succeeded 0.43 s later (walking takes 1.9 s).
- Straight-line speed tests (Snag probes every 0.5 s):

| Speed | Result |
|---|---|
| 1.2x for 9 s | never flagged |
| 1.3x | passed for 8.1 s / 210 studs, about the full map width |
| 1.36x | passed for 6.6 s |
| 1.5x | passed for 4.1 s / 123 studs |

- The long-window limit is about 1.24x (10 s HISTORY).
- Cause: REPL_LAG 0.5 plus up to 1.0-1.6 s of bank on every sample (MoveGuard.luau:43-45, 129-146).
- It is bounded and partly a deliberate lag-tolerance trade-off, but it still gives exploiters a reliable head start on rare belt Goobers and on steal approaches.

**M3. Store/public status unchanged** (owner-side, not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` still returns "[TITLE UNAVAILABLE]", `isContentRestricted: true`, maxPlayers 0.
- The thumbnails API now lists 1 thumbnail (state Completed).

## Minor issues
- **m1. Freezes longer than about 1.6 s still cause long refusals while walking.** A 2.5 s freeze gave "Whoa" from 6.1 s to 10.1 s, clearing only once the player stopped (VERIFIED). This is outside the stated budget and rare.
- **m2. Possible layout overlap (code-derived).** The tutorial Hint (480 wide, centred, y 122-184) overlaps the top-right status column (250-wide pills from W−258) whenever the design width is under about 996 px. That covers every 16:9 phone (design about 889 px) and 1280x720 windows: roughly 24-53 px of overlap with the Lock/Drop pills. Toasts at y = 188 brush the column too. Skip is 69x33 px at the 0.62 floor scale. UNVERIFIED on a device.
- **m3. Exploit-only side effect:** after M1-style moves, `carry.startPos` can be set off-map. A death then produced "waddling home on its own (103s)". This only hurts the exploiter, but it shows untrusted positions reaching carry state.

## Retest of previous round's findings
- **R6 C1 (hop-and-back): FIXED.** Ran the 25-stud hop, the hop back, then a teleport to a target 183 studs away (snag point 160.5 studs from start). 33 "Whoa" replies, then the snag 6.82 s after the teleport (7.58 s total; walking takes about 7.3-8.0 s). A plain teleport after standing still snagged at 5.5 s for 134 studs (walk about 6-6.7 s): about 1 s gain, which falls under M2.
- **R6 M1 (sustained speed hack): PARTLY FIXED.** The gain is now capped per trip, but 1.3x passes a full-map trip and 1.36x passes for 6.6 s (M2).
- **R6 M2 (1 s lag hitch): FIXED.** 1.0 s and 1.5 s freezes gave 0 refusals in 18-20 probes, and a belt carry with a 1.0 s freeze placed with no warning (verified). Theft lag-cancel is fixed in code, but that change causes C1.
- **R6 M3 (store/public): NOT FIXED** (owner-side).
- **R6 m1 (offenceAt never cleared): FIXED in code** (replaced by a separated-offence counter), but this is what introduced C1.
- **R6 m2 (mobile Skip/footprint): PARTLY FIXED** (code). Skip 112x54 design px; Settings moved to (192, 6). Not checked on a device.
- **R6 m3 (unexplained legit-carry toast): NOT REPRODUCED.** A MoveTo carry and a hitch carry were both clean.
- **R6 m4 (MoveTo stuck at belt frames): NOT REPRODUCED** on the straight x = -84 route. Other routes UNVERIFIED.

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; script sync (30/30).
  - Exploit and lag tests: C1-R6 retest; M1 forgiveness bypass; M2 speed/teleport thresholds; 1.0/1.5/2.5 s hitch behaviour; teleport-home belt carry (placed 1.35 s after the jump, one toast).
  - Core loop: legit MoveTo snag, carry and place; Cash Pad; Speed upgrade.
  - Free-player state after revoking all 6 passes: rate 3148 to 1574, capacity 22 to 18, WalkSpeed 20 to 16, luck 1.5 to 1, VIP false. Passes re-granted afterwards.
  - Data and purchases: 1,008 fuzzed remote calls with no errors (GetQuote returned non-nil 4/15); receipt idempotency; marketplace ids and prices; harness save, raw DataStore read, stop, start, identical restore.
  - Assets and audio: assets and MeshParts in use; 31 sounds loaded.
  - Onboarding: tutorial hint, Skip and Beam.
  - Perf stats; public API status.
- **CODE-REVIEWED:**
  - MoveGuard (whole file).
  - StealService (whole file: Offence, catch ordering, succeed, CanSteal).
  - CarryService (whole file).
  - BaseService lock/eject/sell; ConveyorService.Snag; Main remote wiring.
  - Rebirth server and client confirm.
  - UI diff and scale formula.
  - Harness (Studio-only gate).
- **UNVERIFIED:**
  - All two-player paths: live theft, catch, victim/thief leave, victim UI, C1 live, steal approach via M1.
  - Phone layouts and the in-game visual look (no rendering, screenshots time out).
  - Real network lag; 8-player load; real audibility; real purchases (none made); moderation and questionnaire.

## Decision: FAIL
Gates that decided it:
- Unresolved critical ownership/security exploit (C1: teleport-home thefts complete and can't realistically be caught).
- Weighted 7.33 < 8.0.
- Data/economy/exploit 5 < 7.

## Top 5 fixes that would raise the score most
1. **C1:** any teleport-class violation during a stolen carry (an offence while in MoveGuard debt, or a CarryStep jump beyond, say, 2× allowance) should Fail the theft immediately. Keep the lenient "re-time" path only for small, lag-sized excesses. Retest in a real 2-client session: teleport home with the base unlocked and locked.
2. **M1:** at debt forgiveness, never trust the current position. ServerMove to the player's spawn (or keep the frozen history and just re-time). Retest with the off-map 30 s hold, then teleport-snag.
3. **M2:** cap total credit per trip. For example, apply the bank only to the newest few samples, drop REPL_LAG to about 0.25 when ping is low, or spend the bank on any move faster than 1.0x. Retest a 38-stud instant teleport, plus 1.3x and 1.5x runs, while keeping the 1.0/1.5 s hitch tests green.
4. **Mobile:** move the tutorial Hint below the status column (or narrow it) when the design width is under about 1000 px. Device-check a Galaxy A06 and an iPhone landscape once Studio can render.
5. **Real tests:** run a published 2-client private-server test (theft, catch, leave, lag, C1). The owner then finishes the questionnaire and sets Public.

## State changes made during this audit
- Two single-player playtests started and stopped. Studio is back in **Edit** mode. No code, map, Assets or Creator Hub changes; git still clean at bb15b89.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - My fuzz fired `Rebirth` and `BuyUpgrade`, which caused a real in-session rebirth (coins to start value, rebirths 1).
  - I restored with the harness: rebirths 0, coins 11,431,354 (11.49M after offline accrual on rejoin), level 24. Speed upgrade is 0, as at the start.
  - Simulated receipt `AUDIT7-1` recorded (its coins were overwritten by the restore).
  - Goobers 18 to 20: sold 5 cheap ones (2 Blorp, 3 Sir Puddle); 7 cheap/mid Goobers placed by my carry tests (Toastie x2, Pebble Pete x3, Captain Spork, Cone Head).
  - Tutorial set 0, then restored to 99.
  - All 6 passes revoked and re-granted; they are re-derived on join.
  - Harness save done.
- Plugin-VM loggers and helpers (`_G.AUD7`, `_G.SLOG`) ran inside the playtests only.

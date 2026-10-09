# Independent Release Audit - Round 6
Place verified: 90695592143707 / "Snag A Goober" (GameId 10769928826, Studio 99449037, Edit mode at start and end)   Build: d021f7e (main HEAD, working tree clean before and after)

The Studio scripts match git. There are 30 LuaSourceContainers in Studio and none outside RS/SSS/SS/StarterPlayer. I compared each one's byte length and Adler-32 with the matching `src/*.luau` file (CRLF normalised), and all 30 are identical.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 7.5 | **Verified:** legit snag, carry, auto-place at WalkSpeed 16 and 20; income 1286/s; Cash Pad paid bank 18,004 + accrual; Speed upgrade 16 to 17.5; save, stop, start restored the same 9 uids, coins and level. Zero console errors across 2 playtests and 560 malformed remote calls. **Regressions:** one unexplained "No shortcuts!" toast on a legit carry (m3); lag hitch can cancel thefts (M2). |
| Simplicity/enjoyment of core loop | 7.5 | Loop is quick and clear. The first legit snag landed 1.9 s after the snag. Unchanged design. |
| Replayability/progression | 7.5 | Levels, Dex (21/25 discovered), Gold Line at Lv10, rebirth, chaos countdown ("Next: SLOP STORM") are all present. Systems unchanged. |
| Visual/Blender/animation/audio | 7.5 | `ReplicatedStorage.Assets`: 25 Goober models (132 MeshParts) and 12 props (51 MeshParts). All 42 belt models observed contain MeshParts. 27 client Sounds, all loaded (SFX sprite x14, music playing). Screenshots timed out this round, so the look itself was not re-checked. |
| UI/UX and mobile | 7 | Desktop (1429x812, UIScale 1.35): menu buttons 113 px, all labels TextFits=true, Settings 89 px. Phone layout not checked (no device simulator or screenshots). Tutorial Skip is 57x26 at 1.35, about 28x13 px on a 0.676-scale phone (m2). |
| Multiplayer/networking/performance | 6.5 | Server 60 FPS, 2,188 parts, 1.3 MB Lua memory, belt is time-based. A 1 s network hitch puts a walking player into debt that never pays down while walking (M2, verified), which cancels a theft (code). Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 4 | New critical bypass of MoveGuard: snag anything on the map about 1 s after a hop-and-back (C1, verified 3 times). Sustained 1.36x speed hack passes free roam (M1, verified). Persistence, receipts and fuzzing are solid. |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products live, prices match Config. Same simulated receipt twice: granted once (coins unchanged on the replay). Lucky copy states the 18% to 24.8% example and the Odds modal exists. |
| Onboarding/first minute | 7.5 | `tutorial=0`: hint "Grab a Goober off the conveyor!" with Skip and 1 guide Beam. Flow code unchanged since R5 (which verified it). Small Skip target. |

Weighted total: **7.03 / 10** (7.5×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7×.10 + 6.5×.10 + 4×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
**C1. "Hop-and-back" disables MoveGuard: a player can teleport anywhere and snag within 0.3 s, and the steal approach uses the same check.**

**Cause** (`src/ServerScriptService/Services/MoveGuard.luau`):
- (a) When debt clears, `check()` replaces history with one fresh sample (lines 150-153).
- (b) `reachable()` ignores samples younger than `MIN_AGE = 0.6` (line 110). For 0.6 s after any reset, every position passes and is recorded into history (sampler, lines 298-301).
- (c) `enterDebt` freezes the anchor at `g.history[#g.history]` (line 130). That is the newest sample, which is already the teleported position. The resulting debt is "paid" on the next tick (`debtPaid` distance ≈ 0, line 144-145), and history resets again at the new spot.
- **Trigger:** any 20-25 stud hop and immediate hop back. The debt anchors at the pre-hop spot and is paid at once. Any normal debt clearance opens the same window.

**Repro** (pure client script, single player, WalkSpeed 20):
1. `hrp.CFrame = A + 25 studs`; wait 0.35 s.
2. `hrp.CFrame = A`; wait 0.35-0.4 s.
3. Set the CFrame next to a far belt Goober (following it) and fire `Snag(uid)` every 0.1 s.

**Results (verified):**
- **Run 1:** target 75 studs away. Server `Carrying=G15_Chonk` 0.35 s after the teleport (1.13 s total). No "Whoa".
- **Run 2, control:** plain teleport 132 studs and Snag spam for 2 s gave 9x "Whoa, slow down!", so the guard works without the trick. Then I set CFrame back to the start (pays the debt) and teleported 92 studs to **G21_Gooberzilla (Legendary, $200,000)**. Carrying 0.32 s after the teleport, no "Whoa" logged.
- **Run 3:** teleported 184 studs (9.2 s straight-line walk), stood there 1.4 s without snagging, then snagged. Carrying 1.53 s after the teleport, 2.25 s after the start. Plausible therefore stays true for the whole window a steal needs (StealHold right after arrival, Steal ≥0.95 s later).

**Steal impact:** CODE-REVIEWED, since there is no second player. `StealService.HoldBegan` and `Request` gate only on `MoveGuard.Plausible` (StealService.luau:99, 116), the same check as Snag. A thief can therefore appear in any unlocked base and start a theft in about 1.5 s with no approach. The carry home is still enforced: the CarryStep trail plus Offence cancel teleports home (code-reviewed).

**Expected vs actual:**
- Expected: "multi-hop teleports gain nothing; teleport-then-wait never faster than walking" (MoveGuard header).
- Actual: approach costs about 1 s for any distance. Exploiters can take every Legendary/Secret off the belt before anyone can walk there.

## Major issues
**M1. A sustained ~1.36x speed hack passes the free-roam check** (claimed +8%).
- **Verified:** server-side position log (0.25 s polling) showed 26.7-28.9 st/s for 5+ s with server WalkSpeed 20. All 10 Snag probes answered "Get closer to snag it!" (none "Whoa"), so Plausible was true throughout. At 1.6x (31.6 st/s) and 2.0x (38-42 st/s) every probe answered "Whoa".
- **Cause:** same mechanism as C1(b)+(c). Each violation anchors debt at the newest (already-fast) sample, so it is paid next tick and history resets. Only the 0.6 s-old sample is effectively ever checked: 20×1.08×0.6 + 2.5 + 1 ≈ 16.5 studs, about 27.4 st/s.
- **Impact:** this shortens every approach, including thefts. Carries are still limited by the CarryStep 3 s trail (+5%, CODE-REVIEWED).

**M2. A 1 s lag hitch while walking causes long refusals and (code) cancels thefts** (round-4 M2 behaviour is back).
- **Verified:** walking at 20 st/s, I froze the client (HRP anchored) for 1.0 s, then caught up 20 studs. The next 12 Snag probes (one every 0.5 s, about 6 s) answered "Whoa, slow down!" and only cleared after the player stopped at the goal.
- **Cause:** `debtPaid` measures from the frozen anchor, whose `t` is the last sample before the catch-up, so the frozen second is not credited. Allowed distance grows at 1.08×speed while the walker adds 1.0×speed, so the debt pays down at only ~1.6 st/s.
- **Theft impact (CODE-REVIEWED):** while in debt, `CarryStep` returns false (MoveGuard.luau:248-250) and `StealService.Offence` runs every tick. Once ≥1.0 s has passed since the first offence it calls `Fail(thief,"teleport")` (StealService.luau:233-235). One 1 s lag spike on the walk home loses the theft.
- **Verified:** a 0.5 s hitch with 10-stud catch-up during a belt carry gave no warning and placed normally, so short hitches are now tolerated.

**M3. Store/public status unchanged** (owner-side, not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` returns "[TITLE UNAVAILABLE]", `isContentRestricted: true`, maxPlayers 0.
- The thumbnails API lists 2 thumbnails with the same image URL (not 5). Icon state is "Completed".
- `QA/RELEASE_CHECKLIST.md`: questionnaire and Public are still unchecked.

## Minor issues
- **m1. `carry.offenceAt` is never cleared** (StealService.luau:228-235). Any second violation at any later point in a theft cancels it, not only "while still violating" as the comment says. CODE-REVIEWED.
- **m2. Mobile touch targets/footprint.**
  - The tutorial Skip button is 57x26 px at UIScale 1.35 (about 42x19 design px, about 28x13 on a 0.676-scale phone).
  - The enlarged menu is 176x176 plus Settings at y = 188-254 design px, which is about half the height of a 338-px landscape phone.
  - Not device-verified.
- **m3. One "No shortcuts! Walk your Goober home." toast during a legit carry.** It happened while Humanoid:MoveTo was stuck against the belt frames between the lines at (-76, -0.5) and then jumped across. Cause undetermined. A clean 210-stud legit carry, a 31-stud carry with a 0.5 s hitch and a WalkSpeed-16 carry had no warnings.
- **m4. Humanoid:MoveTo got stuck at the belt frames between MidWalk and the belt** (48 s) until jumping. Keyboard crossing not tested, so the navigation snag is minor/unverified for real players.

## Retest of previous round's findings
- **M1 (two-hop teleport bypass): NOT FIXED. REGRESSED in effect.** Frozen-anchor debt stops naive multi-hops (control: 9x "Whoa"). The new MIN_AGE window plus the newest-sample anchor makes the approach about 1 s for any distance (C1). R5 measured 3.8 s for 148 studs; now 1.5 s for 184 studs.
- **M2 (hitch cancels thefts): PARTLY FIXED.**
  - 0.5 s hitch tolerated (verified).
  - 1.0 s hitch: about 6 s of refusals while walking (verified), and theft cancel per code (M2).
  - Catch is checked before CarryStep (verified in code, StealService.luau:306-310).
- **M3 (store/public settings): NOT FIXED / owner-side** (see M3).
- **m1 (mobile layout): CODE-REVIEWED, device UNVERIFIED.** Cells 84 px, close X 72x60, one-line lock pill text, Rebirth button moved to y = 240. Desktop labels TextFits=true (verified).
- **m2 (countdown rounding): FIXED** (code, World.luau:188-196 uses `secs = ceil` before `//` and `%`).
- **m3 (Personal Drop laundering): FIXED** (code). Thief's record `paid = floor(victimPaid*0.5)` and compensation is `victimPaid*0.25` (StealService.luau:250-274). Sell refunds 50% of `paid` (BaseService.luau:209).
- **m4 (catch vs CarryStep ordering): FIXED** (code, catch evaluated first).
- **m5 (free-roam speed tolerance ~1.2x): NOT FIXED, worse.** 1.36x passes (M1).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; script sync.
  - Exploits: C1 (3 runs plus control); M1 speed thresholds (1.15x, 1.25x, 1.36x pass; 1.6x, 2.0x blocked); M2 1 s hitch refusals; 0.5 s hitch tolerated.
  - Core loop: legit snag/carry/place at 16 and 20; 210-stud legit carry; income/bank/Cash Pad; Speed upgrade.
  - Data and purchases: free-player state after revoking all 6 passes (rate 2568 to 1284, capacity 22 to 18, WalkSpeed 20 to 16, luck 1.5 to 1, VIP attribute false), then re-granted; 560 malformed calls on 10 client remotes with no errors or corruption; GetQuote rate-limited (8/60 non-nil); receipt idempotency; marketplace ids and prices; save, raw DataStore read, stop, start, identical restore.
  - Assets: mesh assets in use; 27 sounds loaded; tutorial hint, Skip and beam; perf stats.
  - Public API status.
- **CODE-REVIEWED:**
  - MoveGuard rewrite (whole file).
  - StealService: Offence, catch ordering, paid-based value and compensation, Plausible gating on steals (steal half of C1).
  - CarryService completion timing.
  - UI/World diffs.
  - Harness (Studio-only gate, commands).
- **UNVERIFIED:**
  - All two-player paths: live theft, catch, victim/thief leave, victim-side UI, the steal variant of C1, theft cancel under lag.
  - Phone layouts (device simulator, screenshots and mouse input all timed out this session).
  - Shop modal contents when opened and live price buttons.
  - Real network lag; 8-player load; actual audibility; real purchases (none made); store moderation and questionnaire.

## Decision: FAIL
Gates that decided it:
- Unresolved critical exploit (C1: movement-guard bypass, snag anywhere, steal approach).
- Weighted 7.03 < 8.0.
- Data/economy/exploit 4 < 7.
- Multiplayer/networking 6.5 < 7.

## Top 5 fixes that would raise the score most
1. **Close C1/M1 in MoveGuard.**
   - Never trust positions that were not checked against a sample at least MIN_AGE old. After a reset, seed history with the anchor (keep its original timestamp), or check young-history positions against the oldest available sample, as the R5 code did with `i==1 and not checked`.
   - Freeze the debt anchor at the last sample that passed a full check, not `history[#history]`.
   - Retest: hop-and-back then teleport-snag at 75-180 studs; sustained 1.2x/1.3x speed with Snag probes.
2. **Credit hitch time (M2).**
   - On a violation, take the anchor time as when the player arrived at the frozen spot (the earliest identical sample), or allow a one-off catch-up budget of about speed×1.0 s.
   - Let debt pay at walking rate, not 0.08×speed.
   - Retest 1.0 s and 1.5 s freezes while walking and during a belt carry. Then retest during a real 2-player theft.
3. **StealService.Offence:** clear `offenceAt` after a clean ~2 s, and cancel only on persistent violations.
4. **Mobile:** make tutorial Skip ≥44 px. Check the enlarged menu footprint and the shop/rebirth modals on Galaxy A06 / iPhone with the device simulator.
5. **Real tests:** run a published 2-client private-server test (theft, catch, leave, lag), then finish the owner-side store items (questionnaire, thumbnails, Public).

## State changes made during this audit
- Two single-player playtests started and stopped. Studio is back in **Edit** mode. No code, map, Assets or Creator Hub changes; git still clean at d021f7e.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732), written by my harness save and autosave/BindToClose:
  - Coins about 2.50M to about 4.72M. Includes the simulated Slop Sack receipt `AUDIT6-6442618` (+772,968, granted once), income, the Cash Pad, and a spent Zoomies purchase.
  - Level 12 to 21.
  - Goobers 4 to 9 (Chonk and Gooberzilla via the exploit, Wobblesworth via the exploit, Sir Puddle and Pebble Pete legitimately).
  - Dex counts up.
  - Speed upgrade bought, then reset to 0 via harness.
  - Tutorial set 0, then restored to 99.
- All 6 passes revoked and re-granted in-session (they are re-derived on join).
- A plugin-VM position logger (`_G.AUD`) ran inside the playtest only.

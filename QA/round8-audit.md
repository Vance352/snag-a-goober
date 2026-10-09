# Independent Release Audit - Round 8
Place verified: PlaceId 90695592143707 / "Snag A Goober" (GameId 10769928826, Studio 99449037, in Edit mode at start and end)   Build: d7ae2da (main HEAD; git clean before and after)

**Script sync:** all 30 scripts in Studio match `src/*.luau` exactly (same byte length and Adler-32, CRLF normalised).

**Environment:**
- The client reported ViewportSize 1x1, RenderStepped 0/s and Heartbeat 59/s, so nothing is being rendered.
- Only one player was available. I timed things with the server-side guard state (logged every 0.1 s through the harness `guard` command) and Heartbeat position logs.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:** legit Humanoid:MoveTo snag then carry; placed 2.28 s after the snag over 44 studs, with no debt and no toast. Sell worked (x4). Simulated receipt granted. Save, stop, start restored the identical 19 uids, Lv 24, rebirths 0, all 6 passes and 19 base models. 1,188 malformed remote calls plus 18 GetQuote calls caused no script errors. Console clean across 2 playtests. |
| Simplicity/enjoyment of core loop | 7.5 | Loop unchanged and quick: the legit carry placed at walking time. Not watched visually (no rendering). |
| Replayability/progression | 7.5 | Unchanged systems: Dex 21/25, Gold Line, levels and rebirth (rebirth not re-run). |
| Visual/Blender/animation/audio | 7.5 | Assets: 25 Goobers (132 MeshParts) and 12 props (51); map 377 MeshParts; base 100 and belt 49 MeshParts in use. 27/27 client sounds loaded, music playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7 | Hint/status overlap fixed in code: design width is ≥900, hint right edge W/2+185 vs status left W−258, about 7 px clear. **But** the narrowed hint label (236 design px) no longer fits one tutorial text (TextFits=false, m1). Not checked on a device. |
| Multiplayer/networking/performance | 7.5 | Server 60 FPS, 2,126-2,166 parts, about 1.3 MB Lua memory. Freeze with velocity kept: 1.5 s gave 0 debt rows (verified). Freeze with velocity 0 (1.0 or 1.5 s): 1.5-1.9 s of debt (m2). Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 5.5 | Persistence, receipts and fuzz are solid, and M1 is fixed (verified). **Still open:** theft carries can still beat the teleport cancel with a smooth fast move (C1; first flag +4 studs, below the 10-stud cut-off). A faked stall bank still gives a 0.43 s snag after a 45-stud teleport and a sustained 1.27x hop chain (M2). |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live, prices match Config, passes for sale. Receipt `AUDIT8-1` sent twice: +987,280 once, the replay changed nothing. Lucky copy honest; odds/price cells fill on panel open (CODE-REVIEWED, UI.luau:586-594, 734/757). |
| Onboarding/first minute | 7.5 | Hints for steps 0/2/3 show with Skip and 1 enabled guide Beam; hint hides at step 99. One step-2 text variant overflows (m1). |

Weighted total: **7.38 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7×.10 + 7.5×.10 + 5.5×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
**C1. A theft can still be carried home early and safely: only instant teleports are cancelled.** The guard part is VERIFIED; the theft decision is CODE-REVIEWED end to end.

What changed and why it doesn't hold:
- `StealService.Offence` cancels only when `excess > TELEPORT_EXCESS` (10 studs) (StealService.luau:228-231).
- That `excess` is measured once, at the first violation (`enterDebt` → Offence, MoveGuard.luau:181-195).
- While the player is in debt, `CarryStep` returns `excess = 0` (MoveGuard.luau:329-332) and `check()` never re-measures (MoveGuard.luau:199-220).
- So a fast move that starts by exceeding the allowance only slightly gets one "small" offence. The rest of the trip is unmeasured.
- After that the code path is the same as R7 C1: debt clears once the spot is walkable from the frozen samples, `succeed()` fires at `MinTravelTime` from the frozen spot, and the thief sits in their own (lockable) base the whole time.

Evidence (belt carry; same guard code):
- I carried G02_SirPuddle from (20,-20) home at 3x walk speed (60 st/s, smooth, no CFrame jump).
- The guard's first flag was **"move +4 studs"** (below 10). It stayed in debt the whole run.
- I arrived home at 1.88 s; the carry was placed at 4.30 s, the walk-time floor. One "No shortcuts!" toast.
- Instant teleports *are* caught: a 112-stud CFrame jump was interpolated by the server over about 80 ms and flagged at +92.

Repro (needs 2 players):
1. Thief at Lv≥3 locks their base on the Lock pad.
2. Thief steals from the victim.
3. Thief tweens or speed-hacks home at about 3x (not one CFrame set).
4. Thief stands inside their own base.

Expected: theft cancelled, as with a teleport. Actual (by code): 1 offence, then success at about walking time while the owner is ejected from the locked base.

## Major issues
**M2. The lag bank can be faked by sending walking velocity while standing still** (VERIFIED; R7 M2 not fixed against an exploiter). The bank fills when the server sees a frozen position with replicated velocity ≥0.4× walk speed (MoveGuard.luau:118-131), and the client controls that velocity.
- **Single teleport snag:** I pinned the HRP and set AssemblyLinearVelocity to 20 for 1.8 s; the bank reached 1.60. Then a 45-stud CFrame jump next to G07_Wobblesworth was snagged **0.43 s** later with no "Whoa" (walking takes 2.25 s). The control with velocity 0 cleared debt in about 1.6 s.
- **Sustained hop chain:** five cycles of a 1.75 s faked stall plus a 48-stud hop covered **240 studs in about 9.45 s** (walking takes 12 s), so about 1.27x with no end.
  - Debt never lasted more than 0.35 s.
  - The burst re-base (`record`, MoveGuard.luau:138-145) reset history to n=1 after each hop, so the 10 s long-window check never applies.

**M3. Store/public status unchanged** (owner-side, not scored against the build). `games.roblox.com/v1/games?universeIds=10769928826` returns "[TITLE UNAVAILABLE]", `isContentRestricted: true`, maxPlayers 0. One thumbnail is listed (Completed).

## Minor issues
- **m1. The narrowed tutorial hint overflows.** The hint is now 370 wide, leaving a 236-design-px label.
  - Guide.luau:172 "Your Goober is making Slop Coins! Step on the Cash Pad soon." gave **TextFits=false** at TextSize 8 (verified at scale 0.62).
  - This shows at step 2 whenever bank < 1, which is always the case with AutoCollect.
  - "Collect $50, then buy Zoomies at the Slop-O-Matic!" (Guide.luau:181) is similarly long.
  - The other hints fit, but only at TextSize 8 in the 1x1 test viewport (about 11-12 px on a phone by the scale formula). Small for a phone; UNVERIFIED on a device.
- **m2. Lag tolerance now depends entirely on replicated velocity during a freeze.**
  - Walking at 19 st/s, a freeze with velocity 0 then a 3-burst catch-up gave debt ("Whoa" window) for **1.5 s (1.0 s freeze)** and **≥1.9 s (1.5 s freeze)**. With velocity kept, 0 rows.
  - R7 measured 0 refusals for 1.0/1.5 s freezes.
  - Whether real network stalls keep velocity on the server is UNVERIFIED here; the builder's log asserts it.
- **m3. Walking slightly below full speed slowly earns bank** (0.28 s seen while walking at 19 with speed 20), because `gain > 0` with walking velocity. It is small, but it is free credit.
- **Not counted (test artifact):** one carry made right after a 28 s client pin showed the character frozen for 2 s and then flung 29 studs, which triggered a debt and toast. Not reproduced in clean MoveTo runs (J, K, L: 0 debt rows).

## Retest of previous round's findings
- **R7 C1 (teleport-home theft): PARTLY FIXED / NOT FIXED in practice.** Instant teleports now produce a large excess (+92 measured) and would cancel (code). A smooth 3x move flags at +4 and completes (see C1).
- **R7 M1 (30 s forgiveness trusts any spot): FIXED** (verified).
  - I held off-map at (2000,-35); at 30.1 s the server re-anchored at the last trusted spot (28,-64) with settling, never trusting the off-map position. My pinned client stayed off-map and was back in debt 1 s later.
  - The snag that later succeeded was 59 studs from the anchor, 2.4 s after re-anchoring (walking takes 2.95 s). That is no gain beyond REPL_LAG.
- **R7 M2 (lag-bank head start): NOT FIXED** against velocity spoofing. Standing still with velocity 0 no longer earns bank (verified).
- **R7 M3 (store/public): NOT FIXED** (owner-side).
- **R7 m1 (long freezes refuse): CHANGED.** Velocity-kept 1.5 s freeze is fine; velocity-0 1.0/1.5 s freezes now refuse for 1.5-1.9 s (m2).
- **R7 m2 (hint/status overlap): FIXED in code** (about 7 design px clearance at W=900). It introduced text overflow (m1).
- **R7 m3 (off-map `carry.startPos`): UNVERIFIED.** ServerMove still shifts `startPos` by delta on forgiveness (MoveGuard.luau:305-307); exploit-only.

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync.
  - Exploit and guard tests: control vs faked-stall teleport (debt cleared at 1.6 s vs 0.45 s); real snag 0.43 s after a 45-stud teleport; 240-stud hop chain; 3x carry flagged at +4 then placed at 4.30 s; instant-teleport interpolation (+92); M1 off-map forgiveness re-anchor.
  - Lag: freeze tests with velocity kept vs velocity 0.
  - Core loop: legit MoveTo snag, carry and place; Sell.
  - Free player after revoking all 6 passes: rate 3280 to 1640, capacity 22 to 18, WalkSpeed 20 to 16, luck 1.5 to 1, VIP false. All 6 re-granted.
  - Data and purchases: fuzz 1,188 events plus 18 invokes, no errors; receipt idempotency; marketplace ids and prices; save, raw DataStore read, stop, start, identical restore.
  - UI and onboarding: hint text/TextFits per tutorial step.
  - Assets and audio: asset/MeshPart counts; sounds loaded.
  - Perf stats; public API status.
- **CODE-REVIEWED:**
  - MoveGuard and StealService (whole files: Offence threshold, debt path, succeed, catch order).
  - CarryService.
  - BaseService lock/eject/sell; ConveyorService.Snag.
  - UI scale formula and hint/status geometry; odds/price refresh on panel open.
  - Harness commands used.
- **UNVERIFIED:**
  - All two-player paths: live theft, catch, C1 live, eject of a chasing owner, victim UI, leave cases.
  - Real network-lag behaviour (velocity during real stalls).
  - Phone layouts and in-game visuals (no rendering).
  - 8-player load; real audibility; real purchases (none made); moderation and questionnaire.
  - Rebirth (not re-run this round).

## Decision: FAIL
Gates that decided it:
- Unresolved critical ownership exploit (C1: a smooth-move theft escapes the teleport cancel).
- Data/economy/exploit 5.5 < 7.
- Weighted 7.38 < 8.0.

## Top 5 fixes that would raise the score most
1. **C1:** don't decide theft cancellation from the first excess only.
   - While a stolen carry is in debt, keep measuring the distance from the frozen samples every tick, and Fail once it exceeds TELEPORT_EXCESS. Or Fail on any debt that lasts longer than about 0.5 s during a theft.
   - Retest a 2-client theft with an instant teleport home, a 3x tween home, and a locked base.
2. **M2:** don't trust client velocity for lag credit.
   - Drop the bank re-base, or require the catch-up to be at most the walk distance the stall implies, and cap bank use per 10 s window (e.g. one stall credit per 10 s).
   - Retest a faked stall plus a 45-stud snag, and the 48-stud hop chain.
3. **m2:** a lag-credit design that also works for velocity-0 freezes (e.g. credit only when the catch-up lands on the extrapolated path), and test with real network lag (Studio's network simulator, or a phone on poor Wi-Fi).
4. **m1:** shorten the step-2/step-3 hint variants (or make the hint taller) so TextFits is true, and check text size on a phone once Studio renders.
5. **Real tests:** run a published 2-client private-server pass (theft, catch, leave, lag, C1). The owner then finishes the questionnaire and sets Public (M3).

## State changes made during this audit
- Two single-player playtests started and stopped. Studio is back in **Edit** mode. No code, map, Assets or Creator Hub changes; git still clean at d7ae2da.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - Snagged and placed 4 cheap Goobers (Wobblesworth, Sir Puddle, Blorp, Bean Boi personal drop). That filled the base to 22/22.
  - I sold those plus one older Blorp (5 sells), so the base is back to 19 Goobers (19 uids verified after restart).
  - Coins reset to the starting 13,601,784 (13.67M after accrual on rejoin); level reset to 24 with xp 2746 (I had levelled to 25).
  - Simulated receipt `AUDIT8-1` recorded.
  - Tutorial cycled 0 to 3, then restored to 99.
  - All 6 passes revoked and re-granted.
  - Dex counts and snag/sold stats went up slightly from my tests.
  - Harness save done.
- Plugin-VM loggers and helpers (`_G.SL`, `_G.HB`, `_G.pin`, `_G.walk`) ran inside the playtests only.

# Independent Release Audit - Round 12
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037; Edit mode at start and at end)   Build: dd0ba30 (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau` exactly (same byte length and Adler-32 after CRLF normalisation).

**Environment (checked):**
- The client is not rendering: ViewportSize 1x1, RenderStepped 0 per second, Heartbeat 59 per second, and screen_capture timed out.
- One player only.
- **The starting state differs from the brief.** The base held **22/22** Goobers, not 21/22, at Lv 29 with xp 5081/5278, about 39.55M coins, rebirths 0 and all 6 passes. The builder's test-log entry "base back to 21" doesn't match the saved state.

**Method:**
- **Theft emulator.** As in round 11, I required a fresh clone of the real `MoveGuard` in the server plugin VM. It used a stub registry whose `Offence` copies StealService.luau:224-245, plus a tick loop copying :316-336, including the new `origT` floor. It ran against the live character, whose client HRP was driven by CFrame and velocity every Heartbeat on the clear strip at z = -27. I verified the strip has no collidable parts and that `Map.Ground` is at y = 0. The game's own guard was logged alongside it.
- **Deterministic simulation (new this round).** I ran a second fresh clone of the real `MoveGuard` with `os.clock` replaced by a fake clock (through `getfenv(MG.CarryStep).os`). It ran `CarryStep` against an unparented dummy HRP that I positioned synthetically, with tick dt jittered like the server loop. This is the unmodified module code, so it lets stall phase and speed be swept over 150-200 trials per setting.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:**<br>- Walked to the Pebble Pete stand and sold it (`696931d7047c46c7`, +$25, 22 to 21).<br>- Walked to the belt (2.3 s from base) and snagged a $70 Nugget 8.4 studs away. Walked home and it was placed 1.87 s after the snag (`74a01331685941b4`, stand 4, 22/22, Carrying cleared).<br>- Save, raw store read, stop, start: the same 22 uids and 22 models, the same upgrades and all 6 passes.<br>- Fuzz: 970 malformed fires plus 5 GetQuote invokes. Console clean.<br>**Reliability gap:** theft lag handling still cancels legit thefts depending on stall phase and speed (M1). |
| Simplicity/enjoyment of core loop | 7.5 | Loop unchanged and quick (above). Not seen visually. |
| Replayability/progression | 7.5 | Systems unchanged. Passive XP is about 10/s; Lv 29 to 30 to 31 happened during the session. 6 non-`true` Rebirth fires left rebirths at 0. |
| Visual/Blender/animation/audio | 7.5 | `ReplicatedStorage.Assets`: 25 Goobers and 12 props; 1,726 workspace MeshParts. 27/27 Sounds loaded (11 unique ids), music playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | No UI changes this round. Phone layout UNVERIFIED. |
| Multiplayer/networking/performance | 7.5 | Server 60 FPS, 2,218 parts, about 1.26 MB Lua memory, 10 belt Goobers.<br>The round-11 clustered-stall repro now passes.<br>A phase-dependent stall miss remains (M1): 2.5-5% of single 1-1.5 s stalls cancel at thief speed 20, and 18-22% at top thief speed 29.75. Worse when server ticks jitter. Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 8.5 | m1 is fixed: a 1.15x theft hack now completes at 7.12 s against a floor of 7.04 s and 7.5 s honest (0.84 s early in round 11). A 40-stud hop cancels.<br>The fake-stall hop chain that this change could have opened is bounded: +6 studs per hop stays inside the 1.08x allowance, and +12 per hop flagged at +4, +35 and +56.<br>Fuzz clean, receipt idempotent, persistence verified. |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live, prices match Config, passes are for sale.<br>Receipt `AUDIT12-1` sent twice: +1,028,400 once, replay +0.<br>Free player (all passes revoked): rate 3428 to 1645, cap 22 to 18, walk 20 to 16, luck 1.5 to 1, multiplier 2 to 1, VIP false. Restored afterwards; the rate read 3290 for about 1-2 s before recomputing to 3428. |
| Onboarding/first minute | 7.5 | Unchanged. Not replayed: I didn't wipe the profile, and nothing renders. |

Weighted total: **7.73 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7.5×.10 + 8.5×.10 + 8×.05 + 7.5×.05 = 7.725)

## Critical defects (block release)
None found.

## Major issues
**M1. Whether a stall is recognised depends on sample phase, so legit thefts still get cancelled.** The clustered-stall case is narrowed, but this is the same failure class.

**Mechanism 1: a dead band in `sample()`.**
- A sample counts as "still" if it moved less than `STALL_MOVE` = 1 stud (MoveGuard.luau:136). It counts as "moving" only if it moved at least `0.5*spd*dt` (:160).
- When `0.5*spd*dt > 1`, the last partial sample before a freeze can land between the two. It is then neither still nor moving, so `walkedIn = prev.moving` is false (:138). The stall isn't recognised, and its frozen samples become constraints. The catch-up then flags with excess equal to roughly the stall distance.
- `spd*dt > 2` happens whenever thief speed × tick dt is above 2. That means thief speed 20 or more at nominal dt 0.10-0.12, or lower speeds whenever the server tick stretches.
- **Proof:** in 200 simulated 1.5 s stalls at each speed, every trial whose straddling sample fell in the band cancelled, and no other trial did. Speed 20: 5 BAND (all cancelled), 90 moving, 105 still. Speed 29.75: 37 BAND (all cancelled), 100 moving, 63 still.

Cancel rates from the deterministic simulation (150 trials each, nominal dt 0.10-0.12 s, velocity kept, single-burst catch-up):

| Thief speed | 1.0 s stall | 1.5 s stall | 2.5 s stall |
|---|---|---|---|
| 13.6 or 17 | 0% | 0% | 0% |
| 20 | 0% | 4% | 4% |
| 23.4 | 0% | 9% | 15% |
| 26 | 3% | 11% | 15% |
| 29.75 | 22% | 19% | 16% |

- Thief speed is 0.85 × walk speed (Util.WalkSpeed: 16 + 1.5 × Zoomies level up to 10, +4 with Sprint Boots). Late-game players, who are the likeliest thieves, are at 26-29.75.
- With server tick jitter of 0.10-0.20 s, even speed 17 cancels 15% (single stall) and 16% (1.0 + 1.5 s pair). At 0.10-0.35 s it is 22-25%.

**Mechanism 2: stationary samples inside the catch-up window, and samples lost during debt.**
- A stationary sample within the 1 s catch-up window is never marked C, because `catchup` is set only in the `else` branch (:150-157). A multi-burst catch-up with a pause between bursts therefore creates real constraints at lagging positions.
- Samples aren't recorded while in debt (:419-421). After payoff, the next sample's `prev` is a stale pre-debt sample, so `walkedIn` is false and the next stall isn't recognised.

**Live evidence (theft emulator plus the game's own guard, speed 20):**
- Three stalls (1.0 s with 3 bursts over 0.4 s, 0.6 s walk, 1.5 s with 2 bursts, 0.5 s walk, 2.0 s with 1 burst) cancelled in **2 of 2 runs**:
  - Run 1: `CANCEL excess=23.51` at the third stall; the real guard logged `move +24 studs`.
  - Run 2: the first stall's catch-up flagged `+6` (re-timed for 0.9 s), and the second flagged `+2`. Debug history showed the third stall's samples at x=6 without the S mark, right after a debt gap. Result `CANCEL excess=23.01`.
- Free-roam stalls at speed 29.75 on the real guard:
  - One run flagged **6 of 6** stalls (+20, +15, +10, +17, +12 and +4 studs). Five of those are at or over the theft cancel line of 10. The server was heavily loaded by my monitor polling during that run.
  - An unloaded run flagged 0 of 3.

**What passes now:**
- The exact round-11 repro (walk 1.5, stall 1.0, catch up, walk 0.6, stall 1.5, catch up): 0 offences, real guard silent, `SUCCESS at 7.77`.
- A walk-in of 0.15 s then a 1.5 s stall: success.

Expected (CHANGELOG): "clustered stalls no longer cancel thefts". Actual: they usually pass, but a fixed fraction of single and clustered stalls still cancel, and that fraction grows with speed and server load.

**M2. Store/public status unchanged** (owner-side, not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` still returns "[TITLE UNAVAILABLE]", `isContentRestricted: true` and maxPlayers 0. Votes 0/0.
- The thumbnails API now lists 2 "Completed" thumbnails (the checklist expects 5). Both return the identical imageUrl hash `e436f6cf…`, which may be a placeholder image.

## Minor issues
**m1. A stall that starts as the thief begins walking cancels the theft** (round-11 m3, NOT FIXED).
- Repro: stand 1.2 s (the Steal hold), then a 1.5 s stall with walking velocity before any walking sample registers.
- Result: `CANCEL excess=17.09`; the real guard logged `move +17 studs`. The cause is MoveGuard.luau:138 (`walkedIn` needs a prior walking-pace sample).
- With a 0.15 s walk-in first, the same stall passes.

**m2. A velocity-zero freeze of 1.5 s still cancels** (round-11 note).
- Result: `CANCEL excess=15.88`. In the same run the real guard flagged only +2, because of sampling phase.
- Real network stalls probably keep the last velocity, so this is engine-dependent and UNVERIFIED.

**m3. Constant slack** (round-11 m2, unchanged by design).
- A 1.15x hack still re-times 9-23 times without cancelling. Completion is now bounded by the floor, but the thief gets a spatial lead of a few studs per re-time.

**m4. Brief and test-log state claims are inaccurate.** The base was 22/22 at start, against the "21/22" / "base back to 21" in the brief and QA/test-log.md.

## Retest of previous round's findings
- **R11 M1 (clustered stalls cancel): PARTLY FIXED.**
  - The exact repro passes (0 flags).
  - Three-stall clusters with multi-burst catch-ups still cancelled in 2 of 2 runs.
  - The root cause is wider than clustering (dead band, catch-up window, debt gap); see M1.
- **R11 M2 (store/public): NOT FIXED** (owner-side).
- **R11 m1 (theft speed-hack head start): FIXED.** Completed at 7.12 s against a 7.04 s floor and 7.5 s honest; it was 0.84 s early in round 11. The code is `origT`/`origPos` at CarryService.luau:36, :177 and StealService.luau:334.
- **R11 m2 (constant slack): NOT FIXED** (design tolerance; now m3).
- **R11 m3 (stall after a non-walking walk-in): NOT FIXED** (now m1).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync; environment (no rendering).
  - Sell, belt snag, carry and auto-place.
  - Emulated theft runs:
    - The round-11 M1 repro passes.
    - A 1.5 s velocity-zero freeze cancels.
    - Walk-in variants: a 0.15 s walk-in passes; zero walk-in cancels.
    - The three-stall cluster cancelled twice.
    - The 1.15x hack is floored.
    - A 40-stud hop cancels.
  - Real-guard stall runs at speed 29.75; fake-stall hop chains are bounded.
  - Deterministic sweep of the real MoveGuard code: 3,600 single and paired-stall trials, plus 400 band-classification trials.
  - Fuzz (970 fires plus 5 invokes, console clean); receipt idempotency; marketplace ids and prices; pass revoke and restore.
  - Save, raw store read, stop, start: identical restore.
  - Sounds, templates, MeshParts, perf stats; public API status.
- **CODE-REVIEWED:**
  - The dd0ba30 diff: the MoveGuard `moving` change, and the `origT`/`origPos` floor in CarryService and StealService, including the shift in `ServerMove`.
  - The full MoveGuard: sample, reachable, check, debt and CarryStep.
  - StealService: Offence, the tick loop, succeed, Fail.
  - CarryService; Session.ComputeRate; BaseService.Sell; ConveyorService.Snag; CharacterService.ApplySpeed; the harness commands I used.
- **UNVERIFIED:**
  - All two-player paths: a real theft, catch, victim UI, leave cases.
  - Real network stall behaviour (velocity kept vs zeroed, burst shapes, live server tick jitter).
  - Visuals and phone layout; first-minute onboarding; 8-player load; real audibility; real purchases (none made); maturity questionnaire.

## Decision: FAIL
Deciding gate: weighted total 7.73 < 8.0.
- No category is below 7, there is no critical defect, and the core loop is verified.
- M1 still lets lag cancel legit thefts at a speed- and load-dependent rate. Large areas stay UNVERIFIED (no rendering, one client).

## Top 5 fixes that would raise the score most
1. **M1, dead band.** Stop deciding the walk-in only from the straddling sample's distance.
   - Options: treat `moved >= STALL_MOVE` as moving; or use the replicated velocity of the last pre-freeze sample (at least `STALL_VEL*spd`) as walk-in evidence, which also fixes m1; or look back past a partial sample.
   - Retest with a sweep of thief speeds 13.6-29.75 and tick dt 0.10-0.20 s.
2. **M1, catch-up window and debt gap.**
   - Mark stationary samples within 1 s of a stall end as catch-up.
   - Keep walk-in evidence across debt gaps (record samples while in debt, or carry velocity-based walk-in).
   - Retest the three-stall multi-burst cluster.
3. **Real tests:** a published 2-client private server (theft, catch, cancel vs re-time, leave cases) and one weak-Wi-Fi phone session with a high-speed thief.
4. **Rendering pass:** screenshots of the base, belt and Goobers, and the phone UI via Test -> Device, plus a fresh-profile first-minute run, to earn the visual, UI and onboarding credit.
5. **Owner:** questionnaire, Public audience, and confirm all 5 thumbnails are approved and are not the same placeholder (M2).

## State changes made during this audit
- Two playtests started and stopped; Studio is back in **Edit**. No code, map, Assets or Creator Hub changes; git still clean at dd0ba30.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - **Goobers:** sold Pebble Pete `696931d7047c46c7` (+$25) and snagged a Nugget for $70, which was placed as `74a01331685941b4` on stand 4. The base is 22/22, as at start, with a Pebble Pete swapped for a Nugget. Dex Nugget +1; snag and sold stats +1 each.
  - **Receipt:** `AUDIT12-1` recorded; its 1,028,400-coin grant was subtracted with setCoins.
  - **Level:** passive XP (about 10/s) took it Lv 29 to 31 during play. I reset it to Lv 29, xp 5081 and saved, but it keeps accruing, so it may read Lv 29-30 now.
  - **Coins:** about 44.3M from natural accrual, against about 39.55M at start.
  - **Passes:** all 6 revoked and re-granted.
  - **Saves:** several harness saves.
- Inside the playtest only (not saved): the server Humanoid's WalkSpeed was set to 29.75 for the speed tests, then back to 20.
- No valid-key PromptPass, PromptProduct or BuyUpgrade, and no `Rebirth(true)`, was sent.
- My plugin-VM helpers (`_G.emu`, `_G.SIM`, `_G.drv`, unparented dummy HRP instances) existed only inside the playtests.

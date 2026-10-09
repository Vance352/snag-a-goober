# Independent Release Audit - Round 14
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037). It was in Edit mode at the start and is in Edit mode at the end.   Build: 80cf75b (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau`. I compared byte length and Adler-32 after CRLF normalisation (for example, MoveGuard is 17057 bytes, hash 1524232429, on both sides).

**Environment (checked myself):**
- The client is not rendering: ViewportSize is 1x1, RenderStepped fires 0/s, Heartbeat fires 60/s.
- There is one player.
- The z = -27 strip has no collidable parts except the Map.Boundary walls at the ends.
- Start state: 22/22 Goobers, Lv 30, xp 2253, about 49.58M coins, 6 passes, rebirths 0.
- Client belt Goober pivots are stale because they animate on RenderStepped. Server positions come from the StartX, Dir, Speed and SpawnT attributes.

**Method:**
- **My own fake-clock harness (Edit mode, plugin VM):**
  - Each run uses a fresh unparented clone of the live MoveGuard. `os.clock` is faked, `workspace:Raycast` is stubbed, and ReceiveAge is fixed at 0.1.
  - It runs two models: an "omniscient adversary" that binary-searches the furthest accepted position each tick, and a legit-lag network model.
  - The legit-lag model uses lag of 0.15-0.6 s, 1-4 catch-up bursts with gaps of 0.05-0.45 s, tick jitter, and the StealService cancel rules (excess > 10 studs or 8 s bad).
  - I did not use `tools/guard_sim.luau`.
- **Sensitivity check:** I patched ced4cda's `sample()` and `prune()` into the same harness.
  - It reproduces round-13 C1: a 435.9-stud hop is accepted after a 22 s spoofed idle.
  - It also reproduces round 13's 0% cancel for clusters.
- **Live tests:**
  - The real game guard, with the client HRP driven every Heartbeat on the z = -27 strip.
  - A server monitor polled the harness `guard` command every 0.1 s.
  - The real Snag remote was fired.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Core loop verified:** sold Blorp `44d26997…` (+$5), snagged a $10 Blorp, carried it home, and it was auto-placed as `3c16855f2f7c4e0e` on stand 21 (22/22).<br>**Save/restore:** save, then stop, then start gave 22 identical uids, 22 models, 6 passes, Lv 30, rebirths 0.<br>**Fuzz:** 324 malformed fires and 5 GetQuote invokes; console clean, state unchanged. |
| Simplicity/enjoyment of core loop | 7.5 | Unchanged and quick (above). Not seen visually. |
| Replayability/progression | 7.5 | Systems unchanged. Passive XP keeps accruing (2253 to 4958 during the session). |
| Visual/Blender/animation/audio | 7.5 | No asset changes since round 13 (25 Goobers, 12 props; verified then). In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | No UI changes. Phone layout UNVERIFIED. |
| Multiplayer/networking/performance | **7** | Server 60 FPS, 2,143 parts, about 1.3 MB Lua memory.<br>**Lag tolerance regressed for severe stalls** because of the new 5 s budget (m1). Ordinary stalls of 1-2.5 s still give 0% cancels.<br>Velocity-zero stalls still cancel thefts (m2). Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 7.5 | **C1 is fixed and the bound holds** (see retest). The worst case is a one-off "fog" of up to ~5 s: an instant hop of about 119-122 studs, never chained.<br>Persistence, receipt idempotency and fuzzing are solid. |
| Monetization/compliance | 8 | `verifyMarketplace`: 6 passes and 4 products are live, prices match Config, and all passes are for sale.<br>Receipt `AUDIT14-1` sent twice: +1,030,624 the first time, +0 on replay.<br>Free player (all passes revoked): rate 3424 to 1645, capacity 22 to 18, walk 20 to 16, luck 1.5 to 1, multiplier 2 to 1, VIP false. All restored (rate settles back to 3424 within ~2 s of re-grant). |
| Onboarding/first minute | 7.5 | Unchanged. Not replayed. |

Weighted total: **7.58 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7×.10 + 7.5×.10 + 8×.05 + 7.5×.05 = 7.575)

## Critical defects (block release)
None found this round.

## Major issues
**M1. Store/public status unchanged** (owner-side; not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` returns "[TITLE UNAVAILABLE]", `isContentRestricted: true` and maxPlayers 0.
- The thumbnails API lists 2 Completed thumbnails, both with the same `e436f6cf…` hash. The checklist expects 5.

## Minor issues
**m1. The 5 s STALL_BUDGET regresses lag tolerance for long or clustered stalls, and the checklist overstates the tolerance.**

My legit-lag sim, 100 trials per speed (13.6 / 17 / 20 / 26 / 29.75), theft cancel rates:

| Scenario | Cancel rate |
|---|---|
| Single 1.0 / 1.5 / 2.5 s stall, 2.0 s stall at 0.6 s lag, stall at walk start, 0.10-0.35 s ticks | 0 |
| Single 3.0 s | 0-2% |
| Single 4.0 s | 14-25% |
| Single 4.0 s, one fast catch-up burst | 5-6% |
| Single 4.5 s | 47-59% |
| Single 5.5 s | 100% |
| Pair 1.5 + 1.5 s, 1 s apart | 2-3% (10-15% flagged) |
| Three stalls 1.0 / 1.5 / 2.0 s, 0.6 / 0.5 s apart | **34-82%** |

- ced4cda in the same harness gave 0% for the single 4.0 s stall and for the three-stall cluster. So this is a trade made by the C1 fix.
- **Live free roam:**
  - An emulated 4.0 s stall with a 3-burst 0.9 s catch-up put a legit walker into debt (+10 studs) for 6.7 s.
  - A 5.5 s stall gave debt (+15) for 13.2 s, clearing about 4 s after the player stopped.
  - During that time Snag would be refused with "Whoa, slow down!". There was no 30 s forced return.
- The checklist says "a network stall … of up to ~5 s is forgiven". In practice it is about 3 s once the catch-up is included.
- The test-log does record the cluster limit (~50%).

**m2. Velocity-zero stalls still cancel thefts** (unchanged known limit).
- In my model: a 1.0 s stall cancels 2-35% and a 1.5 s stall cancels 28-67%, with 100% flagged in both.
- The ReceiveAge cue still does nothing in practice. The builder's simulator now models this honestly (ReceiveAge defaults to 0.1).

**m3. Documentation and constant drift.**
- The MoveGuard header (:17) says "at most 4 s past the last real sample", but `STALL_BUDGET = 5.0` (:54).
- `STALL_MAX` (:50) is now unused dead code.
- The checklist says "~100 studs". The measured worst case is 119 studs in carry (ping slack 0.2) and about 122 studs in free roam.

**m4. Constant slack (by design, unchanged).** The omniscient adversary gets 433.8 studs in 20 s at speed 20, a ratio of 1.085, from CARRY_SLACK, REPL_LAG, DIST_SLACK and ping slack.

**m5. Simulator coverage gap.** `guard_sim.luau`'s exploit mode only tests hops after the budget has expired (idle ≥ 6 s). It never asserts the in-budget bound (hop ≤ ~5 s of walking).

## Retest of previous round's findings
- **R13 C1 (spoofed idle, then teleport): FIXED.**
  - **Live 1, round-13 repro:** pinned at (-190, 3, -27) with velocity (20, 0, 0) for 22 s, then a 275.5-stud hop to belt Goober `e89ce6bf…`. The guard showed `debt=true` and "move +50 studs", and Snag 1 s later was refused with "Whoa, slow down!".
  - **Live 2, wiggle-chain:** the same 22 s spoof, with a 1.5-stud wiggle every 4.6 s to re-arm stalls, then a 203.6-stud hop. Debt (+113) and "Whoa, slow down!".
  - **Live 3, inside the budget (expected by design):** a 4.5 s spoof and then a 95.3-stud hop was accepted. Snag passed both the Plausible and range checks and stopped only at "base full". An honest walk takes 4.75 s, so the gain is invisibility, not speed.
  - **Sim, max accepted hop after a spoofed idle** (speed 20, carry rules):
    - 1 s: 34.9 studs; 3 s: 77.0; 5.0 s: 119.0 (walking would be 100).
    - 5.2 s, 6 s, 10 s and 22 s: 15.9 studs. Without the spoof it is 15.9 at every idle length.
  - **Sim, chaining:** the omniscient adversary using stay-then-hop cycles reaches only 0.12-1.10 of the walking distance over 20 s. There is no chaining gain.
  - **Code review:** the newest real sample is never pruned (MoveGuard.luau:242-259). The budget is counted from `lastRealT` (:155-156). A new stall requires `armed` (:160). StealHold and Steal use the same `Plausible()` check (StealService.luau:99, :116).
- **R13 M1 (store/public): NOT FIXED** (owner-side; now M1).
- **R13 m1 (velocity-zero stalls / ReceiveAge): NOT FIXED** (documented known limit; now m2). The test-log correction about ReceiveAge is accurate.
- **R13 m2 (constant slack): NOT FIXED** (by design; now m4).
- **R13 m3 (checklist claim): PARTIALLY FIXED.** The old false claim is gone. The new "~5 s forgiven / ~100 studs" wording is still optimistic (m1, m3).
- **R13 m4 (simulator hygiene): FIXED** (code-reviewed). The trial body is wrapped in a pcall, and `floor:Destroy()` always runs. ReceiveAge now defaults to the measured live behaviour.

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync; environment (no rendering).
  - Three live exploit runs plus one in-budget run.
  - Two live legit long-stall runs.
  - My sim sweeps (about 4,000 trials) on the current and the ced4cda guard.
  - Sell, belt snag, carry and auto-place.
  - Save, raw store read, stop, start: identical restore.
  - Fuzz, clean console.
  - Receipt idempotency; marketplace ids and prices; pass revoke and restore.
  - Public API status.
- **CODE-REVIEWED:**
  - The 80cf75b diff and the full MoveGuard: sample, reachable, prune, check, debt, CarryStep and anchorAt.
  - StealService: HoldBegan, Request, Offence, Fail and the tick loop.
  - The CarryService loop; ConveyorService.Snag; BaseService.Sell.
  - TestHarness; the `guard_sim.luau` diff (not run).
- **UNVERIFIED:**
  - All two-player paths: a real theft, catch, victim UI, leave cases, and spoofed stalls against StealHold.
  - Real-network stall behaviour (velocity kept vs zero, burst shapes).
  - Visuals and phone layout; first-minute onboarding; 8-player load; real audibility; real purchases (none made); maturity questionnaire.

## Decision: FAIL
Deciding gate: the weighted total of 7.58 is below 8.0.
- No critical defect is open, and every category is at 7 or above.
- The other gates are met as far as observable: core loop verified, assets integrated (from round 13, unchanged), round ≥ 3.
- The ceiling is mostly the unverifiable rendering, mobile and two-player areas, plus the severe-lag trade-off.

## Top 5 fixes that would raise the score most
1. **m1: make the lag budget smarter, not shorter, while keeping the C1 bound.**
   - Refresh `lastRealT` from catch-up samples once they have moved forward consistently with walking. Alternatively, let the budget extend while the catch-up is still closing the gap toward the pre-stall real sample's walking envelope.
   - Retest: the three-stall cluster and single 4 s stalls should give ≤ 2% cancels, and the in-budget hop should stay ≤ ~5 s of walking. Add both as assertions in `guard_sim` (m5).
2. **A real 2-client published private-server session:**
   - Theft, catch, re-time vs cancel, thief and victim leaving.
   - Spoofed stall used to approach a victim's stand (StealHold).
   - One weak-Wi-Fi phone session to learn whether real stalls keep their velocity (m2).
3. **Rendered UI and phone pass, plus a fresh-profile first-minute run.** This is the only way to raise the Visual, UI/UX and Onboarding scores above 7.5.
4. **Fix the docs and dead code (m3):**
   - Header "4 s" vs 5.0. Remove `STALL_MAX`.
   - Checklist: "a stall of up to ~3 s (incl. catch-up) is forgiven; a faker can appear up to ~120 studs away once per ~5 s."
5. **Owner items (M1):** questionnaire, Public audience, and all 5 thumbnails approved, then Save and Publish.

## State changes made during this audit
- Two playtests started and stopped; Studio is back in **Edit**.
- No code, map, Assets or Creator Hub changes. Git is still clean at 80cf75b. `guard_sim.luau` was not run. No leftover parts in the workspace.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - **Goobers:** sold Blorp `44d26997bdf94b41` (+$5) and snagged a Blorp for $10, placed as `3c16855f2f7c4e0e` on stand 21. The base is 22/22, as at start. Dex Blorp +1; snag and sold stats +1.
  - **Receipt:** `AUDIT14-1` recorded; its 1,030,624-coin grant was subtracted with setCoins.
  - **Passes:** all 6 revoked and re-granted.
  - **Level:** xp reset to 2253 (Lv 30) and saved.
  - **Coins:** about 51.56M from natural accrual, against about 49.58M at start.
- Inside the playtests only: harness `tp` server moves, and client HRP pinning/driving.
- No valid-key PromptPass, PromptProduct or BuyUpgrade, and no `Rebirth(true)`, was sent.
- Plugin-VM helpers (`_G.AUD` cleared; `_G.drive`, `_G.mon` and similar lived only in the playtest VMs). The MoveGuard clones were unparented and never saved.

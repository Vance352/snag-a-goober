# Independent Release Audit - Round 13
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037). It was in Edit mode at the start and is in Edit mode at the end.   Build: ced4cda (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau`. I compared byte length and Adler-32 after CRLF normalisation, and every one matched.

**Environment (checked myself):**
- The client is not rendering: ViewportSize is 1x1, RenderStepped fires 0 times per second, Heartbeat fires 60.
- There is one player.
- Start state: 22/22 Goobers, Lv 30, xp 1303, about 45.76M coins, all 6 passes, rebirths 0.

**Method:**
- Live tests drove the client HRP every Heartbeat on the clear strip at z = -27. I confirmed it has 0 collidable parts, and Map.Ground's top is at y = 0.
- A server monitor polled the real guard through the harness `guard` command.
- I wrote my own deterministic simulator, separate from `tools/guard_sim.luau`. It runs a fresh clone of the real MoveGuard with a fake `os.clock` and a stub raycast. It drives `CarryStep` with lag of 0.15-0.6 s, 1-4 catch-up bursts with gaps up to 0.45 s, jittered ticks, and the theft cancel rules.
- To check the simulator can find failures, I ran it against dd0ba30's `sample()` patched into the same clone. It reproduces the round-12 failures: single stalls cancel 1-26%, and the three-stall cluster cancels 33-55%.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Core loop verified:** sold Pebble Pete `3d3e5b1a4a964150` (+$25), walked to the belt in 4.27 s, snagged a $10 Blorp, and it was placed 1.60 s into the walk home (`44d26997bdf94b41`, stand 21, 22/22). Save, stop, start gave identical uids, 22 models, the same passes and the same upgrades. Fuzz: 608 malformed fires plus 5 GetQuote calls, console clean, state unchanged.<br>**Theft lag cancels (R12 M1) are fixed** for stalls that keep their velocity. They still cancel when the velocity reads zero (m1). |
| Simplicity/enjoyment of core loop | 7.5 | The loop is unchanged and quick (above). Not seen visually. |
| Replayability/progression | 7.5 | Systems unchanged. Passive XP went from 1303 to 4908 during the session. |
| Visual/Blender/animation/audio | 7.5 | Assets: 25 Goobers and 12 props; 1,778 workspace MeshParts. 27/27 client Sounds loaded (11 unique ids) and music is playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | No UI changes. Phone layout UNVERIFIED. |
| Multiplayer/networking/performance | 7.5 | Server 60 FPS, 2,359 parts, about 1.4 MB Lua memory. Lag tolerance is now robust in simulation and in live single-client tests (see R12 M1 retest). Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | **5** | **New critical regression C1:** after spoofing a "stall" while standing still, a player can teleport anywhere on the map and the guard accepts it. Verified live with the Snag path.<br>Persistence, receipt idempotency and fuzzing are solid. |
| Monetization/compliance | 8 | `verifyMarketplace`: 6 passes and 4 products are live, prices match Config, and all passes are for sale.<br>Receipt `AUDIT13-1` sent twice: +1,027,200 once, replay +0.<br>Free player (all passes revoked): rate 3424 to 1645, capacity 22 to 18, walk 20 to 16, luck 1.5 to 1, multiplier 2 to 1, VIP false. All restored exactly. |
| Onboarding/first minute | 7.5 | Unchanged. Not replayed. |

Weighted total: **7.38 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7.5×.10 + 5×.10 + 8×.05 + 7.5×.05 = 7.375)

## Critical defects (block release)
**C1. Fake stalls chain without limit, so a player who spoofs a stall while standing still can then teleport anywhere on the map** (regression in ced4cda).

**Cause (MoveGuard.luau):**
- A stall now starts on any stationary sample whose velocity reads walking (:148). The walk-in requirement is gone, so standing still can be a stall. The comment that said "Standing still is never a stall" was deleted.
- `STALL_MAX` no longer caps anything. When a stall reaches 3 s, the next sample becomes a catch-up (C) sample (:162-165). Because `not prev.stall` is then true, the sample after that starts a new stall immediately (:148), and the look-back (:152-159) folds the C sample into it. The chain never ends.
- Every S and C sample is skipped as a constraint (:202). Once the last real sample is more than 20 s old, it is pruned (:215-219). The only check left is the `i == 1` fallback against a sample about 20 s old (:202). That gives an allowance of about 20 × 1.08 × 20.35 ≈ 440 studs at walk speed 20. The map is 420 × 300.

**Evidence (live, real game guard and real Snag remote):**
- **Control:** the client stood still at (-190, 3, -27) with velocity 0 for 22 s, then hopped 288 studs to a belt Goober and fired Snag.
  - Result: `debt=true`, `move +41 studs`, and the Snag was refused with "Whoa, slow down!".
- **Exploit:** the same, but the client set AssemblyLinearVelocity to (20, 0, 0) every Heartbeat while pinned. It hopped 256 studs to a belt Goober and fired Snag 1.0 s later.
  - The monitor showed `SC=179/179` history samples marked S or C (oldest `20.10S`). The guard showed `debt=false` with no new flag.
  - The server refused the Snag only with "Your base is full! Sell a Goober or buy More Stands.", which comes after both the Plausible check and the 14-stud range check. With a free stand the snag would have succeeded.
  - An honest walk over that distance takes 12.8 s.
- **Scaling:** a 6 s spoof allowed a 110-stud hop with no flag.

**Impact:**
- Any belt Goober, including Gold line ones, can be grabbed instantly from home. This is the round-1 C3 and round-6 C1 class ("snag anything on the map").
- `StealHold` and `Steal` use the same `Plausible()` check (StealService.luau:99, :116). A thief can therefore appear at a victim's stand without approaching. This is CODE-REVIEWED; there is no second client to try it.
- The carry walking-time floors (`origT`/`MinTravelTime`) still stop a carry finishing early. While spoofing, though, a carry's path is checked only against its start point.

**Repro:**
1. `SAG_Test:Invoke("tp", -190, 3, -27)`.
2. On the client, every Heartbeat set `hrp.CFrame = CFrame.new(-190, 3, -27)` and `hrp.AssemblyLinearVelocity = Vector3.new(20, 0, 0)` for 22 s.
3. Set the CFrame onto a belt Goober about 250 studs away (x from the StartX, Dir, Speed and SpawnT attributes, z = -13).
4. Wait 1 s, then `Remotes.Snag:FireServer(uid)`.

**Expected:** "Whoa, slow down!" (as in the control). **Actual:** the guard accepts the position. Only the full base stopped this snag.

## Major issues
**M1. Store/public status unchanged** (owner-side; not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` returns "[TITLE UNAVAILABLE]", `isContentRestricted: true`, maxPlayers 0, and votes 0/0.
- The thumbnails API now lists only 1 Completed thumbnail, with the same `e436f6cf…` hash as before. The checklist expects 5.

## Minor issues
**m1. Stalls where the replicated velocity reads zero still cancel thefts, and the new ReceiveAge cue does nothing in practice.**
- My simulator, with ReceiveAge fixed at its measured live behaviour, gave these cancel rates:
  - 1.5 s stall with velocity 0: 0/120 at speed 17; 97/120 at 20; 117/120 at 26; 114/120 at 29.75.
  - 1.0 s stall: 0-2/120.
- **Live ReceiveAge measurement:** the client anchored its HRP for 2 s. Server `ReceiveAge` stayed between 0.087 and 0.128 s; it never grew.
- So the builder's test-log row "velocity 0 (ReceiveAge cue on) → 0%" only holds in `guard_sim.luau`'s default mode, which fakes ReceiveAge growing during the stall. It is not evidence about real networks.
- Whether real stalls keep their velocity is engine-dependent and UNVERIFIED.

**m2. Constant slack (by design, unchanged).** The ACTION_SLACK, CARRY_SLACK, DIST_SLACK and REPL_LAG constants and the `origT` floor are unchanged (CODE-REVIEWED). Not re-measured.

**m3. Release checklist claim is now false.** RELEASE_CHECKLIST.md "Known limitations" says "a lag stall of up to ~3 s is forgiven, and a cheater faking that pattern can at best match walking speed". In this build, stalls chain without limit and allow instant hops of up to about 20 s of walking (C1).

**m4. Tool hygiene.** `tools/guard_sim.luau` parents an anchored `GuardSimFloor` Part to the workspace and has no pcall around the trial loop. If it is run in Edit mode and errors mid-run, the part stays in the place and could be saved. I didn't run it.

## Retest of previous round's findings
- **R12 M1 (phase-dependent stall misses cancel thefts): FIXED for stalls that keep a walking velocity.**
  - My simulator, 120-150 trials per cell, speeds 13.6-29.75: 0 cancels and 0 flags for single 1.0, 1.5, 2.5, 3.0 and 5.0 s stalls; the three-stall cluster (1.0, 1.5, 2.0 s); tick jitter 0.10-0.35 s; lag 0.15 and 0.6 s.
  - With burst gaps up to 0.45 s and 4 bursts: 1 flag of 0.8 studs, 0 cancels.
  - The same simulator on dd0ba30's `sample()` cancelled 1-55%.
  - Live (real guard plus a CarryStep emulator on the real HRP), a cluster of five stalls, where the first starts at walk start: speed 20 gave 0 emulator flags and no real-guard flag; speed 29.75 gave the same.
  - **The fix introduced C1.**
- **R12 M2 (store/public): NOT FIXED** (owner-side; now M1).
- **R12 m1 (stall at walk start): FIXED** in simulation (0/120 at every speed) and live (0 flags). This holds only if the last packet carried a walking velocity; otherwise it falls under m1 of this round.
- **R12 m2 (velocity-zero freeze): NOT FIXED** (now m1; 81-98% cancel at speed 20 and above in simulation).
- **R12 m3 (constant slack): NOT FIXED** (by design; now m2).
- **R12 m4 (inaccurate state claims): FIXED.** The test-log now records the correction, and the brief's 22/22 matched the saved state.

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync; environment (no rendering).
  - Sell, belt snag, carry and auto-place.
  - Save, raw store read, stop, start: identical restore.
  - Fuzz: 608 fires plus 5 invokes, console clean.
  - Receipt idempotency; marketplace ids and prices; pass revoke and restore.
  - C1 exploit plus its control (live, three runs).
  - Live lag clusters at speeds 20 and 29.75.
  - ReceiveAge behaviour.
  - My deterministic sweep (about 6,000 trials) of the current and previous MoveGuard.
  - Sounds, templates, MeshParts and perf; public API status.
- **CODE-REVIEWED:**
  - The ced4cda MoveGuard diff and the full MoveGuard: sample, reachable, prune, check, debt and CarryStep.
  - StealService: HoldBegan, Request, Offence and the tick loop.
  - CarryService loop; ConveyorService.Snag; BaseService.Sell; the harness commands I used; `tools/guard_sim.luau` (not run).
- **UNVERIFIED:**
  - All two-player paths, including a real theft, catch, victim UI, leave cases and C1 applied to `StealHold`.
  - Real network stall behaviour.
  - Visuals and phone layout; first-minute onboarding; 8-player load; real audibility; real purchases (none made); maturity questionnaire.

## Decision: FAIL
Deciding gates:
- An unresolved critical security defect (C1: the movement guard accepts a teleport after a spoofed idle).
- A category below 7 (exploit resistance: 5).
- Weighted total 7.38 < 8.0.

## Top 5 fixes that would raise the score most
1. **C1: bound fake stalls again** without bringing back the dead band.
   - Never let the last real (non-S/C) sample be pruned or skipped. Have the `i == 1` fallback check that sample, not `list[1]`.
   - Cap the stall-plus-catch-up time allowed since the last real sample (about STALL_MAX + 1 s). After that, every sample is a real constraint, and a new stall can only start after a real sample has moved at least STALL_MOVE.
   - Retest: stand still with a spoofed velocity for 5, 10 and 22 s, then hop 100-290 studs. It must flag. Re-run the round-12 and round-13 lag sweeps to confirm the 0% cancel rates hold.
2. **Add the C1 repro to `guard_sim.luau`** (a spoofed idle followed by a hop, in free roam and in carry) and assert that it flags. Make the simulator's ReceiveAge default match the measured live behaviour (it does not grow).
3. **m1: decide on velocity-zero stalls.** Either measure real stall packets on a weak network, or accept the risk and document it. Don't count the ReceiveAge cue as mitigation.
4. **Real tests:** a published 2-client private server (theft, catch, cancel vs re-time, leave cases, plus C1 against StealHold), and one weak-Wi-Fi phone session.
5. **Owner and rendering:** questionnaire, Public audience, confirm all 5 thumbnails (M1); a rendered and phone UI pass, and a fresh-profile first-minute run.

## State changes made during this audit
- Two playtests started and stopped; Studio is back in **Edit**. No code, map, Assets or Creator Hub changes. Git is still clean at ced4cda. I never ran `guard_sim.luau`.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - **Goobers:** sold Pebble Pete `3d3e5b1a4a964150` (+$25) and snagged a Blorp for $10, placed as `44d26997bdf94b41` on stand 21. The base is 22/22, as at start, with a Pebble Pete swapped for a Blorp. Dex Blorp +1; snag and sold stats +1 each.
  - **Receipt:** `AUDIT13-1` recorded; its 1,027,200-coin grant was subtracted with setCoins.
  - **Passes:** all 6 revoked and re-granted.
  - **Level:** reset to Lv 30, xp 1303 (passive XP had taken it to 4908), then saved.
  - **Coins:** about 48.23M from natural accrual, against about 45.76M at start.
- Inside the playtest only (not saved):
  - Harness `tp` server moves.
  - The server Humanoid's WalkSpeed was set to 29.75 for one live test, then back to 20.
- No valid-key PromptPass, PromptProduct or BuyUpgrade, and no `Rebirth(true)`, was sent.
- My plugin-VM helpers (`_G.run`, `_G.drive`, `_G.mon`, `_G.emu`, `_G.SIM2`, cloned MoveGuard modules, unparented dummy instances) existed only inside the playtests.

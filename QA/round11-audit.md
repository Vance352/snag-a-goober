# Independent Release Audit - Round 11
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037; Edit mode at start and at end)   Build: 3e8208b (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau` exactly (same byte length and Adler-32 after CRLF normalisation). There are no other scripts in Workspace, StarterGui, StarterPack, ReplicatedFirst or StarterCharacterScripts.

**Environment (checked):**
- The client is not rendering: ViewportSize 1x1, RenderStepped 0/s, Heartbeat 61/s, and screen_capture timed out.
- One player only.
- **State at start differs from the brief.** The base held 22/22 Goobers (not 21/22), at Lv 29, xp 2007, 34.8M coins, rebirths 0.

**Method for theft lag tests:**
- A real two-player theft can't be run here.
- In the server plugin VM I required a fresh copy of the real `MoveGuard` module, passing in a stub registry. Its `Offence` and per-tick rules copy StealService.luau:224-245 and :316-336: cancel when excess > 10 or `badSince` > 8 s, otherwise re-time. Completion uses `MinTravelTime`.
- That copy ran against the real character's positions alongside the game's own guard. The game's real guard flags were logged too, and matched the copy in every run.
- The emulator flagged a harness teleport (+78 studs) on its own, which confirms it works.
- Movement was driven on the client by setting HRP CFrame and velocity every Heartbeat, in the open strip at z = -27. I checked that strip has no collidable parts.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:**<br>- Sold a Toastie at its stand ($15). Snagged a $10 Blorp from the belt (8 studs away), carried it home through a 1.5 s stall and it was placed: used 21 to 22, Carrying cleared.<br>- Save, raw store read, stop, start: the same 22 uids came back, with Lv 29, rebirths 0, tutorial 99, the same upgrades, all 6 passes and 22 base models.<br>- 636 malformed remote fires plus 4 GetQuote invokes: console clean (only the harness and server-ready lines).<br>**Reliability gap:** clustered lag still cancels a theft (M1). |
| Simplicity/enjoyment of core loop | 7.5 | Loop unchanged and quick: belt snag about 4.6 s after leaving the base, home about 8.8 s. Not watched visually. |
| Replayability/progression | 7.5 | Systems unchanged. Rebirth confirm guard still holds: 6 non-`true` Rebirth fires left rebirths at 0. |
| Visual/Blender/animation/audio | 7.5 | 25 Goober and 12 prop templates; 1,851 workspace MeshParts. 27/27 Sounds loaded, music playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | No UI changes this round. Phone layout UNVERIFIED. |
| Multiplayer/networking/performance | 7.5 | Server 60 FPS, 2,157 parts, about 1.3 MB Lua memory.<br>Single stalls are now forgiven up to 2.8 s, and a 1.0 s velocity-0 freeze now only re-times.<br>Residual M1: a second stall that starts within about 1 s of a catch-up cancels a theft.<br>Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 8 | Fuzz clean; receipt idempotent; persistence solid.<br>Faked-stall credit is gone (m1 fixed). Over-capacity earning is fixed (m2).<br>New and minor: the looser theft-cancel rule lets a 1.15x speed hack finish a 150-stud theft about 0.84 s early without being cancelled (m1 below). |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live, prices match Config, passes are for sale.<br>Receipt `AUDIT11-1` sent twice: +1,013,400 once, replay +0.<br>Free player (all passes revoked): rate 3378 to 1620, cap 22 to 18, walk 20 to 16, luck 1.5 to 1, multiplier 2 to 1, VIP false. Restored afterwards. |
| Onboarding/first minute | 7.5 | Unchanged. Not replayed: I did not wipe the profile, and nothing renders. |

Weighted total: **7.68 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7.5×.10 + 8×.10 + 8×.05 + 7.5×.05 = 7.675)

## Critical defects (block release)
None found.

## Major issues
**M1. Clustered lag stalls still cancel a legit theft** (narrowed residual of R10 M1). VERIFIED in the theft emulator and in the game's own guard. This is a faithful pattern: walking velocity is kept during the stall.

Root cause:
- A stall is only recognised if the sample before it was "moving" (`walkedIn = prev.moving`, MoveGuard.luau:138).
- Samples within 1 s after a stall are catch-up samples, and those always get `moving = false` (:155-159).
- So a second stall that starts within about 1 s of the first one's catch-up is not treated as a stall. Its stationary samples become constraints, and the catch-up is flagged.

Repro (z = -27, speed 20): walk 1.5 s, stall 1.0 s, catch up 20 studs, walk 0.6 s, stall 1.5 s, catch up 30 studs, walk.
- **Result:** the real guard logged `move +17 studs`, and the emulated theft logged `CANCEL debt excess=16.77`. Debug history showed the second stall's samples at -107 without the "S" mark, and the walk-in samples marked "C".
- **The same thing happened by accident in the real belt carry:** a catch-up walk followed by a 1.5 s stall gave `move +15 studs`. In a theft that is over 10, so it cancels.
- **With a 1.0 s + 1.0 s pair 0.5 s apart:** +6 studs, re-time only, no cancel. So the cancel needs a second stall longer than about 1.2-1.3 s.

Also note:
- A velocity-0 freeze of 1.5 s cancels (+17). Whether a real network stall keeps the last velocity is UNVERIFIED engine behaviour.
- A single 3.0 s stall cancels (+36). The 2.8 s case passes. That limit (STALL_MAX) is a design choice.

Expected (builder's claim): "lag-sized flags re-time". Actual: clustered stalls on weak Wi-Fi still end the theft.

**M2. Store/public status unchanged** (owner-side, not scored against the build).
- `games.roblox.com/v1/games?universeIds=10769928826` still returns "[TITLE UNAVAILABLE]", `isContentRestricted: true` and maxPlayers 0. Votes 0/0.
- The thumbnails API lists only 1 completed thumbnail (the checklist expects 5).

## Minor issues
**m1. A theft speed hack gains a bounded head start** (new; a trade-off from the looser cancel rule).
- The cancel rule went from "debt over 1 s" to "excess over 10 or 8 s" (StealService.luau:232).
- A re-time anchors at the hacker's last trusted sample, which is already ahead of where a walker would be (:236-239). Each carry-trail flag also resets the trail (:240), so the earlier lead is never checked again.

| Hack | What happened | Result |
|---|---|---|
| 1.15x (23 studs/s), 150 studs | 22 re-times, no cancel | Home after 6.58 s of moving, against 7.42 s honest |
| 1.3x | Main guard flagged at 2.0 s; excess passed 10 at 4.3 s | Cancelled |
| 40-stud hop | | Cancelled at +28 |

A hacker who manages the excess can get about 0.8 s per theft.

**m2. Constant slack** (R10 m3, reduced). REPL_LAG dropped from 0.5 to 0.35 s.
- From standing, an 11-stud part of a 30-stud hop was still accepted instantly.
- A walk-in plus a spoofed 2.8 s stall plus a 70-stud hop was accepted: about 13 studs (0.65 s) beyond walking, the same as the plain slack. Design tolerance.

**m3. Stalls aren't recognised when the walk-in isn't at walking pace** (CODE-REVIEWED, MoveGuard.luau:159).
- This covers a stall right after the thief stands still to hold the Steal prompt, or a slow thumbstick walk.
- A 1.5 s stall right at theft start, as the thief begins walking, would cancel. Rare.

## Retest of previous round's findings
- **R10 M1 (lag-sized flags cancel thefts): PARTLY FIXED.**
  - Velocity-kept single stalls of 1.0, 1.5, 2.0 and 2.8 s gave 0 flags.
  - A 2.5 s stall with a 3-burst catch-up gave 0 flags.
  - 1.0 + 1.5 + 2.0 s stalls (the last with 4 bursts over 1.6 s) gave 0 flags.
  - A 1.0 s velocity-0 freeze gave +1 stud, 0.33 s of debt and a re-time (no cancel).
  - Remaining: clustered stalls and 1.5 s velocity-0 freezes still cancel (new M1).
- **R10 M2 (store/public): NOT FIXED** (owner-side).
- **R10 m1 (faked stall stores a hop): FIXED.**
  - Spoofed velocity while standing for 2.8 s gave no credit: a hop flagged at +15.
  - Credit can no longer be held: no bank, and STALL_MAX is 3 s (MoveGuard.luau:139).
- **R10 m2 (over-capacity earning): FIXED.** After revoking ExtraSlots, the rate was 3240, exactly 2 × the income of stands 1-18 (1620). Session.luau:129-132.
- **R10 m3 (constant slack): PARTLY FIXED** (reduced; now m2).
- **R9 m3 (slow-walk bank): N/A.** The bank was removed (CODE-REVIEWED).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync; environment (no rendering).
  - Sell, belt snag, carry with a stall, auto-place.
  - 19 lag and exploit scenarios, emulated against the real MoveGuard code (above).
  - Pass revoke and restore; m2 fix; fuzz (636 fires plus 4 invokes, console clean); receipt idempotency; marketplace ids and prices.
  - Save, raw store read, stop, start: identical restore.
  - Sounds, templates, MeshParts, perf stats; public API status.
- **CODE-REVIEWED:**
  - Full new MoveGuard: sample, stall and catch-up marking, reachable, debt with ping slack, CarryStep's `debtExcess`.
  - StealService: Offence, the tick loop, succeed, Fail.
  - CarryService; Session.ComputeRate and Capacity; BaseService.Sell; ConveyorService.Snag; the harness commands I used.
- **UNVERIFIED:**
  - All two-player paths: a real theft, catch, cancel and re-time in a live theft, lock, victim UI, leave cases.
  - Real network stall behaviour (velocity kept vs zeroed, how often stalls cluster).
  - Visuals and phone layout; first-minute onboarding replay; 8-player load; real audibility; real purchases (none made); maturity questionnaire.

## Decision: FAIL
Deciding gate: weighted total 7.68 < 8.0.
- No category is below 7, there is no critical defect, and the core loop is verified.
- The score is held down by M1 (clustered lag still cancels thefts) and by how much stays UNVERIFIED with no rendering and one client.

## Top 5 fixes that would raise the score most
1. **M1:** don't lose the walk-in through catch-up samples.
   - For example: let a catch-up sample count as "walked in" when it continues the pre-stall walk at or below walking pace from the last real sample, or carry `walkedIn` forward through C samples.
   - Retest stall 1.0 s, 0.6 s gap, stall 1.5 s, and a 1.5 s velocity-0 freeze, in a theft.
2. **m1:** during a theft, also keep the original constraint: completion no sooner than `MinTravelTime(original steal spot → home)` from the original start time. Or re-anchor at the oldest trusted sample instead of the newest, so trail resets can't hide a speed hack's lead.
3. **Real tests:** run a published 2-client private server (theft, catch, cancel vs re-time, leave cases), plus one weak-Wi-Fi phone session.
4. **Rendering pass:** screenshots of the base, belt and Goobers, and the phone UI via Test -> Device, plus a fresh-profile first-minute run, to earn the visual, UI and onboarding credit.
5. **Owner:** questionnaire, Public audience, and confirm all 5 thumbnails are approved (M2).

## State changes made during this audit
- Two playtests started and stopped; Studio is back in **Edit**. No code, map, Assets or Creator Hub changes; git still clean at 3e8208b.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - **Goobers:** sold Toastie `b6b759951fc747c7` (+$15) and snagged a Blorp for $10, which was placed as `54200e7cd0b44daf`. The base is 22/22 again, with a Toastie swapped for a Blorp.
  - **Receipt:** `AUDIT11-1` recorded; its 1,013,400-coin grant was subtracted with setCoins.
  - **Level:** it reached Lv 30, so I reset it to Lv 29, xp 2007. It now reads xp 2107 from accrual.
  - **Passes:** all 6 revoked and re-granted.
  - **Coins:** about 37.28M from natural accrual, against 34.8M at start.
  - **Other:** Dex Blorp 8 to 9; snag and sold stats +1; one harness save.
- No valid-key PromptPass/PromptProduct or Rebirth(true) was sent.
- My plugin-VM helpers (`_G.emu`, `_G.drv`) ran inside the playtests only.

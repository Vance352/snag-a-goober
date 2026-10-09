# Independent Release Audit - Round 10
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037; in Edit mode at start and end)   Build: 0486f3e (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau` exactly (same byte length and Adler-32 after CRLF normalisation).

**Environment (checked):**
- The client is not rendering: ViewportSize 1x1, RenderStepped 0/s, Heartbeat about 59/s.
- One player only.
- Movement was driven on the client by setting HRP CFrame and velocity every Heartbeat. A server logger read the harness `guard`/`notes` every 0.1 s.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:**<br>- Legit snag of a Toastie, carried and placed, then sold for $15 (base back to 21/22).<br>- 4 more snags followed by Drop refunds.<br>- Save, raw store read, stop, start: the same 21 uids came back, with Lv 25, rebirths 0, tutorial 99, upgrades {Speed 0, Slots 12, Income 0, Lock 0}, all 6 passes and 21 base models.<br>- 759 malformed remote fires plus 4 bad GetQuote invokes: console clean (only the harness and server-ready lines). |
| Simplicity/enjoyment of core loop | 7.5 | Loop unchanged and quick. Not watched visually (no rendering). |
| Replayability/progression | 7.5 | Systems unchanged. Rebirth is now guarded by a confirm flag. Levelling and upgrades work (the fuzz bought Speed Lv1 with a valid key, as designed). |
| Visual/Blender/animation/audio | 7.5 | 25 Goober and 12 prop templates; 1,778 workspace MeshParts. 27/27 Sounds loaded, music playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | The only UI change is the rebirth button now sending `true`. Phone layout and legibility UNVERIFIED. |
| Multiplayer/networking/performance | 7.5 | Server about 60 FPS, 2,145-2,357 parts, about 1.3 MB Lua memory.<br>R9 M1's repro pattern now passes, plus several more stall patterns (see Retest).<br>New M1: lag-sized main-guard flags still last over 1 s, which cancels a theft.<br>Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 8 | Fuzz clean; receipt idempotent; persistence solid; rebirth needs `true`.<br>Sideways faked stalls no longer earn credit.<br>Residual: an aimed faked stall still stores an instant ~40-stud hop (m1).<br>Sustained 1.3x carry flagged about 3 s in. |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live, prices match Config, passes are for sale.<br>Receipt `AUDIT10-1` sent twice: +1,014,972 coins once, replay +0.<br>Free player (all passes revoked): rate 3372 to 1686, cap 22 to 18, walk 21.5 to 16, luck 1.5 to 1, multiplier 2 to 1, VIP false. Restored afterwards. |
| Onboarding/first minute | 7.5 | Unchanged since R9 (hints fit). The first minute was not observed visually; I did not wipe the store to replay it. |

Weighted total: **7.68 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7.5×.10 + 8×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
None found this round.

## Major issues
**M1. Lag-sized main-guard flags still cancel thefts, because the debt takes over 1 s to walk off.** VERIFIED on belt carries, which use the same main guard and `CarryStep` as thefts. The theft consequence is CODE-REVIEWED.

How the code gets there:
- `StealService.Offence` cancels when `now - carry.badSince > 1.0` (StealService.luau:229-231).
- While the main guard is in debt, `CarryStep` returns `false, f[#f], 0` on every tick (MoveGuard.luau:357-359). So `badSince` is never cleared, and any main-guard debt lasting over 1 s ends the theft, however small the excess.
- Debt clears slowly while the player keeps walking:
  - The allowance only grows 8% faster than walking: 1.6 studs/s at speed 20, 1.36 at the thief's 17.
  - The debt check drops the ping slack (`extra = 0` at :228, against `pingSlack` at :248).

Evidence (carrying a belt Goober, walking at 20):
- **1.0 s freeze with velocity 0, 3-burst catch-up:** flag "move +1 studs", 2.3 s of debt plus a "No shortcuts!" toast. Repeated: "+0 studs", 2.0 s of debt plus the toast.
- **2.0 s stall with walking velocity kept:** "+1 studs", 2.2 s of debt plus the toast. A second run passed, so this is borderline.
- **Patterns that pass now (no debt, no toast):**
  - R9's two 1.0 s stalls 3.5 s apart.
  - A 1.5 s stall then a 1.0 s stall, 5 s apart.
  - Three 0.8 s stalls.
  - Single stalls of 1.6 s and 1.8 s.
  - 1.0 s and 1.2 s stalls with a single-jump catch-up.
  - Velocity-0 freezes of 0.6 s and 0.8 s.

Repro: carry, walk, freeze 1 s with velocity 0 (or stall about 2 s), catch up, keep walking. Watch `guard.debt`.

Expected (builder's claim): "a brief, lag-sized flag only re-times". Actual: a +0/+1-stud flag leads to over 1 s of debt, and in a theft that means `Fail("teleport")`. The re-time path only helps when `CarryStep` flags alone. How often real networks produce these patterns is UNVERIFIED.

**M2. Store/public status unchanged** (owner-side, not scored against the build). `games.roblox.com/v1/games?universeIds=10769928826` still returns "[TITLE UNAVAILABLE]", `isContentRestricted: true` and maxPlayers 0. Votes 0/0.

## Minor issues
**m1. A faked stall aimed at the target still stores an instant hop** (R9 M2 residual, downgraded).

Each trial: tp, 1.3 s settle, stand pinned with HRP velocity set, then a CFrame hop to a belt Goober and Snag fired every 0.21 s.

| Velocity during the stall | Stall | Hop | Snagged after the hop | Walking would take |
|---|---|---|---|---|
| 20, aimed at the target | 1.8 s | 34.1 studs | 0.43 s | 1.71 s |
| 20, aimed at the target | 6.0 s | 39.8 studs | 0.65 s | 1.99 s |
| 20, sideways | 1.8 s | 35.1 studs | 1.08 s | 1.75 s |
| none | 1.8 s | 35.2 studs | 1.30 s | 1.76 s |

- The direction check works: sideways velocity earns nothing.
- Counted from the start of the stall, the aimed hop is no faster than walking.
- But the credit can be held indefinitely, so an exploiter can wait out of sight and then appear about 1.3 s early in a ±45° cone. That matters for racing a rare belt spawn or approaching a victim base.

**m2. Revoking ExtraSlots leaves the base over capacity** (R9 m1, not fixed). Capacity dropped to 18, used stayed 21, and all 21 kept earning (rate 3372 to 1686, which is the DoubleCoins halving only). This only matters on a refund or revoke.

**m3. Constant movement slack.** With no stall credit at all, a 35-stud CFrame hop was accepted 1.08-1.30 s after the hop, against 1.75 s of walking. That is about 0.5 s of head start per hop, from REPL_LAG plus 2.5 studs plus ping. It is a design tolerance; noted only.

## Retest of previous round's findings
- **R9 M1 (lag cancels legit thefts): FIXED for the reported pattern.** Two 1.0 s stalls 3.5 s apart, and a 1.5 s plus a 1.0 s stall 5 s apart, gave 0 debt and 0 toasts. A residual remains (new M1: a 1 s velocity-0 freeze, or about 2 s stalls).
- **R9 M2 (faked-stall teleport): PARTLY FIXED.** Sideways spoofing is blocked; aimed spoofing still gives a 0.43 s snag (now m1).
- **R9 M3 (store/public): NOT FIXED** (owner-side).
- **R9 m1 (over-capacity after revoke): NOT FIXED.** Code unchanged; re-observed 21 Goobers at capacity 18.
- **R9 m2 (rebirth without confirm): FIXED.**
  - VERIFIED: `Rebirth:FireServer()` with no argument, `1`, `"true"`, `{true}` and `false` left rebirths at 0. ProgressService.luau:150 requires `confirmed == true`.
  - CODE-REVIEWED: the client sends `true` only on a second tap within 3 s (UI.luau:513-522).
- **R9 m3 (slow-walk bank): UNVERIFIED** (not retested this round).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync; environment (no rendering).
  - Core loop: legit snag, carry, place and sell; Drop refunds.
  - Stall matrix (12 runs, results above); sustained 1.3x carry flagged.
  - Faked-stall hop trials: aimed, aimed with a 6 s stall, sideways, still.
  - Rebirth flag guard; fuzz (759 fires plus 4 invokes, console clean).
  - Free-player pass revoke and restore; over-capacity; receipt idempotency; marketplace ids and prices.
  - Save, raw store read, stop, start: identical restore.
  - Sounds, templates, MeshParts, perf stats; public API status.
- **CODE-REVIEWED:**
  - Full MoveGuard (bankAt, record, reachable direction cap, debt and forgiveness, CarryStep).
  - Full StealService (Offence re-time and cancel rules, the steal loop, succeed, Fail).
  - CarryService; ConveyorService.Snag; BaseService.Sell; ProgressService.Rebirth and BuyUpgrade; the Main remote wrapper; the harness commands I used.
  - Re-time logic: it anchors at a trusted sample, so it never shortens the remaining walk.
- **UNVERIFIED:**
  - All two-player paths: live theft, catch, cancel and re-time in a real theft, lock and eject, victim UI, leave cases.
  - Real network stall behaviour: velocity kept vs zero, and how often stalls cluster.
  - In-game visuals and phone layout; first-minute onboarding replay; 8-player load; real audibility; real purchases (none made); moderation and the questionnaire.

## Decision: FAIL
Deciding gate: weighted total 7.68 < 8.0.
- No category is below 7, and no unresolved critical defect was found. The core loop is verified.
- The score is held down by M1 (a lag-sized flag still ends a theft once the debt passes 1 s).
- It is also held down by how much stays UNVERIFIED with no rendering and one client (visuals, mobile, onboarding, two-player play).

## Top 5 fixes that would raise the score most
1. **M1:** don't fail a theft just because the debt lasted over 1 s when the excess is small.
   - For example: cancel only if the excess grows or tops TELEPORT_EXCESS. Or keep pingSlack in the debt check. Or, on a small-excess debt, re-anchor and re-time instead of waiting for the walk-off.
   - Retest a 1.0 s velocity-0 freeze and a 2.0 s stall with walking velocity, during a real theft.
2. **m1:** make stored stall credit expire (for example after about 2 s), or earn it only when the samples before the stall actually moved at the reported velocity in that direction, so spoofed velocity while standing still earns nothing.
3. **Real tests:** run a published two-client private server covering theft, catch, lock and eject, leave cases, cancel vs re-time, and real poor-network lag (Studio network simulation or a phone on weak Wi-Fi).
4. **Rendering pass:** screenshots of the base, belt, Goobers and phone UI (16:9 and 4:3), plus a fresh-profile first-minute run, to earn the visual, UI and onboarding credit.
5. **Owner and cleanup:** finish the maturity questionnaire and go Public (M2). Clamp or stop earning for an over-capacity base (m2).

## State changes made during this audit
- Two single-player playtests started and stopped; Studio is back in **Edit**. No code, map, Assets or Creator Hub changes; git still clean at 0486f3e.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - **Goobers:** 5 cheap ones snagged. The Toastie was placed, then sold ($15). Sir Puddle x2, Nugget and Blorp were dropped for refunds. The base holds the original 21 uids (verified after restart).
  - **Fuzz side effect:** it bought Speed Lv1 (a valid key). I reset Speed to 0 and refunded the 50 coins.
  - **Receipt:** `AUDIT10-1` recorded; its 1,014,972-coin grant was subtracted.
  - **Level:** it reached Lv 26 from the placement XP and AutoCollect, so I reset it to Lv 25, xp 2188. It now reads xp 2338 from accrual.
  - **Passes:** all 6 revoked and re-granted.
  - **Coins:** 21.97M now, against 19.51M at start, from natural AutoCollect and offline accrual.
  - **Other:** Dex Toastie +1; snag and sold stats went up; one harness save.
- No PromptPass/PromptProduct was fired with a valid key, so no purchase prompts were opened.
- My plugin-VM helpers (`_G.drive`, `_G.hopTrial`, `_G.logRun`, etc.) ran inside the playtests only.

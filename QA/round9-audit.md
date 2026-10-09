# Independent Release Audit - Round 9
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober" (Studio 99449037, in Edit mode at start and end)   Build: 88c2f58 (main HEAD; git clean before and after)

**Script sync:** all 30 Studio scripts match `src/*.luau` exactly (same length and Adler-32 after CRLF normalisation).

**Environment (checked):**
- Client ViewportSize 1x1, RenderStepped 0/s, Heartbeat 60/s, so nothing is rendering.
- One player only. Timings come from a server log of the harness `guard` state and HRP position every 0.1 s, plus the harness `notes` toasts/errors.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8 | **Verified:**<br>- Legit MoveTo snag of G02_SirPuddle off the Main belt; carried 35 studs home and placed about 2.3 s after the snag, with no debt and no toast.<br>- 9 snag/carry/place/sell cycles worked.<br>- Persistence round trip: save, raw store read, stop, start. The same 21 uids came back with Lv 25, rebirths 0, tutorial 99, all 6 passes and 21 base models.<br>- 792 malformed remote fires plus 10 GetQuote invokes caused no script errors. The console was clean in both playtests. |
| Simplicity/enjoyment of core loop | 7.5 | Loop unchanged and quick. Not watched visually (no rendering). |
| Replayability/progression | 7.5 | Unchanged systems. A rebirth ran (by accident, through the fuzz) and behaved as coded: rebirths +1, coins reset, Goobers kept, multiplier 1.5. Restored afterwards. |
| Visual/Blender/animation/audio | 7.5 | 25 Goober templates; 1,766 workspace MeshParts. 27/27 sounds loaded, music playing. In-game look UNVERIFIED (no rendering). |
| UI/UX and mobile | 7.5 | R8 m1 fixed: all 6 tutorial hint texts give TextFits=true at UIScale 0.62 (label 146x33 px). Phone legibility UNVERIFIED on a device. |
| Multiplayer/networking/performance | 7 | Server 60 FPS, 2,152 parts, about 1.3 MB Lua memory. **New M1:** lag tolerance is now one stall per 10 s, and any violation during a theft cancels it. Two real 1 s lag stalls within 10 s, or a 1 s freeze with velocity 0, now lose a legit theft. Two-player paths UNVERIFIED. |
| Data persistence/economy/exploit resistance | 7.5 | C1 fixed: any violation during a theft now ends it. Hop chain fixed (about 1.01x walk). Receipts, fuzz and persistence are solid. **Still open:** one faked-stall teleport per 10 s (M2; snag 0.27 s after a 46-stud hop). |
| Monetization/compliance | 8 | `verifyMarketplace`: all 6 passes and 4 products are live, prices match Config, passes are for sale. Receipt `AUDIT9-1` sent twice: +1,010,758 once, the replay changed nothing. Free-player values after revoking all passes: rate 3358 to 1679, cap 22 to 18, WalkSpeed 20 to 16, luck 1.5 to 1, VIP false. All passes restored. |
| Onboarding/first minute | 7.5 | Hint texts now fit. The first minute was not observed visually. |

Weighted total: **7.58 / 10** (8×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7.5×.10 + 7×.10 + 7.5×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
None found this round.

## Major issues
**M1. Real lag now cancels legit thefts (regression from the R8 fixes).** VERIFIED on belt carries, which use the same `CarryStep` and main guard as thefts. The theft consequence is CODE-REVIEWED.

How the code gets there:
- `StealService.Offence` now always calls `Fail("teleport")` (StealService.luau:220-227).
- It is called on any `CarryStep` failure (:305-306) and on any main-guard debt entry (MoveGuard.luau:197-200).
- After one catch-up burst, `record()` sets `noEarnUntil = now + 10` (MoveGuard.luau:143-147), so a second stall earns no credit.

Evidence:
- **Two stalls in 10 s:** I carried a belt Goober while walking at 20 with two 1.0 s stalls 3.5 s apart (position frozen, walking velocity kept, 3-burst catch-up). This is the builder's own "real stall" pattern.
  - The first stall banked 0.98 and passed.
  - In the second, the bank stayed 0.00 and the guard flagged "move +4 studs": 0.5 s of debt plus a "No shortcuts!" toast.
  - Repeated with a 1.5 s stall then a 1.0 s stall 5 s apart: the first passed, the second flagged (2.5 s debt plus toast).
- **Velocity-0 freeze:** a single 1.0 s freeze with velocity 0 produced no main-guard debt, but `CarryStep` failed ("No shortcuts!" toast). That alone would cancel a theft.
- **Controls:** a single 1.0 s stall with velocity kept, and three 0.5 s stalls within 5 s, gave 0 debt rows and no toast.

Repro: carry, walk, stall 1 s, catch up, walk 2-5 s, stall 1 s again, catch up.

Expected: lag never cancels a theft. Actual: the theft is cancelled, the victim gets "StealFailed", and the thief keeps the 60 s thief cooldown and the 300 s pair cooldown. That hurts players on weak mobile networks.

**M2. A faked stall still turns idle time into an instant teleport, once per 10 s.** VERIFIED. R8 M2 is partly fixed.
- **Single hop:** I stood still for 1.8 s with the HRP pinned and AssemblyLinearVelocity set to 20, then made a 45.9-stud CFrame hop to G06_Nugget.
  - It was snagged **0.27 s** after the hop, with no "Whoa" (walking takes 2.29 s).
  - Control, same but velocity 0: a 34.5-stud hop was snagged only after 2.14 s, with "Whoa, slow down!" twice.
  - The design comment "waiting at the belt can't be turned into a teleport" (MoveGuard.luau:17-18) still fails against velocity spoofing. This matters when racing for a rare belt spawn, or when hopping into a victim base before the steal hold.
- **Hop chain: FIXED.** Five cycles of a 1.75 s faked stall plus a 48-stud hop covered 241 studs.
  - Debt was only fully clear 11.9 s after the chain started (walking takes 12.07 s), so about 1.01x (R8: 1.27x).
  - Hops 2-5 were flagged (+31, +2, +44 studs).
  - The rebase still drops the long-window history (n=1 after hop 1), but the 10 s cooldown blocks re-earning.

**M3. Store/public status unchanged** (owner-side, not scored against the build). `games.roblox.com/v1/games?universeIds=10769928826` still returns "[TITLE UNAVAILABLE]", `isContentRestricted: true` and maxPlayers 0. Votes 0/0; the icon is Completed.

## Minor issues
- **m1. Revoking ExtraSlots leaves the base over capacity.** With 21 Goobers, capacity dropped to 18, but all 21 stayed and kept earning (rate exactly halved by DoubleCoins only). This only matters if a pass is ever revoked or refunded; not a live path today.
- **m2. Rebirth fires on a single remote call with no server-side confirmation.** My fuzz call `Rebirth:FireServer(nil)` rebirthed the account. The client presumably confirms first (UNVERIFIED, no rendering). Server checks are correct (level, cost, not carrying, rate limit), so this is not an exploit, just one tap from a big irreversible action if the client UI ever skips its confirm.
- **m3. Slow walking earning bank: FIXED in practice.** Walking at 17 with server speed 20 gave a max bank of 0.12 (R8: 0.28). Earning now needs under 1 stud per sample.

## Retest of previous round's findings
- **R8 C1 (smooth-move theft beats the teleport cancel): FIXED.**
  - CODE-REVIEWED: Offence calls Fail unconditionally, from both the debt entry and `CarryStep`. There is no re-time path left.
  - VERIFIED detection: a smooth 60 st/s (3x) carry home was flagged by the main guard at "+1 studs" (5.6 s debt) and by `CarryStep` ("No shortcuts!" x2). In a theft that ends the theft.
  - The live 2-player theft is UNVERIFIED.
- **R8 M2 (faked-stall lag bank / hop chain): PARTLY FIXED.** Chain fixed (1.01x); the single faked-stall hop is not fixed (0.27 s snag). See M2.
- **R8 M3 (store/public): NOT FIXED** (owner-side).
- **R8 m1 (hint overflow): FIXED.** TextFits=true for all 6 texts at scale 0.62.
- **R8 m2 (velocity-0 freezes): CHANGED, worse impact.** No main-guard debt this time, but `CarryStep` fails, and a theft is now cancelled (folded into M1).
- **R8 m3 (bank while walking slowly): FIXED** (max 0.12 s).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync.
  - Core loop: legit snag, carry, place, sell (9 cycles).
  - Stall tests: two-stall-in-10 s flags (2 runs); 0.5 s x3, 1.0 s single and 1.5 s single pass; velocity-0 freeze trips `CarryStep`.
  - Smooth 3x carry flagged; faked-stall hop snag vs control; 241-stud hop chain; slow-walk bank.
  - Free-player pass revoke and restore; receipt idempotency; marketplace ids and prices.
  - Fuzz (792 fires plus 10 invokes); save, raw store read, stop, start, identical restore.
  - Hint TextFits; sounds loaded; template and MeshPart counts; perf stats; public API status; console clean.
- **CODE-REVIEWED:**
  - Full StealService and MoveGuard (Offence, Fail, succeed, the steal loop, catch order, bank/record cooldown, debt and forgiveness).
  - CarryService; ConveyorService.Snag; BaseService.Sell; ProgressService.Rebirth.
  - The harness commands I used.
- **UNVERIFIED:**
  - All two-player paths: live theft, catch, cancel on violation, lock and eject, victim UI, leave cases.
  - Real network-lag behaviour: whether real stalls keep replicated velocity, and how often stalls cluster.
  - In-game visuals and phone layout (no rendering); 8-player load; real audibility; real purchases (none made); moderation and questionnaire.

## Decision: FAIL
Deciding gate: weighted total 7.58 < 8.0.
- No category is below 7, and no unresolved critical defect was found.
- The score is held down by the new M1 (legit thefts lost to lag) and the residual M2.
- It is also held down by how much stays UNVERIFIED with no rendering and one client. Visuals, mobile and two-player play can't earn credit until they are observed.

## Top 5 fixes that would raise the score most
1. **M1:** never let lag cancel a theft.
   - Distinguish clear shortcuts from borderline flags: cancel on big excess, flying, or debt lasting over about 1 s; re-time on small flags.
   - Or allow 2-3 stall credits per 10 s, but cap their total at the stall time actually observed.
   - Retest a theft or belt carry with two 1 s stalls 3 s apart, and with a 1 s velocity-0 freeze.
2. **M2:** stop trusting client velocity for credit.
   - Earn credit only once the catch-up lands on the extrapolated walking path from the frozen spot, in the frozen velocity's direction.
   - Or credit the stall only after the catch-up, never ahead of a jump. A faked stall followed by a hop to a belt Goober should then wait for the walking time.
3. **Real tests:** run a published two-client private server, covering theft, catch, lock and eject, leave cases, the violation cancel and real poor-network lag (Studio network simulation or a phone on weak Wi-Fi). Without it, multiplayer and exploit scores can't rise further.
4. **Rendering pass:** with Studio rendering, screenshot the base, belt, Goobers and the phone UI (device emulator 16:9 and 4:3), and check the hint, toast and Skip sizes on a phone. That would earn the visual, UI and onboarding credit currently held back.
5. **Owner:** finish the maturity questionnaire and set the experience Public (M3). Also consider clamping an over-capacity base (m1) and confirming the client-side rebirth confirm (m2).

## State changes made during this audit
- Two single-player playtests started and stopped. Studio is back in **Edit** mode. No code, map, Assets or Creator Hub changes; git still clean at 88c2f58.
- Studio DataStore `SAG_Player_Studio_v1` (user 456399732):
  - 9 cheap Goobers snagged and placed for tests (Sir Puddle, Snorkel x2, Toastie, Wobblesworth, Nugget x2, Blorp x2); every one was sold. The base holds the original 21 uids (verified after restart).
  - The placements levelled the account to 26. Reset to Lv 25, xp 76; the account now shows xp 226 from AutoCollect accrual.
  - **An accidental rebirth** was triggered by my remote fuzz, which included a bare `Rebirth` fire. It set rebirths 1 and coins 50k. Restored to rebirths 0 and 18,782,593 coins through the harness; the restore was verified after restart (rebirths 0, Rebirths attribute 0). Upgrades were unchanged by it.
  - Receipt `AUDIT9-1` recorded. Its 1,007,400 coin grant was subtracted afterwards; coins are 17.94M, up from 14.77M at start, from natural AutoCollect and offline accrual.
  - All 6 passes revoked and re-granted.
  - Dex counts and snag/sold stats went up slightly.
  - Harness save done twice.
- The fuzz fired PromptPass/PromptProduct with valid keys, which may have opened Studio purchase prompts. None were confirmed, and they closed with the playtest.
- Plugin-VM helpers and loggers (`_G.LOG`, `_G.walkLine`, `_G.fakeStall`, `_G.hopSnag`, etc.) ran inside the playtests only.

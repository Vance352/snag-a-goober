# Independent Release Audits - Rounds 4 and 5

Verbatim reports from fresh separate auditor subagents following
`.claude/agents/independent-release-auditor.md` (run as general-purpose agents told to follow
that file, because agent definitions load only at session start). Both FAIL.

# Independent Release Audit - Round 4
Place verified: 90695592143707 "Snag A Goober" (Edit window 99449037; local server ae8a9ca1 + clients Player1 e3f1c7d5 / Player2 1725a2f5)   Build: f25a23f (main HEAD, clean). I compared the byte size of all 30 scripts in the Edit DataModel and the running server with `src/`, and every one matches.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 7.5 | Core loop, steals, catch, placement, Drop/Sell, receipts and saves all worked in the live session. 2 of about 8 legit approaches were wrongly refused (M2). |
| Core gameplay loop | 7 | Snag, carry, place, Cash Pad, upgrade is clear and quick. Unchanged from R3. |
| Replayability / progression | 7.5 | Levels, Dex milestones, rebirth, Gold Line and Chaos events are intact. Rebirth panel is clear. |
| Visual / Blender / audio | 7 | Mesh Goobers (octopus, Snorkel, Moai and others) on stands and belt; map, landmarks and decor render well (Edit overview screenshot). 17 game Sounds load (SFX sprite, 15 s). |
| UI/UX and mobile | 7 | Galaxy A06 (705x338) layout fits. UIScale 0.676, menu buttons 48x48, Settings 37x37, shop descriptions and status-banner text about 8 px. Desktop chat moved to bottom-left. On touch devices the chat is deliberately left at the default position (Chat.luau:15). |
| Multiplayer / networking / performance | 7 | 2322 parts, 23 belt models, heartbeat 60, 1.36 MB Lua memory. Belt movement is time-based, so it costs no network. |
| Data persistence / economy security / exploit resistance | 4 | New critical: respawn-grace teleport theft (C1). Thieves can still beat their slowed speed by about 29% (M1). Reset-and-teleport snag loop (C1 variant). Saves, bad-argument fuzzing and receipts are solid. |
| Monetization / compliance | 8 | All 10 IDs live via a direct GetProductInfo call; names and prices match Config. Lucky description and odds math check out (27/109 = 24.77%). Receipts are idempotent. Restricted-region gating is in the code. |
| Onboarding / first minute | 7.5 | Setting tutorial to 0 shows the hint pill with Skip plus the guide beam. A rare-spawn banner stacks tight under the hint. |

Weighted total: **6.95 / 10**

## Critical defects (block release)
**C1. Respawn gives 4 s of unchecked teleporting, so a full theft needs no walking at all.**
- **Cause:** `CharacterService.luau:143` calls `MoveGuard.Grace(player, 4)` on every CharacterAdded. `Grace` wipes history, anchor and debt (`MoveGuard.luau:158-164`).
  - During the grace `Plausible()` returns true (`MoveGuard.luau:140`). That covers Snag, StealHold and Steal.
  - `CarryStep` skips the jump and speed checks (`inGrace`, `MoveGuard.luau:224-239`).
  - The sampler never enters debt during grace (`MoveGuard.luau:267`).
- **Repro (pure client script on Player2, verified):**
  1. `Humanoid.Health = 0`. The character respawns after 3.37 s.
  2. Set the HRP CFrame into Player1's base next to Snorkel.
  3. After 0.2 s fire `StealHold(uid)`; 1.15 s later fire `Steal(uid)`. The carry starts.
  4. Immediately set the HRP CFrame home and hold it there.
- **Result:** `StealStart` then `StealSuccess` 3.08 s later. Snorkel moved P1 to P2 (new uid 2484de999f53419c). The victim got $87 compensation and a 120 s shield. The thief never walked a stud either way and was never catchable on a route.
- **Same hole for snags (verified):** reset, teleport 50 studs to the belt, snag, teleport home. Placed 1.8 s after the snag. Looping reset/teleport/snag skips every walk to the belt.
- **Code-reviewed sibling:** `ServerMove` adds a 0.6 s grace (`MoveGuard.luau:197`). Ejection from a locked base therefore also opens a short unchecked window.
- **Expected:** respawn trusts only the server's own spawn position; anything off it goes into debt. **Actual:** any position is trusted for about 4 s.

## Major issues
**M1. Thieves can still out-run the owner (R3 M1 partly fixed).**
- Sustained carry tolerance is `speed*1.12*dt + 3 + pingSlack` over a window of only about 1.2-1.35 s. That is roughly 1.3x the server WalkSpeed.
- Verified on a belt carry: a client-set WalkSpeed of 21 (server 16) averaged 20.67 st/s over a 140-stud path with no "No shortcuts!" and normal placement.
- For a thief (13.6 server speed) the same check function allows about 17.6-18.6 st/s, faster than a 16 st/s owner. The 20 st/s case from R3 is now caught; 17-18 st/s is not.
- Teleport-in then immediate steal is now refused (verified). Stealing after waiting out the debt took 3.5 s versus about 2.2 s walking (verified), so that part is fixed.

**M2. Legit players are sometimes refused, and one flag blocks them for seconds.**
- Two of about 8 legit approaches (Humanoid:MoveTo at 16 st/s) were refused:
  - a steal hold right after walking into P1's base was silently ignored;
  - a snag after walking from home to the belt returned "Whoa, slow down!".
- Neither reproduced in a monitored rerun. The root cause is undetermined; a fling from the other, unidentified P1 driver (WalkSpeed 31) is possible.
- Verified amplification: a single 15-stud displacement while walking (like a physics fling or lag catch-up) made every snag probe answer "Whoa" for about 6 s (probes 3-8, about one per second).
  - `debtPaid` (`MoveGuard.luau:129-130`) compares against distance from the old anchor, and that distance keeps growing at almost walking pace, so the debt barely pays down while the player walks.
- Simulated 1 s replication stall plus 16-stud catch-up during a carry: no false cancel (verified), so R3 M4 itself looks fixed.

**M3. Public/server settings still not independently checkable (R3 M6).**
- Unauthenticated games API returns placeholders ("[TITLE UNAVAILABLE]", maxPlayers 0). The experience is still private.
- Size 8, description and public status rest on the builder's authenticated read. UNVERIFIED.

## Minor issues
- **m1.** Steal prompts now show "Steal in m:ss" during cooldowns. They are still silently disabled for protected Goobers, locked bases and players under level 3, with no reason shown (`World.luau:174-191`).
- **m2.** Mobile:
  - the touch path keeps the default chat position (`Chat.luau:15`), so a phone overlap with the top-left menu is unverified;
  - Settings button is 37x37;
  - shop card descriptions (Lucky especially) and status banners are about 8 px on a 360p phone;
  - the Rebirth modal's X sits partly in the top inset (y = -1).
- **m3.** The "SECRET SPOTTED!" banner stacks directly under the tutorial hint pill and covers the player's name tag in the centre of the screen.
- **m4.** A pending "waddling home" Goober lands after `MinTravelTime`, which assumes 1.25x walk speed minus 0.5 s. That is about 1 s sooner than really walking (2 s vs 2.6 s for 42 studs). Small.
- **m5.** The thief compensation/sell loop is not profitable (stolen Goobers are recorded as paid = 50%), but friends can still farm XP (+25 per steal) with alternating thefts every 5 minutes.

## Retest of previous round's findings
- **M1** (teleport in, then out-run at 20 st/s): **PARTLY FIXED.** Teleport-in is refused, 20 st/s is caught by the builder's evidence and the code, but about 1.29x still passes (M1). **REGRESSED in spirit** via the respawn-grace path (C1).
- **M2** (teleport, wait about 3 s, snag/steal): **FIXED** outside respawn. Verified: immediate steal refused; allowed after 3.5 s versus 2.2 s walking. Bypassed by C1.
- **M3** (reset with a belt Goober places it instantly): **FIXED.** Verified "waddling home on its own (2s)", landed about 2 s later.
- **M4** (lag false positives on carries): **FIXED** for a simulated 1 s stall (verified, no cancel). A related false-positive risk outside carries remains (M2).
- **M5** (chat over the HUD menu): **FIXED on desktop** (ChatWindowConfiguration Left/Bottom, input bar at y = 530). **UNVERIFIED on mobile.**
- **M6** (server size/description/public): **UNVERIFIED.**
- **m1:** PARTLY FIXED (cooldown countdown shown).
- **m2** (grace overwrite): FIXED; ServerMove now shifts history (code-reviewed). The 0.6 s grace remains (see C1).
- **m3** (Personal Drop flipping): FIXED. Code-reviewed: `paid` is stored and the refund is 50% of what was paid.
- **m4** (harness VIP revoke): FIXED (code-reviewed).
- **m5** (no message after carry-check reset): FIXED (code-reviewed toast, `CarryService.luau:154-157`). Not triggered in my runs.
- **m6** (cross-client VIP tag): CODE-REVIEWED, using the replicated `VIP` attribute. End-to-end UNVERIFIED.
- **R2 C1** (teleport-home theft outside grace): still blocked (code path unchanged). REGRESSED through the C1 variant.

## Verified / Code-reviewed / Unverified
**VERIFIED (observed this session):**
- Place ID; build matches git.
- Respawn-grace theft and snag exploits.
- Debt model: immediate teleport steal refused; allowed after about 3.5 s.
- Belt carry at 20.67 st/s not flagged.
- Reset with a belt Goober waddles home in 2 s.
- 1 s stall tolerated.
- 15-stud hop gives about 6 s of "Whoa" while walking.
- Wall-hop jumping carry placed normally.
- Legit snag after walking.
- Bad-argument fuzz on all 12 client-to-server remotes plus 200x Snag and 50x GetQuote spam: no server errors. GetQuote is rate-limited (returns nil).
- Save, then a raw DataStore GetAsync matches memory (coins, level, 13 Goobers, lock present).
- Receipts idempotent: same PurchaseId granted once; Boost +15 min.
- Marketplace IDs and prices live.
- Audio assets load.
- Phone layout screenshots (Galaxy A06); tutorial hint and beam.
- Server perf stats.

**CODE-REVIEWED:**
- DataService: session lock, retries, BindToClose, sanitize.
- MonetizationService: receipt order, prompted-pass verification, PolicyService gating.
- Sell/Drop refunds, steal fairness rules, rebirth rules, CarryStep hover check.

**UNVERIFIED:**
- Full stop/rejoin persistence cycle (not done, to avoid ending the session).
- Real-network lag behaviour.
- Mobile chat placement.
- Public listing / max players.
- Actual audibility.
- Cross-client VIP chat tag.
- A fresh-account first minute (only a tutorial reset on an existing account).
- 8-player load.

**Environment note:** another actor was driving Player1 (and possibly the harness) while I tested. During my session P1 bought Speed 10 / Slots 12 / Income 8 / Lock 5 and spent about 195k coins, locked its base and caught my Player2 thief. P2's coins also jumped from about 105k to about 1.55M. I did none of this. It may explain the M2 refusals and it complicated cooldown-bound tests.

**State changes I made (all inside the running playtest):**
- Snorkel stolen P1 to P2 via the exploit (P1 +$87, 120 s shield, P2 cooldowns).
- P2 snagged and placed Nugget (teleport test), Toastie twice (one by reset waddle), Moai Goob and Nugget again; P2 then walked a second Nugget home.
- P2 was caught once stealing Fluffernaut (it returned to P1).
- My fuzz sold P2's own Bubbles McGee for $2.5K.
- P2: 2 simulated receipts (+$211,800 Slop Sack, 15-min 2x boost).
- Harness `tp` of P1 once; P2 tutorial set to 0 and restored to 99; clearNotes.
- Device simulator used on the Player1 client and stopped (back to default).
- No playtest started or stopped; Edit window untouched; no code or assets changed.

## Decision: FAIL
Gates that decided it:
- unresolved critical exploit/ownership defect (C1);
- weighted 6.95 < 8.0;
- Data/economy/exploit category 4 < 7.

## Top 5 fixes that would raise the score most
1. **Close C1.** On respawn, anchor the trust at the server's spawn CFrame instead of a free 4 s grace:
   - set the anchor and history to the ServerMove target and drop the `Grace` call (or make it 0 s);
   - treat any position off that anchor as debt;
   - give ServerMove's 0.6 s window the same anchor-based check.
   - Retest: reset, then teleport-steal or teleport-snag.
2. **Tighten sustained carry speed (M1).** Use a longer window (2-3 s) and a smaller constant slack so a thief can't exceed about 1.1x their slowed speed. Consider also checking the stolen carry against the owner's speed.
3. **Make debt pay down while walking (M2).** Compute the required time from the debt-entry position to the current position with a capped penalty, or cap debt at about 2 s. Log the cause of each flag to find the intermittent legit refusals.
4. **Mobile chat and text.** Position the chat away from the menu on touch too; raise Settings to 44 px or more and the description and banner text to at least 10-11 px on phones.
5. **Explain disabled steal prompts.** Show "Protected 0:32" / "Base locked" / "Lv 3 needed" instead of hiding the prompt. Space the rare-spawn banner away from the tutorial hint.


---

## Builder fixes after round 4 (commit 4fcfd28)
See CHANGELOG 2026-10-09 and QA/test-log.md.

---

# Independent Release Audit - Round 5
Place verified: 90695592143707 / "Snag A Goober" (Studio 99449037, Edit mode at start and end)   Build: 4fcfd28 (main HEAD, working tree clean). All 30 Studio scripts match `src/` byte for byte (Adler-32 of every Source compared with every .luau file).

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 7.5 | The core loop works end to end with zero console errors across 2 playtests and 212 malformed remote calls. Save, stop, restart restored everything. Lag-hitch false positive on carries (M2). |
| Simplicity/enjoyment of core loop | 7.5 | Snag, carry, place, income, upgrade all feel quick (legit carry of ~150 studs took 8 s with no warning). The belt gets label clutter during Slop Storm. |
| Replayability/progression | 7.5 | Unchanged systems (levels, Dex rewards, rebirth, chaos events, Gold line at Lv10). Chaos "Slop Storm" observed working. |
| Visual/Blender/animation/audio | 7.5 | 25 Goober models in Assets are used on stands and the belt (Slime King, Moai, Toastie and others seen in screenshots). 27 Sounds, all loaded. |
| UI/UX and mobile | 7 | Settings is now 44.6 px and text is at least 12 px on Galaxy A06. Rebirth X sits below the inset. Chat is bottom-left. The "UPGRADES" label overflows on phones, the lock pill wraps, and the modal X is 41x34 (m1). |
| Multiplayer/networking/performance | 7 | Server at 60 FPS, 2,371 parts with 1 player, belt is time-based (quiet network). Two-player paths UNVERIFIED this round. CarryStep is much less tolerant of lag (M2). |
| Data persistence/economy/exploit resistance | 6 | Round-4 C1/M1 fixed, but a two-hop teleport gets past the debt model (M1). In-debt movement is free and debt is capped at 10 s. Laundering a Personal Drop through a friend's theft (m3). |
| Monetization/compliance | 8 | verifyMarketplace: all 6 passes and 4 products live, prices match. ProcessReceipt is idempotent (code). Lucky odds are disclosed and PolicyService gating is in place (code). |
| Onboarding/first minute | 7.5 | Tutorial replayed (harness reset): Grab, Home, Collect, Upgrade, then the "YOU'RE A GOOBER BOSS!" card. The beam/arrow guides, Skip is there, and the guaranteed $5 Blorp drop comes every 12 s. |

Weighted total: **7.28 / 10** (7.5×.20 + 7.5×.15 + 7.5×.15 + 7.5×.10 + 7×.10 + 7×.10 + 6×.10 + 8×.05 + 7.5×.05)

## Critical defects (block release)
None confirmed. M1 is borderline: it reopens the round-4 C1 exploit class (teleporting on the approach), though it now costs a few seconds.

## Major issues
**M1. Two-hop teleport gets past MoveGuard debt; teleport-then-wait is faster than walking.**
- Evidence: `MoveGuard.luau` charges debt only for the first implausible jump. While in debt, the sample loop skips checks (`elseif not inDebt(g)`) and `Plausible` returns early, so further moves during debt are never charged. `addDebt` also caps debt at 10 s.
- Repro (single client, server position log via a polling task, WalkSpeed 20):
  1. Stand at spawn (-84,-58).
  2. Client CFrame +26 studs, wait 0.6 s.
  3. Client CFrame to the belt at x≈36 and follow a Goober.
  4. Spam Snag.
- Server log: jump 1 at 3.13 s, jump 2 at 3.76-3.88 s, `Carrying=G13_Fluffernaut` at 6.93 s. That is 3.8 s after jump 1, for a snag point 148 studs away in a straight line (7.4 s walking; the Goober was moving away, so a legit intercept takes about 10 s).
- A single 135-stud hop took 6.3 s. Walking to the same place is ≥6.7 s, more to intercept.
- Expected: never faster than walking (the commit's claim). Actual: about 2x faster.
- `StealHold` and `Steal` use the same `Plausible`, so a thief can reach any victim base in about 3-4 s. Not live-tested with 2 players; code path is identical. The carry home is still validated.

**M2. Legit network hitches cancel thefts / delay carries (regression from the stricter CarryStep).**
- Evidence: CarryStep now checks every sub-window of 1 s or more at +5% plus `1.5 + speed*ping` (ping clamped to 0.05-0.15).
- Simulated hitch: the client holds its position, then catches up to where a 1.0x walker would be.
  - 0.3 s freeze: no flag.
  - 0.5 s freeze: "No shortcuts!" and placement at 11.4 s instead of 8.1 s.
  - 0.5 s + 1.0 s freezes: placement at 13.45 s.
- For steals, the same check fires `StealService.Fail(thief,"teleport")`, cancelling the theft. A one-tick catch-up over about 16.5 studs also fails the single-tick limit.
- Real lag behaviour is UNVERIFIED (Studio had about 0 ms ping). The freeze-then-catch-up pattern is what a hitch looks like to the server.
- Expected: tolerate short hitches. Actual: a half-second hitch is enough to lose a theft.

**M3. Store/public settings still not verifiable or not ready.**
- The public games API for universe 10769928826 now returns "[TITLE UNAVAILABLE]" and `isContentRestricted: true` (private or unrated).
- The thumbnails API returns only 2 thumbnails, with identical image hashes (likely placeholder or pending), not 5. The icon state is "Completed".
- The maturity questionnaire is still unchecked in `QA/RELEASE_CHECKLIST.md`.

## Minor issues
- **m1. Mobile layout.**
  - On Galaxy A06 (705x338) the "UPGRADES" menu label doesn't fit (`TextFits=false`, needs 24 px in a 15 px box). It wraps as "UPGRAD ES" there and as "UPGRADE S" on iPhone 16 Pro.
  - The lock pill text wraps onto two lines at about 12 px.
  - The modal close X is 41x34 (under 44).
  - The Rebirth button is below the fold in a scrolling body.
  - On-belt name/price labels overlap heavily, especially during Slop Storm.
- **m2. Steal/cooldown countdown rounding** (World.luau `stealPromptState`, floor minutes vs `math.ceil(sec) % 60`): it shows "1:00" when about 1:59.5 is left (a 1-second flicker at each minute boundary). Cosmetic.
- **m3. Personal Drop laundering.** A stolen Goober is re-placed with `{stolen=true}` and no `paid`, so `Sell` refunds 50% of the full price (BaseService.luau:209). Friends can buy a 50%-off Personal Drop, steal it, and sell it at par, plus 25% insurance once per 10 min. That bypasses the round-3 "refund on paid price" fix. CODE-REVIEWED.
- **m4. Ordering in StealService.Start:** CarryStep runs before the catch check. A collision shove at the moment of a catch reports "teleport" (60 s cooldown) instead of "caught" (90 s, stun, stat). CODE-REVIEWED.
- **m5. Free-roam speed tolerance:** a sustained speed hack of about 1.2x outside carries passes `windowOk` (1.12×speed×dt + 3 + lag), which shortens approaches. CODE-REVIEWED.

## Retest of previous round's findings
- **C1 respawn grace teleport: FIXED.** Reset, then teleport to the belt on respawn and spam Snag: refused ("Whoa, slow down!") until 2.74 s, against 2.29 s to walk the 45.8 studs. Note that M1 reopens the same exploit class by another route.
- **M1 thief out-running: FIXED** (belt carry verified; steals use the same CarryStep, CODE-REVIEWED).
  - 1.00x and 1.05x CFrame carries: not flagged.
  - 1.08x (21.6 st/s at WalkSpeed 20): flagged twice and placed at 15.7 s against a 9.7 s walk.
  - So a slowed thief (0.85x) tops out around 0.9x of the owner's speed.
- **M2 legit refusals / bump lockout: FIXED for normal play.**
  - Keyboard walking, jumps, strafing into walls, a 2.5 s idle, then E-snag and walking home with jumps: no refusals, at WalkSpeed 20 and at WalkSpeed 16 (Sprint Boots revoked).
  - A 12-stud physics bump: 0 refusals. A 38-stud fling: 1 refusal, then success.
  - 8-12 stud bumps mid-carry: no warning.
  - New lag regression filed as M2.
- **M3 public settings: NOT FIXED / UNVERIFIED** (see M3).
- **m1 steal prompt reasons: FIXED** (CODE-REVIEWED in World.luau; the prompt stays visible with Lv / New player / Base locked / Protected / Steal-in reasons). Needs 2 players to see live.
- **m2 mobile: mostly FIXED.** Settings 44.6 px, text at least 12 px, Rebirth X below the inset (y≈22-56 in the viewport, inset 58 is excluded), chat Left/Bottom on all devices. Remaining items in m1 above.
- **m3 banner under hint: FIXED** (screenshot: the "EPIC Grandpa Goob" banner sits directly below the hint pill with no overlap).
- **m4 waddle-home faster: FIXED.** Snag at (-40,-18), then immediate reset: toast "(3s)", landed at 2.98 s, against about 1.5-2 s to carry to the plot edge.
- **m5 friend steal XP: PARTIALLY FIXED** (CODE-REVIEWED: XP once per victim per 30 min). The laundering is m3.
- **Two-player paths** (live theft, catch, victim/thief leaving): UNVERIFIED this round. They were verified live in earlier rounds (QA/test-log.md).
  - Round-4 changes touching them: Settling gate on completion, XP throttle, stricter CarryStep.
  - The stricter CarryStep can wrongly cancel legit thefts (M2) and changes caught-vs-teleport attribution (m4).
  - The logic for thief or victim leaving is unchanged.

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; script sync.
  - Respawn exploit blocked.
  - Two-hop and single-hop teleport timings (M1).
  - Carry speed thresholds.
  - Hover carry flagged at 0.95 s and not faster than the legit route.
  - Waddle-home timing; reset after a long carry places immediately.
  - Bumps; keyboard legit play at 16 and 20 speed.
  - Bad args and spam on all 12 client remotes plus GetQuote: no errors, no corruption.
  - Tutorial flow; Chaos event.
  - Shop, Upgrades and Rebirth panels.
  - Device sim on Galaxy A06 and iPhone 16 Pro.
  - Marketplace ids and prices.
  - Save, stop, start persistence (coins, level, tutorial, 17 Goobers, 20 Dex entries, upgrades).
  - Sounds loaded; perf stats.
- **CODE-REVIEWED:** MoveGuard rewrite; CarryService/StealService diffs; steal prompt reasons; ProcessReceipt idempotency and receipt pruning; ejection ServerMove; Sell refund path; TestHarness gated to Studio.
- **UNVERIFIED:**
  - Live two-player theft, catch and leave paths.
  - Real-network lag behaviour.
  - 8-player load.
  - Physical phone.
  - Store page moderation and maturity questionnaire.
  - Real purchases (none made).

## Decision: FAIL
- Weighted 7.28 < 8.0.
- Data/economy/exploit category is 6 (< 7).
- The approach-teleport exploit class (M1) is still open.

## Top 5 fixes that would raise the score most
1. Charge debt for all movement while in debt. For example, keep the trust anchor frozen and require the current position to be reachable from the last trusted anchor in (now − anchor.t). Remove the 10 s cap or make it equal to the walking time.
2. Make CarryStep hitch-tolerant without reopening speed: compare against the anchor path with a ping/jitter budget (a few tenths of a second of catch-up allowed once per window). Also, for steals, re-time the walk on a first offence instead of cancelling.
3. Check the catch before CarryStep in StealService.Start. Record `paid` (or 0) on stolen Goobers so Sell can't launder Personal Drops.
4. Mobile polish: shorter or auto-sized menu labels ("UPGRADES"), 44 px close buttons, single-line pills, and decluttered belt labels during events.
5. Complete the store page: maturity questionnaire, confirm all 5 thumbnails are approved and listed, and set public visibility once approved. Then run a published two-player test of theft and catch under real latency.

## State changes made during this audit
- Two single-player playtests started and stopped. Studio is back in **Edit** mode. Device simulator used and stopped (default viewport). No code, map, Assets or Creator Hub changes.
- Studio-only DataStore `SAG_Player_Studio_v1` for user 456399732 (written by autosave and BindToClose):
  - Goobers went from 7 to 22 (snags; base now full).
  - Level 7 to 11.
  - Coins about 970K to about 1.9M. Includes `setCoins` 50 for the tutorial test, then restored to 1,903,259, plus income, level rewards and 2 Drop sell-backs.
  - Dex counts increased.
  - Tutorial: `set tutorial 0`, replayed, now 99.
  - The bad-arg spam bought Speed/Income/Lock upgrades and the tutorial bought Zoomies; all reset to 0 via harness.
  - Sprint Boots revoked and re-granted in session only.


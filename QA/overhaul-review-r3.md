# Goober Breach overhaul - independent review, round 3 (final)

Date: 2026-10-10. Build: `06ea9e5` ("review round 2 fixes"). Studio sources match `src/` for all 45 scripts. I compared length plus a position-weighted byte checksum, with CR stripped, and every script matched exactly.
Place checked: `game.PlaceId == 90695592143707` before every Edit-mode `execute_luau`. The map in Studio is the rebuilt one: the plaza sign is at y 21 and its posts are 21 studs tall.

## How I tested
- **Two-player Studio session**: Test > Server and Clients, then Add Clients, driven by UI Automation. Player1 (-1) and Player2 (-2) were set to Lv 10 with the tutorial done and $5M. Player3 (-3) joined later for the phone checks. All actions went through harness `call`, which runs the real handlers.
  - Carrier "walking" and teleports were done with `Character:PivotTo` from the plugin, which does not move the carry's start point.
  - Leaves were simulated the way a real leave happens: `player.Character = nil`, then the real `Carry.OnRemoving`.
  - One real disconnect: `Player:Kick()` on a carrier.
- **Phone layout**: Player3's client window was resized until the viewport was exactly **750x381**. The inset measured **58 px**. I took screenshots and measured the GUI.
- **Code review** of the full diff of `06ea9e5`: BreachService, CarryService, CombatService, DataService, Config, MapBuilder, LeaderboardUI and UI. I also re-read the whole economy path for the developer's design decision: Snag, DropFromCarry, settleDropped, OnRemoving, Release, PlaceHome, LandPending, Base sell, StealService.succeed, and BindToClose.
- **The real account (cooolvance55) was not used.** Its base stays 22/22.

Side effects, all on Studio test accounts that are not saved: coins and levels were set, and test Goobers were spawned, bought, dropped, released and placed. SLOP STORM was forced for 40 s. Player2 was kicked. The session was ended with Test > End Session, and Studio is back in Edit mode.

**Overall: 7.0 / 10.** Both round-2 blockers are really fixed, and I verified both myself:
- The refund loop is closed. The leaver ends $1.125M down after two cycles, and the partner gains $0.
- A real Kick now drops the carried Goober into the field.

SLOP STORM, the doorway landings for blasted Goobers, the saved steal credit, the 60-degree facing check and the raised plaza sign are also verified. No critical problem is open. Two **major** problems remain:
- **The leave refund is still a 50% discount for a pair of accounts.** The refund is paid while the Goober stays in the world for a friend to grab. Reproduced: the pair spent $750K for a $1.5M Glitch.
- **A teleport exploit skips the whole chase.** A carrier who teleports straight into their own base is not moved back. They are safe there from the Blaster, and the Goober is delivered once the walk time has passed. Reproduced: 194 studs, delivered 6.1 s later.

Both fixes are small.

---

## Scores

| # | Category | R1 | R2 | R3 |
|---|---|---|---|---|
| 1 | Goober Breach acquisition | 7.0 | 7.5 | **8.0** |
| 2 | Blaster combat (responsiveness, fairness) | 5.5 | 7.0 | **7.0** |
| 3 | Map quality and visual polish | 5.5 | 6.5 | **7.0** |
| 4 | Leaderboards (accuracy, presentation) | 6.0 | 7.0 | **7.5** |
| 5 | Game passes and shop | 6.5 | 7.0 | **7.5** |
| 6 | UI/UX and mobile | 6.5 | 7.0 | **7.0** |
| 7 | Security, persistence, multiplayer | 6.0 | 4.0 | **6.5** |
| 8 | Performance and release readiness | 6.5 | 5.5 | **6.5** |
| | **Overall** | 6.0 | 5.5 | **7.0** |

The plain mean of the categories is 7.1. I rounded down because both open majors sit in the core loop.

The pending imports (the Breach frame and ring, the Blaster and the Mart stall from SAG_Hub.fbx) and the SAG_SFX3 upload cost about 1 point in category 1, 1.5 in category 3, 1.5 in category 8 and 0.5 in each of categories 2 and 5. When they land as exported, I'd expect about +0.5 overall.

### 1. Breach acquisition - 8.0
Verified:
- **SLOP STORM** now runs Cooldown 1.45 / Charging 3.65 / Unstable 1.40 / Blast 1.55, about 8.0 s against 15.5 s normally (1.93x). The "twice as often" copy is now true, and the Unstable warning is 1.4 s, not 1.0.
- **Blasted drops avoid doorways.** In two trials a carrier 7 studs from the south plot edge (z -33, edge at -40) was shot along +X. Both Goobers landed at (-25.3, -22.3), on the arena side.
- **Island cauldrons.** All four stayed in Cooldown for 8 s with 0 island Goobers. With Player1 at the Pumpkin Patch: Charging at 0.4 s, Unstable at 8.5 s, Blast at 11.5 s, 4 Goobers.

Deductions:
- -1.0: stand-ins for the Breach frame and ring, and SAG_SFX3 is not uploaded (pending).
- -0.5: landing and hop plans are still published in `PathPts` at spawn, so a modified client can pre-position (inherent, low).
- -0.5: **death and leave drops** don't use the doorway check. Only blasts pass `alt`. Player2 died at z 27 and the Glitch landed at **z 36**, about 4 studs from the north plot row (edge about z 40). A north-row owner can grab it on their doorstep and be home before the 6-stud grace runs out.

### 2. Blaster combat - 7.0
Verified:
- **Facing check.** The shooter was 8 studs from a carrier and aimed straight at them. Facing 90° away: no hit, still nothing after 0.35 s. Facing 70° away: no hit. Facing 45° away: HitConfirm.
- **Fair race, still intact.** The Spork landed 11 studs to the side. Player1 grabbed it after the 1 s lockout (`takenFrom = -2`, carry price 1,500).
- **Lag compensation** is capped at 0.25 s (code).

Deductions:
- -0.5: the Blaster is a 4-part stand-in (pending).
- -0.75: **teleporting home skips the chase** (Major 2, see category 7). The Blaster's whole counterplay is the walk home, and an exploiter doesn't have to make it.
- -0.5: **the delayed re-check (new) opens two holes.**
  - (a) It skips the "hands full" rule. Reproduced: Player1 fired while facing 90° away, snagged Sir Puddle inside the 0.2 s window, then turned. 0.4 s later Player2 got HitConfirm and lost their Blorp, while Player1 was carrying.
  - (b) It resolves against positions 0.2 s *after* the shot, not where the shooter saw the target. The honest client turns `root.CFrame` and fires in the same frame (`Blaster.luau` lines 153-162). The remote can arrive before that rotation replicates, so on live servers many honest shots may take the delayed path. A sprinting carrier then has 3.5-4 studs of extra escape. **Untested**: Studio replicates instantly.
- -0.25: facing is still read from the client-owned HRP. A modified client simply turns first, so the check mostly constrains honest clients.
- -0.25: the ping-pong between the old and new carrier still exists (both sides have equal lockouts, so this is mild).
- -0.5: **rage-quit refund.** A blasted carrier who leaves inside the 1 s lockout still gets 50% back, and staying gives nothing (see Major 1).
- -0.25: lag compensation is untested (Studio ping is about 0).

### 3. Map - 7.0
Verified: in the Edit shot from the plaza entrance at eye height, the arch sign now sits above the boards and all five coloured board headers are visible. The arch posts frame the two outer boards, which is acceptable.

Deductions:
- -1.5: stand-ins for the Breach, the Blaster and the Mart stall (pending).
- -1.0: the 420x300 ground is still mostly flat empty grass ringed by hills (unchanged).
- -0.5: the boards are still mostly empty space (one data row on a 22-stud board).

### 4. Leaderboards - 7.5
Verified:
- Panel data is real: Vance $117M (EARNERS) and 5 (RARE), with "You: $0 • not in the top 10 yet".
- Cash Pad collect gave +516,448 to both `coins` and `totalEarned`.
- **The steal credit is saved.** A combat steal gave `combatSteals` 2 → 3 and `data.stealCredit = {"-2": now+300}`. It sits in the saved profile, and `sanitize` drops expired entries.

Deductions:
- -0.5: the phone tabs no longer wrap, but **every tab label now renders at 8 px**. The label is 76x18 px, the text is 45-60 px wide, and `TextSize = 8` (MinText 11 × UIScale 0.76). Before this round it was about 10.6 px. The RARE tab is also cut at the right edge of the tab strip (screenshot).
- -0.5: the TOP EARNERS history still includes refunds and packs credited before the round-1 fix.
- -0.5: the leave discount (Major 1) lets a friend collect Secrets at half price, which inflates RARE COLLECTORS. Reproduced: "Discovered Glitch 14/25".
- -0.5: there is no rank outside the top 10.
- -0.5: not tested: OrderedDataStore under live throttling.

### 5. Game passes and shop - 7.5
The coin products are no longer worthless, because the infinite-coin loop is gone.

Deductions:
- -0.5: the golden Blaster is a recolour of the stand-in.
- -0.5: there is no preview of the Glam effects.
- -0.5: the shop is a long scroll on phones.
- -0.5: not tested: a real purchase and receipt.
- -0.5: the leave discount halves the real price of bought Goobers for anyone with a friend or alt. It's bounded, but it undercuts Lucky Goober and Slop Coin value.

### 6. UI/UX and mobile - 7.0
Measured at 750x381 (inset 58):
- The nav grid is now 53x52 cells starting at GUI y 100.6. Its bottom row (LEVELS / UPGRADE / REBIRTH / TOP) ends at GUI y 184.4, which is **screen y 242.4**. The thumbstick zone starts at y 241, so about 1 px overlaps: fixed.
- The "COLLECTE/D" wrap is gone.

Deductions:
- -0.5: tab text at 8 px, and the RARE tab is cut off (see category 4).
- -0.5: the BLAST button is unchanged: 73 px with a 19 px gap to jump. It is touch-only, so I didn't see it.
- -0.5: not tested: real touch input and auto-aim on a device.
- -0.5: on a phone the overhead name and level tag still sits over the plot's "CASH PAD" text (screenshot).
- -0.5: the top banner and the right-hand column cover about half the phone screen. At the plaza entrance the board headers sit behind the HUD; you have to walk in to read them.
- -0.5: there is still no feedback for some ignored snags (an expired uid).

### 7. Security, persistence, multiplayer - 6.5
**Fixed and verified.**
- **Round-2 Critical 1 (refund loop)**, end to end:
  1. Player1 had $5,000,000. Snagging a Glitch took it to $3,500,000.
  2. Player1 died and left: **+$750,000**, so $4,250,000. The field entry now has `paid 0`, `paidBy nil`, `dropBy nil`.
  3. Player2 grabbed it (carry price **$0**, coins unchanged) and reset. The Glitch dropped again (dropBy -2, paid 0).
  4. Player1 respawned and grabbed it: **paid $750,000 back** ($3,500,000; carry price 750,000, paidBy -1).
  5. Player1 died and left again: **+$375,000** = $3,875,000.
  6. Player2 grabbed and released it: **"+$0"**.

  Player1 ends $1,125,000 down and Player2 $0 up. The refund can't be repeated.
- **Round-2 Major 1 (real disconnect banks the Goober)**: Player2 snagged a Fluffernaut ($2,200), "walked" 7 studs and was **kicked**. The log showed `CharRemoving@249.711 ; PlayerRemoving@249.711 char=nil`. Afterwards the field held one Fluffernaut model at (-34.8, 15.9) with `paid 0` and `dropBy nil`, which means the refund was paid. It was not placed at home.
- Pair steal credit is saved (category 4). The console is clean on the server and both clients (3 info lines on the server).

**The developer's design decision** (a knocked-loose Goober keeps the original buyer's `paid`, so the thief can sell or release it for 50%). I accept the reasoning *for the thief*. I tried these sequences in code and at runtime:
- thief sell or release;
- the victim leaving before or after the grab;
- the thief dying or leaving;
- the original buyer re-grabbing after someone else dropped it;
- shutdown;
- base theft of a stolen record (thief record `paid × 0.5` plus 25% compensation);
- full-base fallbacks.

None of them creates net coins or duplicates a uid. The total paid out per Goober is never more than 50% of its last payment. The `loose` → `carry` → `loose`/stand moves are removed-before-added, and `Session.Used` counts carries, pending and dropped Goobers, so the 100% "no free stand" refunds (`PlaceHome`, `LandPending`, `settleDropped`) are not reachable in practice.

What does not hold is the claim that "no coins are created" *by the leave refund*. A Release pays 50% and destroys the Goober. The leave refund pays 50% and **leaves the Goober in the world for someone else to grab for free**. That is value created, P/2 per Goober, once per Goober (Major 1 below).

Deductions:
- **-1.5, Major 1: leave-refund discount.** Reproduced: Player1 paid $1.5M for a Glitch, died and left (+$750K). Player2 grabbed it free and took it home: stand record `{id = G24_Glitch, paid = 0}`, "Discovered" (14/25), income rate 6,402/s. The pair paid $750K for a $1.5M Secret.

  Repeat that for every purchase and a friend pair halves all Goober prices. One player with an alt can bring the Goober back by stealing it from the alt's base: `StealService` ignores `owed`, so they pay no debt. That costs one rejoin per Goober.
- **-1.0, Major 2: teleporting into your own base skips the chase.** Reproduced: Player1 snagged a Cone Head at (104, 2, 1) and was moved by `PivotTo` 194 studs into their own base. Player1 was **not moved back**. The only reaction was the toast "No shortcuts! Walk your Goober home." 6.08 s later (the walk time at speed 31) the Cone Head was placed and `delivered` went 33 → 34. In the meantime the carrier stands inside the base, where `CanHit` refuses every shot ("Safe inside their own base!").

  MoveGuard only restarts the walk clock. That was fine for the old belts, but it now defeats the Blaster. Leaving inside the base after a teleport banks the Goober at once (`Settle("left")` → `atHome` → `PlaceHome`). This is pre-existing code, but it matters much more now.
- -0.25: the delayed shot ignores the "hands full" rule (category 2, reproduced).
- -0.25: client-owned facing and the lag window (unchanged in principle).
- -0.25: death and leave drops can land at a plot doorway (category 1).
- -0.25: not tested: a real shutdown. The code moves carried and dropped Goobers home; the second `PlayerRemoving` pass after `BindToClose` finds nothing left to move.

### 8. Performance and release readiness - 6.5
The server console is clean. Script sources are exactly in sync with git. The cauldrons idle and the far-away loose Goobers are culled (from round 2, code unchanged).

Deductions:
- -1.5: stand-ins and SAG_SFX3 (pending). `ReplicatedStorage.Assets.Props` still has no Blaster, Breach or Mart models.
- -1.0: two open majors in the core loop (above). Both are small code changes, but they should go in before players see the update.
- -0.5: there is still no valid frame-rate measurement (several Studio instances on one PC). Real latency is untested, which matters more now that honest shots may take the 0.2 s delayed path.
- -0.5: process. The developer's retest log tested the refund loop but not the case where the refunded Goober simply stays with the partner. It also tested no exploit-style teleport while carrying.

---

## Round-2 problems: status

| # | Round-2 problem | Status | Evidence (this round) |
|---|---|---|---|
| C1 | Endless coins through the repeatable leave refund | **Fixed** | Two leave cycles: P1 5.0M → 3.875M; partner's free grab worth $0; P1 re-grab paid the $750K debt; release "+$0" |
| M2 | A real disconnect banks the carried Goober | **Fixed** | Real Kick: one Fluffernaut model in the field, `paid 0` (refunded), `dropBy nil`; not placed at home |
| M3 | Release/Sell pay the original buyer's price to a free holder | **Not changed (design decision)**, accepted | No net coins in any sequence I found (see category 7). The payout to the thief stays at 50% of the victim's payment |
| 4 | Pair steal credit per server | **Fixed** | `data.stealCredit {"-2": now+300}` after a combat steal; saved; expired entries dropped on load |
| 5 | Facing check about 101° | **Fixed** (honest clients) | 90°/70° no hit, 45° hit. New: the delayed path skips "hands full" (reproduced) |
| 6 | Lag switch earns 0.4 s | Partly | Capped at 0.25 s; still trusts `GetNetworkPing`; untested |
| 7 | Blasted drop lands about 6 studs from a door | **Fixed for blasts**; partly overall | Two trials landed at z -22.3 (arena side); a death drop landed at z 36, about 4 studs from a door |
| 8 | "COLLECTE/D" wrap | Fixed, **minor regression** | No wrap, but all tab text is now 8 px and RARE is cut off |
| 9 | Arch hides board headers | **Fixed** | Edit shot from the entrance: sign above, all five headers visible |
| 10 | SLOP STORM 2.5x | **Fixed** | 8.0 s cycle (1.93x); Unstable 1.4 s |
| 11 | Rage-quit refund after a hit | **Not fixed** | Still 50% on leave (now once per Goober); see Major 1 |
| 12 | TOP EARNERS history | Not fixed (old data) | Vance still $117M |
| 13 | Harness leave test isn't a real leave | **Fixed** (process) | Developer and I both used a real `Kick` |

---

## Ranked list of remaining problems

### Critical
None.

### Major
1. **The leave refund is paid while the Goober stays in the world** (a 50% discount for a pair; with an alt, the Goober comes back by stealing it from the alt's base, which ignores `owed`). Evidence above: the pair paid $750K for a $1.5M Glitch, Discovered, 6,402/s.

   *Fix (pick one):*
   - No refund on leave at all. Leaving already means you lose the Goober, which is the strict "no escape" rule.
   - Refund and make the Goober dive back into the Breach (vanish) instead of leaving it in the field.

   Either one-line change also removes the rage-quit incentive (r2 #11). If you keep the refund, at least skip it when the drop came from a blast.
2. **Teleporting into your own base skips the chase**, and the Blaster can't touch you there. Evidence: 194-stud `PivotTo`, no correction, delivered after 6.08 s.

   *Fix:*
   - When `MoveGuard.CarryStep` flags a shortcut on a belt carry, `ServerMove` the carrier back to the last trusted spot, or drop the Goober there (`DropFromCarry` with that origin).
   - In `CombatService.CanHit`, don't grant "safe inside their own base" while the carry's walk clock hasn't been satisfied (an unverified arrival).
   - Treat `Settle("left")` at home the same way when the walk time isn't met.

### Minor
3. **The delayed Blaster re-check skips the "hands full" rule** and resolves against positions 0.2 s after the shot (reproduced). *Fix:* in `_resolve`, refuse if `ast.carry`. Better: check facing against the server-seen HRP facings over the last ~0.3 s (keep them in `history`) and resolve straight away against positions at fire time. That also removes the hidden 0.2 s delay for honest shots on real servers.
4. **Death and leave drops can land at a plot doorway** (z 36, about 4 studs from a door). *Fix:* run the `nearBase` check for every drop and try the opposite direction or a shorter distance.
5. **Phone leaderboard tabs at 8 px, and RARE cut off.** *Fix:* use 5 equal-width tabs (`Scale` widths), and either drop the icons on `UI.small` or shorten COLLECTED to "HOME", with MinText 13.
6. Facing is read from the client-owned HRP, and lag compensation trusts `GetNetworkPing`. Both are low risk with the 60° / 0.25 s limits. Test with Incoming Replication Lag.
7. The ping-pong re-blast after a new carrier walks 6 studs (mild; equal lockouts).
8. The TOP EARNERS history includes pre-fix refunds and packs.
9. On phones the HUD covers about half the screen, and the plaza headers are hidden until you walk in. The name tag also sits over "CASH PAD".
10. Latent: `LandPending` and `PlaceHome` refund **100%** of `carry.price`, even to a non-payer, if `Base.Place` fails. It isn't reachable today because the slot accounting is right. Make it `paidBy`-aware and 50%, so a future slot change can't open it.
11. `owed` is never pruned (one entry per refunded uid per server). That's a tiny leak. Clear it when the uid leaves the field for good.

Known pending items (not counted as defects): importing SAG_Hub.fbx (Breach frame and ring, Goober Blaster, Mart stall) and uploading SAG_SFX3.wav.

---

## Brief checklist

| Check | Result |
|---|---|
| Breach acquisition | PASS. Glitch, Spork, Fluffernaut, Cone Head, Wobblesworth and Sir Puddle snags charge the price; the Central cycle runs, and SLOP STORM is 8.0 s |
| Delivery | PASS (PlaceHome / walk time). **Exploit**: a teleport into the base is delivered after the walk time (Major 2) |
| Hit + drop | PASS. 45° hit; 11-stud side drop; doorway case lands on the arena side |
| Counterplay | PASS for honest players (1 s equal lockouts, unchanged); FAIL against a teleporter |
| Race | PASS (unchanged code; Player1 won the Spork after the lockout) |
| Disconnect / reset | PASS. A real Kick drops the Goober in the field (refunded, one model); the refund is once only; the debt is paid on re-grab. **Leave discount** open (Major 1) |
| Safe zones | PASS. The own-base rule works, but it is exactly what shelters the teleporter |
| Leaderboards real data | PASS. Real ODS rows (Vance $117M, 5 rare); saved steal credit |
| Pass ownership | Not re-run (no pass code changed this round; round-2 Glam and Sprint Boots checks still apply) |
| Mobile combat layout | PASS with notes. Nav ends at screen y 242.4 (about 1 px into the thumbstick zone); tabs at 8 px; BLAST button untested on touch |
| Map walk-through | Plaza entrance (Edit shot): headers visible under the raised sign; client shot at the entrance shows the HUD covering them |
| Halloween regression | PASS. Cauldrons idle (8 s of Cooldown, 0 Goobers); Pumpkin erupts with a player there (4 Goobers) |
| Original-game regression | PASS. Cash Pad +516,448 (coins and totalEarned) |
| Console | PASS. Server: 3 info lines; Player1 and Player3 clients: empty |

## Not tested
- Real network latency: the lag-compensation path, and how often honest shots take the 0.2 s delayed path.
- Real touch input and the BLAST button on a device. More than three players.
- A real server shutdown (`BindToClose`); checked in code only.
- A real rejoin by the same UserId, and the complete alt base-steal leg of Major 1. The steal path was read in code: `succeed` uses the stand record's `paid` (0) and ignores `owed`.
- Live DataStore and OrderedDataStore throttling. Real purchases.
- Frame rate.
- The pending Blender imports and the SFX upload.

## Verdict
**Not ready to publish yet, but close.** No critical problem is left, and both round-2 blockers are verified fixed. Before Save → Publish:
1. **Must:** close the leave-refund discount (Major 1). No refund on leave, or the Goober vanishes when it's refunded.
2. **Should:** stop a teleport-home from sheltering a carrier (Major 2). Otherwise the first exploiters on a public server skip the whole Breach-and-Blaster chase.
3. Then do the pending imports and the SFX upload. Then a quick retest: a real Kick, a teleport while carrying, and one blast race.

The minors (the delayed-shot "hands full" hole, death drops at doorways, the 8 px phone tabs) can follow in a patch.

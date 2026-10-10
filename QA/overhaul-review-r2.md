# Goober Breach overhaul - independent review, round 2

Date: 2026-10-10. Build: `f8ad868` ("review round 1 fixes"). Studio sources match `src/` for all 45 scripts (lengths compared with CRLF stripped).
Place checked: `game.PlaceId == 90695592143707` before every Edit-mode `execute_luau`.

## How I tested
- **Two-player Studio session**: Test > Server and Clients, then Add Clients twice, driven by UI Automation. Player1 (-1) and Player2 (-2) were set to Lv 10 with the tutorial done and $5-50M. Most actions went through harness `call`, which runs the real handlers. Carrier "walking" was done with `Character:PivotTo` from the plugin, so it didn't move the carry's start point. One delivery was walked home on the client with `Humanoid:MoveTo`.
- **A real disconnect**: Player2 was kicked by the server (`Player:Kick`) while carrying a Goober in mid-field, with listeners on `CharacterRemoving` and `PlayerRemoving`. Afterwards a third client joined as Player3 (-3).
- **Phone layout**: Player3's client window was resized until the viewport was exactly **750x381**. The inset again measured **58 px**. Then I took screenshots and measured the GUI.
- **Screenshots**: Edit-mode shots of Champions Plaza, the east market and an aerial view. Server-side read of the board texts.
- **Code review** of the full diff of `f8ad868`: BreachService, CarryService, CombatService, CharacterService, Session, LeaderboardService, DataService, Config, Breach, World, Blaster, UI, LeaderboardUI and MapBuilder.
- **The real account (cooolvance55) was not used.** I ran no solo play this round. Its base stays 22/22.

Side effects, all on test accounts in Studio: coins and levels were set, and some Blorps and Pebble Petes were removed with `Base.RemoveRecord`. Glitch, Spork and Fluffernaut test Goobers were spawned, dropped and released. Glam and Sprint Boots were granted to Player2 for that session only. The session was ended with Test > End Session, and Studio is back in Edit mode.

**Overall: 5.5 / 10.** Most round-1 findings really are fixed, and I verified most of those fixes myself. The drop race is now fair, the Blaster is server-built and visible to everyone, Sprint Boots rest after firing, cauldrons idle when nobody is near, and the east side and the plaza look better. The score falls because of two problems in the new leave code:
- The leave refund can be repeated: two accounts can create coins without limit (**critical**, reproduced).
- A real disconnect still banks the carried Goober safely, so round-1 Major 1 is not fixed outside the harness (reproduced with a real Kick).

Without those two problems I would put the build at about 6.8.

---

## Scores

| # | Category | R1 | R2 |
|---|---|---|---|
| 1 | Goober Breach acquisition | 7.0 | **7.5** |
| 2 | Blaster combat (responsiveness, fairness) | 5.5 | **7.0** |
| 3 | Map quality and visual polish | 5.5 | **6.5** |
| 4 | Leaderboards (accuracy, presentation) | 6.0 | **7.0** |
| 5 | Game passes and shop | 6.5 | **7.0** |
| 6 | UI/UX and mobile | 6.5 | **7.0** |
| 7 | Security, persistence, multiplayer | 6.0 | **4.0** |
| 8 | Performance and release readiness | 6.5 | **5.5** |
| | **Overall** | 6.0 | **5.5** |

The overall score is capped by the open critical exploit. The plain mean of the categories is 6.4.

### 1. Breach acquisition - 7.5
What's fixed:
- The Central field is now z ±26, which leaves 13 studs to the plot doors.
- The snag grace now also ends after carrying 6 studs. Verified: a blast 0.12 s after the snag hit once the carrier had moved 7 studs, and a standing carrier was refused.
- The island cauldrons rest when nobody is near. All four stayed in Cooldown for 16 s with 0 island Goobers. With Player1 in the Pumpkin Patch the cauldron ran Charging → Unstable → Blast and gave 4 Goobers, and a Boo Blob snag worked.
- "Too slow - Player2 grabbed it!" now shows when you lose a race.

Deductions:
- -1.0: the Breach frame and ring are still stand-ins, and SAG_SFX3 is not uploaded. This is the known pending import, but it is what players see today.
- -0.5: hop and landing plans are still published in `PathPts` as soon as a Goober spawns, so a modified client can pre-position (inherent, low).
- -0.5: SLOP STORM now applies `intervalMult 0.33` to every stage except Blast. I measured a 6.3 s cycle (Cooldown 1.0 / Charging 2.7 / Unstable 1.0 / Blast 1.5) against 15.5 s normally. That is 2.5x, not the "twice as often" in the copy, and the Unstable warning shrinks to 1 s.
- -0.5: the knocked-loose Goober now flies 11 studs "to the side of the shot". When a carrier is shot along X, which is common in the long oval, that side is ±Z, toward the plot rows. In one test it landed at z = 32.5, about 6.5 studs from a plot door: outside the field the developer had just pulled back from the doors.

### 2. Blaster combat - 7.0
Verified:
- **Fair race.** Hit at 8 studs: the drop landed 10.8 studs from the (pushed) victim and 15.1 studs from the shooter. At t = 0.61 s, both were refused: "You're still dizzy" and "Your Blaster is still recoiling". At t = 1.03 s the first to snag got it, and the other was told "Too slow". Victim stagger (0.75 s) plus walking 2.8 studs is still under the 1.0 s lockout, so both reach the 8-stud range in time. The race is now decided by reaction time and ping, which is fine.
- **Server Blaster.** Player2's client sees Player1's GooBlaster and its own. After granting Glam, the gun had `Gold = true` and Foil within about 1 s, and the other client saw it gold.
- **Sprint Boots rest.** WalkSpeed went 21.5 → 17.5 right after firing → 21.5 after 3.2 s.
- **Base-thief splat.** A real `Steal.Request` by Player3, then Player1 blasted the thief outside the base: StealFailed, and Disco Dan went back on Player1's stand.

Deductions:
- -0.5: the facing check only rejects aim more than about 101° off (`dot < -0.2`). A shooter facing north hit a target due east (90° off). Also, the client owns its own HRP rotation, so a modified client can just turn before it fires. The check mostly constrains honest clients.
- -0.5: lag compensation accepts the target's current position **or** its position up to 0.4 s back (`GetNetworkPing`, clamped). This is reasonable, but a lag switch inflates ping and gets the full 0.4 s window (about 6-12 studs of trailing hitbox on a sprinting carrier). **Untested**: Studio ping is about 0, so the code path is effectively off in every test so far.
- -0.5: the ping-pong still exists. The new carrier's grace ends after 6 studs, and the old carrier, off cooldown, can blast straight back. It is less extreme now that both sides have equal lockouts.
- -0.5: the Blaster itself is a 4-part stand-in (pending import). The golden version is just that stand-in recoloured with Foil.
- -0.5: a victim gets nothing back when their paid Goober is snatched. But leaving after being hit gives 50% back (see category 7), which is a perverse incentive to rage-quit after a hit.

### 3. Map - 6.5
What's fixed (screenshots): the Rebirth Shrine is off to the north-east side of the plaza. The five boards are bigger (16x22 studs, rows about 34 px at 30 px/stud) and sit on an arc with nothing in front. The arch sign is no longer clipped ("Leaderboards • Rebirth Shrine"). A new paved east market (a disc around the Chaos Rift, a Mart pad, a portal pad and three paths, with lamps and planters) joins the arena to the Rift, the Goober Mart and the Spooky Portal.

Deductions:
- -1.5: stand-ins for the Breach, the Blaster and the Mart stall (pending import).
- -1.0: the 420x300 ground is still mostly flat empty grass, ringed by blob hills and mushrooms (aerial shot).
- -0.5: from the plaza entrance at eye height, the arch crossbeam covers the board headers. "MASTER THIEVES" shows only as a sliver under the sign. You have to walk through the arch to read which board is which.
- -0.5: the boards are still mostly empty space: one row of data on a 22-stud board (that's the data, but it looks sparse).

### 4. Leaderboards - 7.0
Verified on the server: all five boards show real ODS data: Vance $117M, 101 collected, Lv 30, 5 rare, and "No rankings yet" on MASTER THIEVES. In the panel at 750x381: tabs EARNERS / COLLECTED / THIEVES / LEVEL / RARE, a stat line with the full title, and "You: $0 • not in the top 10 yet". Cash Pad collect added +258,957 to both coins and `totalEarned`. In code, Sell, Release, theft compensation, the "no stand" refunds and coin packs now pass `notEarned`. The combat-steal pair credit is in `CarryService` (300 s per thief:victim key).

Deductions:
- -0.5: on a phone the **COLLECTED** tab wraps mid-word into "COLLECTE / D" (screenshot). MinText 14 in a 138-px button at UIScale 0.76 doesn't fit.
- -0.5: `stealCreditAt` is in server memory only. Two friends who hop to a new server together reset it, so MASTER THIEVES farming drops from about 1 per 8 s to about 1 per server hop, not 1 per 5 min.
- -0.5: existing TOP EARNERS values (Vance's $117M) still include refunds and packs credited before the fix. The fix only applies from now on.
- -0.5: the coin exploit below lets a friend be handed Secret Goobers for free, which inflates RARE COLLECTORS (discoveries).
- -0.5: there is no rank outside the top 10 ("not in the top 10 yet"). That's acceptable, but it gives a mid-table player no sense of progress.

### 5. Game passes and shop - 7.0
What's fixed: the Glam golden Blaster is server-built and visible to all clients (verified on the other client), and it re-colours within about 1 s of the grant. The Sprint Boots description now states the fair-play rule, and that rule matches the behaviour I measured.

Deductions:
- -0.5: the golden Blaster is a recolour of a 4-part placeholder until the Blender import.
- -0.5: there is still no preview of the Glam effects. On phones it is the last card in a long scroll (unchanged).
- -0.5: not tested: a real purchase prompt and receipt in a live server.
- -1.0: while the coin exploit (Critical 1) is open, Slop Coin products lose their value: anyone with an alt can make coins for free.

### 6. UI/UX and mobile - 7.0
Measured at 750x381 (inset 58, so the GUI area is 750x323):
- The nav grid is now 55 px cells starting at y 132. Its bottom row (LEVELS / UPGRADE / REBIRTH / TOP) ends at GUI y 189, which is screen y 247. Round 1 measured the thumbstick zone at y 241-361 for x 20-140, so only about 6 px of the LEVELS and UPGRADE corners overlap, against about 35 px before. Effectively fixed.
- The Lv < 3 toast is throttled to once per 15 s (code). Dropped Goobers now show "Dizzy..." or "Recoiling..." in their prompt, and the prompt range matches the server's 8 studs.

Deductions:
- -0.5: the COLLECTED tab wrap (see category 4).
- -0.5: the BLAST button is unchanged: 73 px with a 19 px gap to the jump button. It only appears on touch, so I didn't see it in this Studio session.
- -0.5: not tested: real touch input and auto-aim on a device.
- -0.5: there is still no feedback for a snag that was ignored for other reasons, for example an expired uid with no recent claim. Minor.
- -0.5: on a phone the overhead name and level tag sits right over the plot's "CASH PAD" text at the spawn view. This is cosmetic.

### 7. Security, persistence, multiplayer - 4.0
Passed (verified):
- Lockouts and the fair race.
- Snag grace by distance.
- Base-steal splat goes home.
- Island cauldron area gate.
- Real delivery by walking: `delivered` 30 → 31.
- Console clean on the server and both clients.

Passed in code (I did not re-run these):
- The full-base drop reservation (`Session.Used` counts `DroppedCount`; refund fallback in `settleDropped`).
- Leaderboard writes moved off the save path (`task.spawn`).

Deductions:
- **-3.0, Critical 1: infinite coin loop through the leave refund.** Reproduced end to end, see below.
- **-1.5, Major 1: a real leave still banks the carried Goober at home** (stats are no longer credited, but the Goober is safe). Reproduced with a real Kick, see below.
- -0.5: Release and Sell pay 50% of the *original buyer's* price to whoever holds the Goober. Player2 grabbed Player1's dropped Glitch for $0 and released it for **+$750K**. `paidBy` was added in this round but isn't used here.
- -0.5: the facing slack and the lag-switch window (category 2). Pair credit is in server memory only (category 4).

### 8. Performance and release readiness - 5.5
What's fixed: the cauldrons idle. Loose Goobers more than 260 studs from the camera aren't animated, so there are 13 loose models in view on the client against about 50 before. The server console is clean (3 info lines). Board, panel and Blaster all work.

Deductions:
- -2.0: Critical 1 (minting coins) and Major 1 (leave banking) must be fixed before players see this. Both live in code that was added to fix round 1.
- -1.5: stand-ins plus SAG_SFX3 not uploaded (pending). `ReplicatedStorage.Assets.Props` has no P_GooBlaster, P_BreachFrame, P_BreachRing or P_MartStall.
- -0.5: the developer's leave retest called `Carry.OnRemoving` on a connected player whose character still existed. That isn't how a real leave happens (see Major 1), so the "PASS" in the test log was wrong. Real leaves (Kick) should be part of the standard test.
- -0.5: there is no valid frame-rate measurement this round. The client showed 15 fps with four Studio instances on one PC, which says nothing about the game. Real latency (lag compensation) is also still untested.

---

## The two new defects in detail

### Critical 1 - the leave refund can be repeated: endless coins with two accounts
`BreachService.OnRemoving` refunds 50% of `e.paid` to the leaver for every dropped Goober with `e.paidBy == leaver`. But `paidBy` is carried unchanged through every later free grab and drop (`Snag`: `paidBy = e.paidBy` for dropped Goobers; `DropFromCarry`: `paidBy = carry.paidBy`). It is only reset when the `refundedTo` player re-grabs that same entry. A drop by someone else creates a new entry without `refundedTo`, so the original buyer can grab it for free and be refunded again on the next leave.

Reproduced on the Studio server with the real handlers. The leave was simulated the way it really happens: `player.Character = nil`, then `Carry.OnRemoving`.
1. Player1 snags a Glitch for **$1,500,000**.
2. Player1 dies, and the Glitch drops (dropBy -1, paidBy -1).
3. Player1 leaves: **+$750,000**. The Glitch stays in the field (refundedTo -1).
4. Player3 grabs it for **$0**, then resets. It drops again (dropBy -3, **paidBy still -1**, no refundedTo).
5. Player1 "rejoins" and grabs it for **$0**, dies and leaves again: **+$750,000**.
6. Steps 4-5 repeat: **+$750,000** each cycle.

Player1's coins: $5,000,000 → paid → $4,250,000 → $5,000,000 → **$5,750,000**, and so on, while the Glitch is still in the field. A first run that used the carrying-leave path (character present) gave the same numbers. At the end Player2 also grabbed the Glitch for free and released it for another +$750K.

Cost per cycle: one rejoin, about 20-40 s. Payout per cycle: half the price of the most expensive Goober you can snag ($750K for a Glitch, $1.25M for a Chaos Goob). The partner can also just keep the Goober for free.

Fix:
- Record the payment once per Goober uid: refund at most once per uid. A simple way is to store `e.refunded = true` on the entry and in `carry`, and carry it through every snag and drop.
- Or set `paidBy = nil` whenever someone other than the payer takes the Goober.
- Use the same `paidBy` and refunded rule for Release (`CarryService.Drop`) and for the sell value (`paid`) of a Goober you grabbed for free.

### Major 1 - a real disconnect still banks the carried Goober
Test: Player2 carried Captain Spork ($1,500, paid) at (104.8, 2.3, -8.8), and the server kicked them. The listeners logged `CharacterRemoving@447.265 ; PlayerRemoving@447.265 char=nil`. So by the time DataService's `PlayerRemoving` runs the removing hooks, `player.Character` is already nil. After the leave there was **no field entry and no Spork model**.

The code shows why. `CarryService.Settle(player, "left")` only drops when `hrp` exists (`reason == "left" and not atHome and hrp`). Otherwise it calls `PlaceHome(player, false)`, which puts the Goober on a stand.

Confirmed on a connected player by setting `Character = nil` before `Carry.OnRemoving`: the Fluffernaut count at home went **1 → 2**, `delivered` +0, no refund, nothing in the field. Leaving is therefore still a safe way out of a chase. It is just no longer credited as a delivery or a combat steal. The developer's retest passed because the harness call ran with the character still present.

Fix: drop on `player.CharacterRemoving` while the character still exists (`DropFromCarry` before the model goes). Or give `DropFromCarry` an origin and use `carry.lastPos` when there is no character. Re-test with a real `Kick`.

---

## Round-1 problems: status

| # | Round-1 problem | Status | Evidence |
|---|---|---|---|
| 1 | Leaving banks a carried Goober | **Not fixed** (stats no longer credited) | Real Kick: `Character` is nil at PlayerRemoving; Spork not in the field; Fluffernaut 1→2 at home (Major 1) |
| 2 | Combat-steal farming with a friend | Partly fixed | 300 s pair credit (developer: second steal not counted). In server memory only: a server hop resets it |
| 3 | Drop destroyed when the base is full | Fixed (code + developer test) | `Session.Used` counts own drops; refund and toast fallback in `settleDropped`. I didn't re-run it |
| 4 | Attacker wins the drop race | **Fixed** | Victim 10.8 / shooter 15.1 studs; both locked at 0.61 s; first snag at 1.03 s wins; "Too slow" to the other |
| 5 | Sprint Boots outrun carriers | **Fixed** | 21.5 → 17.5 after firing → 21.5 after 3.2 s; description updated |
| 6 | Blaster client-only; Glam gold invisible | **Fixed** | Server-built GooBlaster seen by the other client; Gold/Foil within about 1 s of the grant |
| 7 | Leaderboard writes before the final save | Fixed (code) | `task.spawn(writePlayer)`; `st.data` is captured before the save |
| 8 | TOP EARNERS counts refunds and packs | Fixed (code) | `notEarned` on Sell, Release, compensation, refunds and packs; Collect counted. Old totals not cleaned |
| 9 | Aim not checked against facing | Partly | 90° off-facing shot still hits; only about 101°+ is rejected |
| 10 | No lag comp; client range 16 vs 14 | Implemented, untested | 0.4 s history; client range now 14. Studio ping is about 0 |
| 11 | Shrine blocks a board; tiny text; clipped sign | Fixed | Screenshot; board rows about 34 px; sign unclipped. New: the arch beam hides headers from the entrance |
| 12 | East side bare | Fixed | Paved market square and paths (screenshot); the wider map is still mostly empty grass |
| 13 | Phone tabs 7-10 px; nav over the thumbstick | Mostly fixed | Tabs readable, but "COLLECTE/D" wraps; nav bottom at screen y 247 (about 6 px overlap, was about 35) |
| 14 | Lv < 3 toast on every click | Fixed (code) | 15 s throttle |
| 15 | Doorway landings unblastable | Fixed | Field ±26; grace ends after 6 studs (hit 0.12 s after a snag once the carrier had moved 7 studs) |
| 16 | Cauldrons run unattended; no culling | **Fixed** | 16 s of Cooldown on all four with 0 island Goobers; Pumpkin runs with a player there; 260-stud cull |
| 17 | SLOP STORM copy | Partly | Copy now "twice as often"; measured 2.5x (6.3 s vs 15.5 s) |
| 18 | Island drops skip the area gate; drops into bases | Fixed (code) | The area gate applies to dropped Goobers; `inAnyPlot` landing check |
| 19 | No feedback on a lost race | **Fixed** | "Too slow - Player2 grabbed it!" |
| 20 | "Collected" inconsistent | Fixed | Leaving no longer credits `delivered` |

---

## Ranked list of remaining and new problems

### Critical
1. **Endless coins through the repeatable leave refund** (new in this round). See above. *Fix:* refund at most once per uid, and stop passing `paidBy` through free grabs.

### Major
2. **A real disconnect still banks the carried Goober** (round-1 #1 not fixed in practice; new code path). *Fix:* drop on `CharacterRemoving`, or use `carry.lastPos` when there is no character. Re-test with a real Kick.
3. **Release and Sell pay out half the original buyer's price to a holder who paid nothing.** Player2: free grab, then Release, gave +$750K. Not money from nothing on its own, but it pays out on any Goober you knock loose, and it was a link in the critical loop. *Fix:* refund what *this* player paid, using `paidBy`.

### Minor
4. Pair steal credit is per server. A server hop resets it. *Fix:* save `pairCredit` (the save already has a `pairCooldowns` table for base theft) or key the limit on a saved timestamp.
5. The facing check allows about 101° either side, and the client controls its own facing. *Fix:* tighten to `dot > 0.3` and also compare with recent server-seen facings.
6. Lag compensation trusts `GetNetworkPing`, so a lag switch earns the full 0.4 s. *Fix:* cap at about 0.25 s, require the past position to be in line of sight (it is) **and** the current position to be within range plus a few studs. Test with Studio's network simulation (Incoming Replication Lag).
7. The drop can fly toward the plot rows and land about 6 studs from a door. *Fix:* clamp drop landings to the field's z range, or pick whichever side points toward the field's centre line.
8. The phone "COLLECTE/D" tab wrap. *Fix:* `TextWrapped = false` with a smaller MinText, or use the label "HOME".
9. From the plaza entrance the arch crossbeam hides the board headers. *Fix:* raise the sign about 4 studs, or put the board titles at the bottom.
10. SLOP STORM is 2.5x, not 2x, and the Unstable warning drops to 1 s. *Fix:* use `intervalMult 0.45` on Charging and Cooldown only.
11. Leaving after being blasted gives a 50% refund, but staying gives nothing. That is an incentive to rage-quit. Fixing Critical 1 by refunding once per uid partly addresses it. Consider no refund when the Goober was knocked loose by a hit.
12. The TOP EARNERS history still includes refunds and packs credited before the fix.
13. Process: the harness leave test (`call("Carry.OnRemoving")` with a live character) doesn't reproduce a real leave. Use `Player:Kick()` in the standard test.

Known pending items (not re-reported as defects): the Breach frame and ring, the Blaster and the Mart import, and the SAG_SFX3 upload. These cost about 1-1.5 points each in categories 1, 3 and 8, and about 0.5 in categories 2 and 5.

---

## Brief checklist

| Check | Result |
|---|---|
| Breach acquisition | PASS. Central cycle logged (normal, and 6.3 s in SLOP STORM); Glitch, Spork and Wobblesworth snags charge the price |
| Delivery | PASS. Wobblesworth walked home on the client (`MoveTo`); `delivered` 30 → 31 |
| Hit + drop | PASS. Grace refusal while standing still; hit after a 7-stud carry; 4-stud push; sideways drop of 11 studs |
| Counterplay | PASS. Both locked for 1.0 s; the victim is closer (10.8 vs 15.1); first to snag after the lockout wins |
| Race | PASS. "Too slow" to the loser. The same-frame double snag wasn't re-run (passed in round 1, code unchanged) |
| Disconnect / reset | **FAIL**. A real Kick banks the carried Goober (Major 1); the leave refund repeats (Critical 1). Death drop PASS |
| Safe zones | PASS. Own-base protection, base-thief splat goes home, island area gate; drops never land inside a base (code) |
| Leaderboards real data | PASS. Five boards with real ODS data, panel global tab, "You:" line. THIEVES empty (correct) |
| Pass ownership | PASS (session grant). Glam gold Blaster seen by others; Sprint Boots rest measured |
| Mobile combat layout | PASS with notes. Nav ends 6 px into the thumbstick zone (was 35); COLLECTED wraps; no touch test |
| Map walk-through | Screenshots: plaza (unblocked, sign fixed, headers hidden from the entrance), east market (paved), aerial |
| Halloween regression | PASS. Cauldrons idle without players and erupt with one there; Boo Blob snag in the Pumpkin Patch |
| Original-game regression | PASS. Cash Pad collect +258,957; base steal (`Steal.Request`) then the owner's splat returns Disco Dan |
| Console | PASS. Server: 3 info lines; clients: clean (one plugin camera notice from my own probe) |

## Not tested
- Real network latency, so the lag-compensation path. Real touch input on a device. More than three players.
- A live-server DataStore or OrderedDataStore under throttling. A real Glam purchase and receipt.
- A full real rejoin by the same UserId. Studio gives a new test id. The refund loop was driven with `Character = nil` plus the real `Carry.OnRemoving` and `BreachService.OnRemoving`, which is exactly the state a real leave produces; `refundedTo` is keyed by UserId, so it carries across a real rejoin.
- The full-base reservation and pair-credit timers were not re-run (the developer logged them; I checked the code).
- Frame rate: no valid measurement with four Studio instances open.
- The pending Blender imports and the SFX upload.

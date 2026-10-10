# Goober Breach overhaul - independent review, round 1

Date: 2026-10-10. Build: `36cdbaa` (Studio sources match `src/` by length, CRLF-adjusted, for all 45 scripts).
Place checked: `game.PlaceId == 90695592143707` before every `execute_luau`.

How I tested:
- A real two-player Studio session (Test > Server and Clients > Add Clients x2, driven by Windows UI Automation). Player1 (-1) and Player2 (-2) were set to Lv 10 with the tutorial done. Most actions went through the harness `call`, which runs the real remote handlers. The steal used a real keyboard hold of E on the client prompt. The cauldron Goober was walked home on the client with `Humanoid:MoveTo`.
- One Player2 client window was resized until its viewport was exactly **750x381**, to check the phone layout. Note that Studio reports a **58 px** GUI inset there, not 36 px, so the usable UI area is 750x323.
- Edit-mode and client screenshots of the arena, Champions Plaza, Goober Mart and the panels.
- A short solo Play as cooolvance55 (Lv 30). I only looked: the Rebirth panel and the console. The base was 22/22 before and after, nothing was bought, and Rebirth was not pressed.
- A code read of BreachService, CombatService, CarryService, LeaderboardService, Blaster, World, UI, DataService and MonetizationService.

Side effects, all on test accounts only: Player1's Studio save had Goobers sold and Blorps placed and then sold, and both test players had coins and level set. Glam was granted to Player1 for that session only. The session was ended through Test > End Session. Studio is back in Edit mode.

**Overall: 6.0 / 10.** The core loop works and the server is careful in most places. I found no critical defect, no duplication and no cross-wall hits. The problems are combat fairness and escape hatches (leaving the game, friend farming, a paid speed advantage), one silent item loss, and a hub that still looks unfinished.

---

## Scores

| # | Category | Score |
|---|---|---|
| 1 | Goober Breach acquisition (originality, quality) | **7.0** |
| 2 | Blaster combat (responsiveness, fairness) | **5.5** |
| 3 | Map quality and visual polish | **5.5** |
| 4 | Leaderboards (accuracy, presentation) | **6.0** |
| 5 | Game passes and shop | **6.5** |
| 6 | UI/UX and mobile | **6.5** |
| 7 | Security, persistence, multiplayer | **6.0** |
| 8 | Performance and release readiness | **6.5** |
| | **Overall** | **6.0** |

### 1. Breach acquisition - 7.0
What works: the cycle runs exactly as stated. I logged it at Cooldown 3 s, Charging 8 s, Unstable 3 s and Blast 1.5 s, which is a 15.5 s cycle, and the four cauldrons are staggered. The type (SLOP SURGE / GOLD RUSH / RARE RIFT) shows in the meter while charging. The path is a pure function of time, and the same function animates on the client and validates on the server. This is a good design: snags off a flying Goober are refused with "Wait for it to land!", and the out-of-range check uses where the Goober is now or where it was 0.4 s ago. The field held 16 Central and about 35 cauldron Goobers. Personal Drops land at the nearest edge of the field to your base. It is a real step up from conveyors.

Deductions:
- -1.0: the field (z ±32) ends 7 studs from the plot doors (z ±39). A Goober that lands at your door is home inside the 1.5 s snag grace, so it can never be blasted. Corner plots (1/4/5/8) carry about 50% further on average than centre plots: the mean |dx| is about 86 vs 56 studs. Combat exposure therefore depends on which plot you were assigned.
- -1.0: the stand-in Breach (a dark cage of pillars) and the missing SFX make the blast read weaker than the concept deserves. This is the known pending import, but the score has to reflect what players see today.
- -0.5: Hop plans and landing spots are in model attributes (`PathPts`) the moment a Goober spawns. A modified client can walk to the next hop spot ahead of time. This is low severity and inherent to the design, but worth knowing.
- -0.5: The SLOP STORM copy says "3x faster", but `intervalMult` only shortens Charging, so the cycle goes from 15.5 s to about 10.1 s (1.5x).

### 2. Blaster combat - 5.5
What works, all tested: the 1.5 s snag grace is refused ("They only just grabbed it!"). A real hit gives HitConfirm and GotBlasted, sets WalkSpeed to 0 for the stagger, pushes the target **exactly 4.00 studs** and drops the Goober. The dropper is "dizzy" for 1.2 s. Ten blasts fired in a burst produced 1 hit (cooldown). Shots through a plot wall were blocked, even with the shooter raised 3.5 studs (jump height). Blasting a base thief sent the stolen Goober home ("SPLAT! ... ran home"). Malformed or NaN aim is handled.

Deductions:
- -1.5 **the attacker nearly always wins the "race"**. The drop lands about 0.55 s after the hit, 7 studs past the victim, who has just been pushed 4 studs. The victim is locked out for 1.2 s. The attacker is at most 14 + 7 studs from the drop, and the snag range is 14 studs. So the attacker is in range when the Goober lands, or within 7 studs of range, and can grab it well before the victim's lockout ends. "Anyone can grab" is nominal in a 1v1. The only counterplay is to blast back after the attacker's grace, and that becomes a ping-pong.
- -1.0 **Sprint Boots is now a combat pay-to-win**. Carriers can never use Sprint Boots (`ApplySpeed`) and walk at 0.85-1.0 of their speed by rarity. Chasers keep the +4. A paying chaser always closes on any carrier.
- -1.0 the **Blaster is client-only**. On Player1's client, Player2 had no GooBlaster, and the server shows none on anyone. Nobody can see who is armed, so there is no threat telegraph, only the shot fx.
- -0.5 aim is not checked against the server-side facing. Player2, facing **+X**, hit Player1 behind them because the remote's aim vector pointed at Player1. A modified client can auto-aim 360°. The cone check only constrains honest clients.
- -0.5 there is no lag compensation (server-time target positions). The client auto-target uses range+2 (16) against the server's 14, so edge shots at fleeing targets will miss silently. **Untested under real latency** (Studio has none).

### 3. Map - 5.5
What works: a clear layout. The Breach sits in the centre of a paved oval between the two plot rows, Champions Plaza is to the west (arch, 5 boards, Rebirth Shrine) and the Mart and Chaos Rift are to the east. There are lamps, benches and a rune circle, and the map is closed by a ring of hills.

Deductions:
- -1.5 stand-ins: the Breach cage, the hip-welded box that serves as the Blaster, and a plain stall for the Mart. Pending imports, but they are what ships today.
- -1.0 the **Rebirth Shrine ring stands directly in front of the middle board (MASTER THIEVES)**. From the plaza entrance, half of that board is hidden behind the ring (screenshot from the client). The arch subtitle is clipped on both sides ("lobal leaderboards • Rebirth Shrin").
- -1.0 the **east side is unfinished**: the Goober Mart and Chaos Rift sit on bare grass, with no paving and no path from the oval. Most of the 420x300 ground is empty green, and the "hills/trees" are blob ellipsoids and mushrooms.
- -1.0 board text is tiny. The rows are readable only from a few studs away, and each board is mostly empty space (one entry on a 15x21-stud board).

### 4. Leaderboards - 6.0
What works: real OrderedDataStores with a separate Studio prefix. Test players (UserId ≤ 0) and temporary sessions never rank. UpdateAsync keeps the higher value, and a failed read keeps the last good data. The boards showed real data: Vance $115M, Lv 30, 101 collected, 5 rare. MASTER THIEVES correctly showed "Nobody on this board yet". The panel's GLOBAL and THIS SERVER tabs both work at phone size (live tab: Player1 $53.1M, Player2 $37.5M).

Deductions:
- -1.5 **MASTER THIEVES is farmable with a friend**. Combat steals have no pair cooldown, while base theft has 300 s. I ran a full cycle: P1 snags a $10 Blorp, P2 hits P1, P2 grabs, P1 hits P2, P1 grabs, and P1's `combatSteals` went 1 → 2. That costs $10 per point, and only the 8 s same-target and 4 s immunity timers limit the rate.
- -1.0 **TOP EARNERS is not "earned"**. `Session.AddCoins` adds to `totalEarned` for every source: sell refunds, Release refunds, theft compensation, quest rewards and **Robux coin packs**. A buy-and-sell loop or a purchase raises your rank.
- -0.5 "Collected" (`delivered`) leaves out Goobers that waddled home after a drop, but includes Goobers banked by leaving the game (see #1 below).
- -0.5 there is no "your rank" (only "You: score"). On a 750x381 phone the category tabs render at about 7-10 px ("MASTER THIEVES" TextBounds 10, "RARE COLLECTORS" 9 and cut off).
- -0.5 the boards are blocked or tiny (see Map).

### 5. Game passes and shop - 6.5
What works: `verifyMarketplace` shows all 7 passes and 4 products live, with price matching Config (Glam 2026448294, 149 R$, on sale). Granting Glam added GlamTrail, GlamGlitter and the Glam attribute on the server. The Mart prompt exists and opens the Shop. Sprint Boots is off while carrying a Breach Goober.

Deductions:
- -1.5 **Goober Glam's "golden Goober Blaster" can only be seen by the buyer** (the gun is client-only). Even the buyer doesn't see it until the gun is rebuilt: right after the grant, Player1's gun was still purple SmoothPlastic. One third of a paid cosmetic is invisible to everyone else.
- -1.0 Sprint Boots has quietly become a combat advantage (see category 2), but its description still reads as a convenience pass.
- -0.5 there is no preview of the Glam effects, and on phones the Shop shows two cards at a time with Glam last in a 1,030 px scroll.
- -0.5 not tested: a real purchase prompt and receipt for Glam in a live server.

### 6. UI/UX and mobile - 6.5
Measured at 750x381 (Studio inset 58, so the GUI is 750x323, UIScale 0.762):
- The BLAST button is **73x73 px**, at screen x 563-636 and y 290-363. It leaves a **19 px gap** to Roblox's small-screen jump button (655-725). That is tight but it doesn't overlap, and the button is clear of the right column, which ends around y 252. It is hidden while carrying, so it never competes with DROP.
- The HUD, meter, tabs and Leaderboard and Shop panels all fit, with nothing clipped except the leaderboard category strip.

Deductions:
- -1.0 the nav's bottom row (LEVELS/UPGRADE/REBIRTH/TOP) reaches screen y ≈ 276. With the 58 px inset it overlaps the thumbstick zone (x 20-140, y 241-361) by about 35 px. This predates the overhaul, but the 58 px inset makes it worse than the earlier 36 px assumption.
- -1.0 leaderboard tabs are 7-10 px on phones (see category 4).
- -0.5 a Lv 1-2 player gets a toast **on every world click** ("The Goober Blaster unlocks at Level 3!"), with no throttle (`Blaster.Fire`).
- -0.5 losing a grab race, or snagging something already gone, gives no message (`Snag` returns silently).
- -0.5 not tested: real touch input and auto-aim on a device.

### 7. Security, persistence, multiplayer - 6.0
Passed:
- **Race**: P1 and P2 snagged the same fresh Goober in the same frame. Exactly one carrier, one charge ($50 to P1, $0 to P2) and one model.
- **No dropped-Goober duplication**: a drop followed by a simulated leave left nothing on the field and put it at home with the same uid. A later Snag of that uid did nothing.
- **Death**: Health = 0 drops the Goober where you fell. The player respawns at base about 3.8 s later with 5 s SpawnSafeUntil.
- Hit spam, cross-wall shots, the snag grace and rate limits all held.
- Real hold E on a steal prompt, followed by the victim blasting the thief, sent the Goober back to the owner.

Deductions:
- -1.5 **Leaving the game banks a carried Goober instantly and safely**. I carried a Goober knocked loose from P2 in mid-field at (-41, -12) and ran `Carry.OnRemoving` (the leave path). It went straight onto a stand, with `delivered` +1 and **`combatSteals` +1**. Any carrier being chased can rage-quit to bank it, and a Secret Goober is well worth a rejoin. Death drops the Goober but leaving does not, which is inconsistent.
- -1.0 **a dropped Goober is destroyed silently if the dropper's base is full** when it expires (`settleDropped` → `vanish`) or when they leave (`BreachService.OnRemoving`). Test: P1 was hit while carrying Pebble Pete ($50 paid) and filled the base to 18/18. After 22 s Pete was gone, with no message and no refund (Pete count at home unchanged at 2). The capacity check ignores dropped Goobers, so this is easy to hit by snagging another Goober after being blasted.
- -1.0 the leaderboard's `S.Data.OnRemoving` hook runs up to 5 yielding `UpdateAsync` calls **before** `DataService.Save` (the hooks run in order, then the save). Under OrderedDataStore throttling this can delay the critical save past the 25 s BindToClose wait or extend the session lock. It should run after the save or in a `task.spawn`. Found in code, not reproduced.
- -0.5 360° aim spoofing (see category 2).

### 8. Performance and release readiness - 6.5
Console: the server, both clients and the solo play were clean. The only error was from my own probe script. Server heartbeat was 60, about 50 loose Goobers (7-16 parts each, about 700 parts), and the table count matched the folder count (50/50), so nothing leaked. The client had 5,523 parts, about 1.95 GB Studio memory and 60 fps. Effects use Debris, and vanished, dropped and claimed models were destroyed.

Deductions:
- -1.5 not releasable as is: the Breach, Blaster and Mart are stand-ins and SAG_SFX3 is not uploaded, so there is no new audio.
- -1.0 all four cauldrons spawn and replicate Goobers non-stop with nobody on the island (about 35 models, each with a BillboardGui). Each client also sets the CFrame of every loose Goober every RenderStepped, with no distance culling.
- -1.0 combat balance issues (#1, #2, #4 below) must be fixed before players see them.

---

## Ranked problem list

No **critical** defect found: no duplication, no free Goobers from a race, no cross-wall hits, no hit spam.

### Major
1. **Leaving the game = instant safe delivery** (and combat-steal credit). *Evidence:* a mid-field carry put on a stand by `Carry.OnRemoving`, `combatSteals` 1→2, `delivered` 25→26. *Fix:* on leave, treat a Breach carry like death (`DropFromCarry`, landing home only through the normal 20 s waddle and only if nobody grabs it), or put it back on the field reserved for 20 s. Never count `takenFrom` or `delivered` on a leave.
2. **Combat-steal stat farming with a friend** (MASTER THIEVES, plus `hits`). *Evidence:* the ping-pong cycle above, $10 per point. *Fix:* a per-pair cooldown (for example 120-300 s, like base theft) before `takenFrom` counts. Only count steals where the victim paid at least X% of the Goober's price, or where the victim isn't on your friends list. Optionally rank combat steals separately from base thefts.
3. **Dropped Goober destroyed silently when the dropper's base is full.** *Evidence:* Pebble Pete vanished at 18/18, with no toast and no refund. *Fix:* count your own unclaimed drops in `Session.Used`, so you can't fill the slot, or refund `paid` with a message in `settleDropped` and `OnRemoving`.
4. **The attacker wins the drop race; "counterplay" is nominal.** *Evidence:* timings from Config plus the measured 0.55 s landing and 4-stud push. *Fix:* the attacker gets the same lockout as the victim, or longer (for example 1.5 s), or the drop flies sideways or back toward the victim. Alternatively, cut the snag range for dropped Goobers to about 8 studs.
5. **Sprint Boots outruns every carrier** (paid advantage in combat). *Fix:* turn Sprint Boots off while the Blaster is "hot" (for example 3 s after firing), or give carriers the same +4. At minimum, rewrite the pass description.
6. **The Blaster is client-only**: there is no threat telegraph, the Glam golden blaster is invisible to others, and the gold is not applied until the gun is rebuilt. *Evidence:* the server and the other client have no GooBlaster, and the gun stayed purple after the grant. *Fix:* weld a server-side (or replicated) blaster model to the character when `canUse` is true, coloured from the Glam attribute, and rebuild it when the attribute changes.
7. **Leaderboard writes are ahead of the final save.** *Fix:* register the leaderboard hook as `AfterRemove`, or `task.spawn` it, so `DataService.Save` never waits on OrderedDataStore budget.
8. **TOP EARNERS counts refunds and Robux packs.** *Fix:* add to `totalEarned` only for income (Collect, AutoCollect, offline earnings), not in `Session.AddCoins`, or add a `source` parameter.

### Minor
9. Aim not checked against facing; 360° auto-aim possible (verified while facing away). *Fix:* require `aim:Dot(hrp.CFrame.LookVector) > 0` with slack (the client already turns before firing), or check against the last few server-side facings.
10. No lag compensation; the client auto-aim reaches 16 studs and the server 14. *Fix:* keep about 0.25 s of position history per player and validate against `t - ping`, and make the client range match.
11. The Rebirth Shrine blocks the centre leaderboard; board text is tiny; the arch subtitle is clipped. *Fix:* move the shrine behind or beside the boards, use bigger rows (or fewer rows with avatars), and widen the sign or shrink its text.
12. The Goober Mart and Chaos Rift sit on bare grass with no path; the east side looks empty. *Fix:* pave a small east plaza to match Champions Plaza, with a path from the oval.
13. Phone: leaderboard tabs 7-10 px; the nav bottom row overlaps the thumbstick zone with the 58 px inset. *Fix:* icon-only tabs or a larger MinText on phones; lift or shrink the nav when `UI.small`.
14. Lv < 3 players get a toast on every click. *Fix:* throttle it to once per 10 s, or don't bind mouse fire until Lv 3.
15. Goobers land up to 7 studs from some plot doors (unblastable within the grace); corner plots have about 50% longer carries. *Fix:* keep landings at least 20 studs from doors, or bias landings toward the field's centre line.
16. Cauldrons run with nobody on the island; no distance culling for loose-Goober animation on the client. *Fix:* pause a site's blasts when no player is in its area, and skip CFrame updates beyond about 250 studs.
17. SLOP STORM copy says "3x faster", but the cycle is 1.5x.
18. Dropped island Goobers skip the area gate (only the level is checked); a drop can fly through a base entrance into someone else's base.
19. A lost grab race or a stale snag gives no feedback.
20. "Collected" leaves out waddled-home Goobers but includes leave-banked ones (fixed by #1).

---

## Brief checklist

| Check | Result |
|---|---|
| Breach acquisition | PASS: cycle timings exact, 5 sites, snag charges the price, a second snag is ignored |
| Delivery | PASS: a cauldron Goober (Boo Blob) through the island portal, walked home: placed, `delivered` +1, Event XP +15, discovery |
| Hit + drop | PASS: grace refusal, hit, 4.00-stud push, stagger, drop, dizzy refusal, other player grabs |
| Counterplay | WEAK: works mechanically, but the attacker almost always wins the race (Major 4) |
| Race | PASS: same-frame double snag gives one carrier, one charge, one model |
| Disconnect / reset | Reset PASS (drops). Leave: no duplication, but **leave banks the Goober instantly** (Major 1). Full base: **Goober lost** (Major 3) |
| Safe zones | PASS for walls and protections; own base, spawn and new-player protections confirmed in code (the developer also logged them). Doorway landings are unblastable (Minor 15) |
| Leaderboards real data | PASS: real ODS data on the boards and in the panel; THIS SERVER live. Accuracy issues: Majors 2 and 8 |
| Pass ownership | PASS: all 11 ids live and price-matched; Glam applies server effects. Golden blaster: Major 6 |
| Mobile combat layout | PASS with notes: 73 px BLAST, 19 px from jump; nav and thumbstick overlap (Minor 13). No real touch test |
| Full map walk-through | Done through screenshots (arena, Champions Plaza, Mart, aerial). Issues: Minors 11 and 12 |
| Halloween regression | PASS: Island travel, intro, cauldron snag (area gate), candy C01 +10 (repeat and far claims ignored), shortcut refused while carrying, portal works while carrying, Event XP |
| Original regression | PASS: Cash Pad collect, Zoomies upgrade (WalkSpeed 16 → 17.5), steal by real hold E then blasted home, Rebirth refused at Lv 10 ("Reach Level 15"), Rebirth panel renders on the real account |
| Console | PASS: clean on the server and both clients; solo play clean |

## Not tested
- Real touch input and auto-aim on a phone or emulator; real network latency (hit registration at range).
- Live-server DataStore and OrderedDataStore throttling, BindToClose with a full server, multiple servers writing to the boards.
- A real Glam purchase and receipt in a live server.
- More than 2 players (3-way fights, third-party grabs).
- The pending Blender imports and the SAG_SFX3 upload (not in the place yet).
- "Leave" was simulated by calling the real `Carry.OnRemoving` path on a connected player; a real disconnect runs the same hook from `PlayerRemoving`.

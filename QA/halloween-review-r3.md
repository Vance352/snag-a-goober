# Halloween update - independent review, round 3 (final)

Reviewer: independent QA agent. Date: 2026-10-09. Build: `6bd5743`. The Studio sources of EventService,
QuestService, ConveyorService, Halloween, GooberData, UI, EventUI, Halloween (client), Feedback and
IslandBuilder are byte-identical to `src/`. Island rebuilt: 2,411 parts, 533 collidable MeshParts,
94 lights, 0 mounds, CastleAvenue present.

**Limits:**
- **Only one player is available, so two-player stealing is still untested.** Not tested: Halloween Goober
  thefts, the "no portal with a stolen Goober" rule, victims away on the island, and catching on the new
  content. This has been true for all three rounds.
- I can't listen to audio; the loop-seam verdict below comes from sample statistics.
- The end of the event can only be checked in code: `Halloween.Active()` uses `os.time()`.

**Test account:** restored and saved.
- Level 30 / xp 750, event Lv10 / xp 170 with levels 1-2 claimed, candy 108.
- Candies C01/C02 found, milestone 3 claimed, chain at quest 7, areas visited Forest + Village.
- Left over: one 40-paid Pumpkin Pip was sold and a Mummy Wrap (paid 580) is now on a stand (base 22/22);
  daily "8 Goobers" is at 4/8.
- Playtest stopped. No Lighting changes.

## End-to-end retests (this build)

| Loop | Result |
|---|---|
| **Portal -> island belt -> home (no harness teleports)** | PASS. Walked (pathfinding) from the base into the Spooky Portal, landed at the island arrival, walked through the open Forest gate to (99.5, 631) inside the Forest. Snagged Mummy Wrap (real `Snag` handler). Walked to the return portal, landed at (128, -60), walked home. Placed; event XP 170 -> 200 (+30 Uncommon), placeLeft 30 -> 29, daily "8 Goobers" 3 -> 4, Halloween dex 4/16. |
| **Over-fence snag** (round-2 N1) | BLOCKED, three ways, from the Village by the fence: event Lv10 at the Forest gets "Step into the Haunted Forest to snag from its belt!"; event Lv0 at the Forest gets "Haunted Forest needs Level 8 and Event Level 3."; event Lv0 at the Castle gets "Phantom Castle needs Level 25 and Event Level 14." No snag in 14 s each. |
| **Quest card tap-to-claim** | PASS. First tap on the HUD card (quest 7 done) gave "QUEST COMPLETE +60 Candy +120 Event XP"; chain -> 8. Second tap (quest 8 at 2/12) opened the Quests panel and granted nothing. |
| **Track card claim** | PASS. Three rapid clicks on the LV3 card (151x221 desktop) gave exactly one "EVENT LEVEL 3 +40 Candy"; claimed = {1, 2, 3}. The panel stayed open. |
| **Phone layout 750x381** (UIScale 0.762, 36 px inset, Player card hidden like `UI.small`) | Nav tiles 45x47 px. Menu bottom at screen y 275, thumbstick top 313 (38 px clear). Travel tabs **88x45** (now 44 or more). Quest card 190x74. Status column bottom 251 without a boost pill (286 with one in R2), jump top 313. **3 badges** (Halloween, Levels, Rebirth). Nav label TextSize 8 px. |
| **Candy and bucket reachability** after the new trees and avenue | PASS. Pathfinding from inside each area reached all 30 candies and 6 buckets (worst end miss 0.0 studs). |
| **Gated island toasts** (round-2 N3) | PASS. At event Lv10, a Castle-belt Epic (needs Event 14) gave no toast within 1 s; a Graveyard-belt Epic (needs 8) gave "EPIC Count Goobula is on the Cursed Graveyard belt!". |
| Console | 0 warnings/errors (server output and client LogService) for the whole session. |

## Round-2 items: status

| Item | Status | Evidence |
|---|---|---|
| **N1** over-fence snag | **FIXED** | `Snag` now requires `AreaOpen` and `AreaAt(hrp).key == line.area` (ConveyorService.luau:192-204). Repro blocked as above. |
| **Grim Goober capstone** | **FIXED (balanced)** | Grim Goober 9,000 -> **6,000/s** (= Glitch), Phantom King 7,000 -> 5,000 (GooberData.luau:83-84). Chaos Goob (8,000, Chaos-Rift only) stays the top earner. Still the best non-event Secret and free at track Lv25, but no longer above everything. |
| **N5** post-event state | **MOSTLY FIXED** (code) | After `EndsAt`: the event-level part of gates is waived on server (EventService.luau:64-66), client barrier and toasts; no new dailies roll (QuestService.luau:71-74). Left: the Quests panel still shows "new ones in Xh" (EventUI.luau:372 uses `dailyResetIn` unconditionally); chain quests and milestones still pay candy (acceptable as earned rewards). |
| **N2** stale hints | **FIXED** | Quest 7: "opens at Level 8 + Event Level 3"; quest 10: "needs Level 15 + Event Level 8". |
| **N3** gated toasts | **FIXED** | Live test above. |
| **N4** Bonus Chest overflow | **FIXED** (code) | `chests()` now also runs right after hitting Lv25 (EventService.luau:205-209). |
| **N6** `Enabled=false` on the client | **FIXED** (code) | Island tab hidden and the walk-in portal and portal prompt off when `Enabled=false` (UI.luau:1151, Halloween.luau:187-189, 338). Not toggled live (would need a script edit). |
| **N7** blob mounds | **FIXED** | 0 `Mound` parts on the island; spooky trees at the slab corners instead. |
| **N8** badge overload | **FIXED, with a small regression (R1 below)** | At most 3 badges are shown (UI.CapBadges); the phone check showed exactly 3. |
| **N9** WAV folder | **FIXED** | The three WAVs are back in `Assets/Audio/`; `Assets/StorePage/` holds only store PNGs. |
| **Halloween loop seam** | **ACCEPTED (developer claim verified)** | numpy on `Assets/Audio/SAG_HalloweenTheme.wav`: seam |s[0]-s[-1]| = **2,152**. In-track sample-to-sample jumps of 2,152 or more: 99,444 = **2,486 per second**. Median 555, p99 5,312, max 15,335. Near the start the median jump is 2,808 (the loop opens on a transient), so the seam is inside the signal's normal range and masked by the onset. Main theme seam 321. Not checked by ear. |
| **Mobile leftovers** | **MOSTLY FIXED** | Tabs 88x45 (were 91x42). Nav labels still 8 px at phone scale (TextSize 8; "UPGRADE" is cramped). Track-card state bar still below the fold at phone scale, but the whole card is the tap target. |
| **Visual leftovers** | **PARTLY FIXED** | New: lantern-lit avenue from the Castle gate to the gatehouse, trees in the Castle front and slab corners, readable two-row odds board (r3_castle_avenue). Still a flat rectangular slab split into a 2x3 grid, a lot of empty Village paving, a Castle front that is mostly open floor, and the red-orange lamp-lit Village path at night. |
| Collection grid alignment | **FIXED** (code) | `HorizontalAlignment = Center` (EventUI.luau:221). |

## New problems found in this round

**R1 (minor regression, confirmed): event-driven badges are hidden for good by the 3-badge cap.**
- The Index badge is turned on only by the `Discovered` notification (Feedback.luau:103-106).
- `UI.CapBadges` (UI.luau:1194-1208) hides it whenever three higher-priority badges are on. Nothing ever
  sets it back to visible, so it doesn't return when those clear.
- Seen: Mummy Wrap was a new Halloween discovery this session, yet the badges shown were Halloween, Levels,
  Rebirth and no Index.
- Fix: keep a "wanted" flag per badge and apply the cap to the wanted set on every refresh, instead of
  writing `Visible = false` into the source of truth.

**R2 (minor, post-event copy): "DAILY QUESTS new ones in Xh" keeps counting down after the event**, even though
no new dailies will roll (EventUI.luau:372). Show "Event over" instead when `ev.active` is false.

No other regressions found. Checked: the 4x2 nav with the "OPTIONS" rename, track cards as buttons (no
double grants, panel doesn't close), quest-card claim, gates needing event level, Bonus Chest code path, daily
placement cap (placeLeft drops 1 per belt Goober), event-end gating in code, island rebuild (all pickups
reachable, collidable meshes 509 -> 533 from the new trees and lanterns).

---

## Final scores

| # | Category | R1 | R2 | R3 | Reasons |
|---|---|---|---|---|---|
| 1 | Visual quality | 6 | 7 | **7** | Plus: castle landmark with avenue and lanterns, readable gantries, dark silhouettes, decent night mood in the Forest and Graveyard, consistent original icon set. Minus: still a flat 2x3 grid slab floating in the void; Village plaza and the Castle front are mostly empty floor; Village path glows red-orange under the pumpkin lamps. |
| 2 | Gameplay quality | 5 | 6 | **7** | Plus: the island loop works end to end and is worth doing; event XP paced over days (21,750 XP, 30 full-XP Goobers a day); dailies matter; Personal Drops wait; capstone now on par with Glitch; gates can't be dodged. Minus: veterans still finish in about a week and grinders in about 2 days; candy sinks are thin after one Count Goobula; stealing on the new content is untested. |
| 3 | Progression | 5 | 6.5 | **7.5** | Plus: player-level and event-level gates enforced on area entry *and* on the belts; saved area visits (no soft-lock); merged level-up banner; Bonus Chests after 25; small veteran milestone candy; post-event gate waiver. Minus: still fast for engaged veterans; post-event copy (R2). |
| 4 | UI/UX | 6 | 7.5 | **8** | Plus: panel taps no longer close panels; whole-card claims; quest card claims in one tap; default tab and scroll reset; capped badges; clear lock texts; travel cooldown feedback. Minus: badge cap swallows discovery cues (R1); track state bar below the fold on small screens; nested horizontal-in-vertical scroll on the track. |
| 5 | Mobile usability | 5 | 7 | **7.5** | Plus: measured at 750x381, all primary targets are 44 px or more (tiles 45x47, tabs 88x45, cards 85x125, quest card 190x74, X 54x45); 38 px thumbstick and 27+ px jump clearance; no mid-word wraps. Minus: nav labels 8 px; emulated layout only, not a real device. |
| 6 | Audio | 3 | 6.5 | **7** | Plus: distinct main and island themes live with a measured 2.5 s crossfade; 8 new SFX on the right regions; seam statistically within the music's own jumps. Minus: not judged by ear; short loops (48 s / 40 s) will repeat during long sessions. |
| 7 | Technical quality | 7 | 6.5 | **8** | Plus: server authority closed (over-fence snag refused three ways); every claim idempotent under rapid taps; waddle-home credits progress; boost-proof coin rewards; saves versioned and reconciled; clean console. Minus: **two-player stealing on the new content never verified**; post-event behaviour checked only in code. |
| 8 | Performance & release readiness | 6 | 7 | **7.5** | Plus: 0 console warnings/errors; 533 collidable meshes (was 1,203); no shadow-casting lights; assets uploaded and Approved; sources in sync with git. Minus: island 2,411 parts / 94 lights always streamed (it sits inside the default streaming radius); no 2-client regression run on this build; badge regression R1. |

**Overall: 7.5 / 10.** The round-1 critical and every major item are fixed or reduced to minor, with fresh
evidence. No exploit or save problem is open that I could test. It stays below 8 because:
- the island still reads as a flat grid with empty stretches,
- veteran pacing is about a week,
- two-player theft on the new content has never been tested.

## Remaining problems (ranked)

**Major (verification gap, not a known defect)**
1. **Two-player stealing on the new content is untested** (one-player limit, all rounds). Before publishing,
   run a 2-client Studio session for:
   - stealing a Halloween Goober,
   - the stolen-Goober portal refusal,
   - a victim on the island using the Base shortcut to defend,
   - a thief disconnecting with a Halloween Goober.

**Minor**
2. **Visual:** flat 2x3 slab, empty Village plaza and Castle front, red-orange lamp-lit Village path at
   night. Add height (stairs, raised plaza, hills), cluster props, and cool the lamp colour on the path.
3. **Pacing for veterans:** the track takes about 6-7 days at 1 h/day and about 2 days for grinders. Fine for
   a 31-day event, but expect a long tail with only dailies and Bonus Chests. Consider a few more candy sinks
   (cosmetics, titles, more shop stock).
4. **R1:** the badge cap permanently hides event-driven badges (Index discovery cue lost).
5. **R2:** "new ones in Xh" daily countdown shown after the event ends.
6. Nav labels 8 px at phone scale ("UPGRADE"/"OPTIONS" cramped). Try MinText 9-10 or shorter labels.
7. Track card state bar below the fold on small screens (the tap still works); horizontal scroll inside a
   vertical scroll.
8. Short music loops (48 s / 40 s); loop seam fine by statistics, unverified by ear.
9. The whole island is always streamed (2,411 parts, 94 lights). Acceptable now; watch client memory on
   low-end phones.

# Halloween update - independent review, round 2

Reviewer: independent QA agent. Date: 2026-10-09. Build: `c9ba91d`. The Studio sources of EventService,
QuestService, CarryService, Session, DataService, Halloween, Config, UI, EventUI, Halloween (client),
Feedback and IslandBuilder are byte-identical to `src/`. Place 90695592143707, Studio Play, solo client,
1429x852 viewport, plus a forced 750x381 phone layout (UIScale 0.762, 36 px inset, Player card hidden the
way `UI.small` does).

**Limits (unchanged from round 1):**
- One player only: stealing and catching are still not tested in this round.
- I can't listen to audio; I checked Sound instances, regions and fades on the client.
- Clicks are Studio's synthetic input.
- The end of the event can only be checked in code: `Halloween.Active()` uses `os.time()`, and I may not
  edit scripts.

**Test account:** restored to the state at the start of this round:
- Level 30 / xp 600, event Lv10 / xp 170 with levels 1-2 claimed, candy 68.
- Candies C01/C02 found, milestone 3 claimed, chain at quest 7, areas visited Forest + Village. Saved.
- Left over:
  - The 0-paid Pumpkin Pip on a stand was sold and replaced by a 40-paid one; the base is still 22/22.
  - Today's daily progress is "8 Goobers" 3/8.
  - A Spooky Boost is still running (about 6 min left at stop).
- Playtest stopped. No Lighting changes.

---

## Round-1 problems: status

| R1 item | Status | Fresh evidence |
|---|---|---|
| **C1** music/SFX not in game | **FIXED** | Client: `MusicMain = 115688752797061` (48.0 s, loaded) and `MusicIsland = 128091419086773` (40.0 s, loaded). Island Sounds for Portal/Candy/Bucket/Quest/EventLevel/Reward/Locked/Area exist on `84417681107169` (9.95 s) with regions matching `SAG_SFX2.json`. Portal crossfade sampled every 0.5 s: main 0.209/0.133/0.068/0.021/0.001/0 (then paused), island 0.011/0.087/0.152/0.199/0.219/0.220. Never two tracks at full volume. |
| **M1** quest 7/10 soft-lock | **FIXED** | Quest 7 showed 1/1 from the Forest visit saved in an earlier session, and claimed by tapping the HUD quest card. Repro for quest 10: cleared `areasVisited.Graveyard`, walked into the Graveyard, left, set the chain to 10. Result "Enter the Cursed Graveyard 1/1". |
| **M2** pacing / capstone | **PARTLY FIXED** | See *Pacing* below. The track is now 21,750 XP with 30 full-XP Goobers a day. About 6-7 days for a veteran playing about 1 h a day, about 1.5-2 days for a hard grinder, about 10-14 days for a new player. The Lv25 capstone is still Grim Goober (9,000/s base, the best in the game). |
| **M3** tap inside a panel closes it | **FIXED** | `Panel` is now a TextButton. Hooked every backdrop button's `Activated`; clicked the header, the tab row and an empty body corner: 0 backdrop hits, panel stays open. A click outside the panel still closes it (1 hit). |
| **M4** mobile targets / wrap / overlap | **MOSTLY FIXED** | At 750x381: nav tiles 44x47 px (4x2 grid), menu ends at screen y 275 (thumbstick starts at 313: 38 px clear). Status column ends at 286 (jump at 313: 27 px clear). Travel tabs 91x42 (2 px under 44). "SPOOKY" on one line. Quest card 190x74 is the tap target. Track cards (85x125 visible) are tap targets: tapping LV3 at phone scale gave "EVENT LEVEL 3 +40 Candy". Nav labels ("UPGRADE", "REBIRTH") are about 7-8 px tall. |
| **M5** Personal Drops expire on the island | **FIXED** | On the island `nextDropIn` went 28.8 -> 19.2 -> 14.2 -> 9.1 -> 5.9 -> 5.5 and held. No `PersonalDrop` note for 50 s. The HUD reads "Personal Drop waits for you". The drop arrived after returning to the base. |
| **M6** level gates moot for veterans | **FIXED in design, BYPASSED in code** | Gates need player level AND event level. A Lv30 player at event Lv2 was pushed out of the Forest with "Haunted Forest needs Level 8 and Event Level 3.", and the client barriers stay solid. Milestone candy for a Lv30 veteran is now 210 (was 960). **But the belts don't check event level: see N1.** |
| **M7** castle / island look unfinished | **PARTLY FIXED** | Edit-mode shots: a real Phantom Castle now stands (curtain walls with battlements, gatehouse with arch, portcullis and sign, four corner towers, keep with spire, banners, courtyard). Graveyard has paths, a crypt and trees; lantern ring and pumpkin piles in the Village; edge rocks. Still a flat rectangular slab split into a grid. The front half of the Castle area and most of the Village are still bare. The new "mounds" are dark smooth grey half-spheres that read as blobs (see V1). |
| m1 waddle-home skips progress | **FIXED** | Snagged a Pip on the island and reset at once ("waddling home on its own (33s)"). After landing ("Pumpkin Pip made it home!"): event XP 185 -> 200, placeLeft 28 -> 27, daily "8 Goobers" 2 -> 3. |
| m2 boost stacking | **FIXED** | Rate 3,408/s, bought Spooky Boost (rate 6,816/s), claimed milestone 5: "+$1.02M" = 300 s x 3,408 (un-boosted). Track preview shows +$408K (un-boosted). |
| m3 double discovery | **FIXED** (code) | `grantGoober` no longer calls `Discover` (EventService.luau:132). |
| m4 main-world toasts on the island | **PARTLY FIXED** | Slop/Gold Line Epics are suppressed on the island. Slop-Line Legendary/Secret banners still show there (by design, it seems). New issue: N3. |
| m5 thumbnails eyes-only / silhouettes leak | **FIXED** | Collection silhouettes are fully dark (eyes included). Viewports stay hidden until `PreloadAsync` finishes (3 s max). No eyes-only frames seen. |
| m6 "QUEST BOAR" clipped, odds wrap | **FIXED** (built) | Booth sign is wider (13 x 3.2) and odds are split onto two rows (IslandBuilder.luau:291-296). I didn't re-screenshot the sign close up. |
| m7 orange night wash / dark Goobers | **PARTLY FIXED** | Client Lighting on the island: Brightness 2.2, cool Ambient (96,84,130), ColorShift_Top (60,44,70). Belt Goobers and pumpkins now read at night. The Village path is still strongly red-orange under the pumpkin lamps (screenshot r2_hud_island). |
| m8 candies "hidden" vs hint | **FIXED** | Hint now reads "Follow the pink sparkles!" |
| m9 short loops / Halloween loop seam | **NOT FIXED** | The WAVs are byte-identical renames (git: `Assets/{Audio => StorePage}`). The Halloween loop still wraps -3277 -> -1125 (jump about 2,150 vs about 300 typical). Uploaded asset presumed the same file; check by ear. Loops are still 48 s / 40 s. |
| m10 one banner per level | **FIXED** | eventXP 22,000 gave one note `EventLevel {from 1, level 25}` and a "LEVEL 1 -> 25" banner. |
| m11 no cooldown feedback | **FIXED** (code) | Shortcut presses during the cooldown now say "Travel is recharging - try again in a moment." (EventService.luau:417-419). |
| m12 coin-reward comment | **FIXED** | Comment now says "un-boosted income, at least 2 per second". |
| m13 event end / Enabled switch | **PARTLY FIXED** | After `EndsAt`: Event XP, candy pickups and buckets stop; claims and shop stay open; HUD says "Event over". But see N5 and N6. |
| m14 precise-collision decor | **FIXED** | 509 collidable MeshParts (was 1,203). Pumpkins, shrooms, lollipops, candy and fence meshes no longer collide. Tombstones, trees and towers still collide (fine). |
| m15 daily collect target boosted | **FIXED** (code) | Uses `Session.BaseRate` (QuestService.luau:77). |
| m16 panel reopens mid-scroll / old tab | **FIXED** | `UI.Open` resets the canvas and defaults Halloween to Track (UI.luau:550-556); reopening showed Track at the top. |
| m17 Spooky tab during the tutorial | **FIXED** (client) | With tutorial = 2 the Island tab was hidden (Base/Plaza visible). The server still accepts `Travel "Island"` during the tutorial; harmless. |

### Pacing (from the new Halloween.luau numbers)

**XP needed:**
- Event Lv0 -> 25: sum over L=0..24 of (150 + 60L) = **21,750**.
- Gates: Forest needs Event Lv3 (630 XP), Graveyard Event Lv8 (2,880), Castle Event Lv14 (7,560).

**XP per Goober brought home** (full XP for the first 30 each UTC day, then 20%):

| Belt | Full XP | Tired XP | 30 full Goobers |
|---|---|---|---|
| Pumpkin | 23.7 | 4.7 | 711 |
| Forest | 42.4 | 8.5 | 1,270 |
| Graveyard | 84.0 | 16.8 | 2,518 |
| Castle | 120.5 | 24.1 | 3,616 |

Other sources:
- Dailies: about 535 XP/day (3 picked from a pool averaging 178).
- One-offs: quest chain 2,010 + candies 600.

**Time to finish:**
- **Veteran, about 1 h a day:** day 1 about 4.5-5k (around Event Lv8), day 2 reaches Event Lv14. After
  that the Castle gives about 4.1k a day, so the track is done in **about 6-7 days**.
- **Hard grinder past the cap:** Castle at 24 XP a trip and 2-3 trips a minute is about 3-3.6k XP/h, so
  **about 1.5-2 days**.
- **New player:** Pumpkin + Forest about 1.3k + 535 a day, so **about 10-14 days** (they gain player levels
  for the Graveyard on the way).

The developer's claim "2-3 weeks of daily play" holds for new players, not veterans. Acceptable for a 31-day
event. The Grim Goober capstone is still a 9,000/s Secret handed to whoever finishes.

---

## New defects introduced or exposed by this round

**N1 (MAJOR, exploit/regression): locked-area belts can be snagged from outside the gate, which bypasses the new event-level gate.**
- Cause: `ConveyorService.Snag` checks only `st.data.level < line.levelRequired` (ConveyorService.luau:182-185). The event-level requirement exists only in the area-eject loop.
- Geometry: every belt ends 12 studs inside its area's fence (endX = O.X ± 82, fence at x = ±70), and `SnagRange` is 14.
- Repro: Lv30, `event.level` = 0, stood in the **Village** at (68, 2.3, 638) by the Forest fence.
  - While the base was full: `Conveyor.Snag` on Forest Goobers at belt x=81 returned "Your base is full!", so every other check had passed.
  - After freeing a slot: **"CARRYING H04_BatBrat snagged at belt x=81 from x=68.0 (Village side), eventLevel=0"**.
  - Carried home through the portal: placed, +30 Event XP, placeLeft 30 -> 29.
- Who can use it: any veteran past the player level (most of them, since the test account is 30) can farm the Forest, Graveyard and Castle belts (Castle = 4% / 1.5% Secrets) from the hub at event Lv0. That defeats M6's fix. A normal client can do it too, if the belt prompt reaches through the fence.
- Fix:
  - In `Snag`, if `line.area` is set, require `S.Event.AreaOpen(st, Halloween.AreaByKey[line.area])`.
  - Preferably also require `EventService.AreaAt(hrp.Position).key == line.area`.
  - And/or end the belts at least 16 studs inside the fence.

**N2 (minor): stale quest hints.** They still describe the old player-level-only gates. Quest 7: "The Haunted
Forest gate opens at player Level 8." Quest 10: "Unlocks at player Level 15." (Halloween.luau:218, 221). Both
now also need Event Lv3 / Lv8. A veteran at Lv30 with event Lv2 reads "opens at Level 8", walks up, and is
pushed back.

**N3 (minor): island rare-spawn toasts ignore the event-level gate.** At event Lv2 (Castle needs Lv14) the HUD
showed "EPIC Count Goobula is on the Phantom Castle belt!". `Feedback.luau:342` checks only `s.level <
spawnLine.levelRequired`. Use the area's event level as well.

**N4 (minor): Bonus Chest overflow sits unpaid.** When a big grant lands on Lv25, the leftover goes to
`bonusXp` but isn't converted (EventService.luau:205-207 only converts on the next grant). Seen as "MAX! Bonus
Chest 600 / 600" until another +100 XP paid it out. Run the chest conversion after the level loop too.

**N5 (minor): the "event over" state is inconsistent.** The Config comment says "After it: no more Event XP or
candy", but:
- Daily quests keep rolling and the chain and milestones still grant candy (`AddCandy` is not gated), so candy
  keeps flowing.
- Area gates still need event level, which is frozen after the end. Anyone who hadn't reached event Lv14 (or
  reaches player Lv25 later) is **locked out of the Phantom Castle and its belt permanently** while the island
  stays up.

Decide the post-event island: drop the event-level part of gates once `not Active()`, or close the island,
and stop daily rolls.

**N6 (minor): `Enabled = false` doesn't hide the tabs or portal on the client.** Halloween.luau:13 says
"portal and tabs off". Only the server refuses (`"Halloween Island is closed."`, EventService.luau:411-413).
Nothing in the client reads `Enabled` (grep), so the Spooky tab, portal swirl and island stay visible.

**N7 (minor, visual): the new mounds look like blobs.** They are dark smooth half-spheres ("Grass" material,
colour 46,36,58) that read as grey blobs in daylight overview and close-up (r2_mound). Candy C09 sits at the
foot of one. Still reachable: walked to C09 and C11 and both collected.

**N8 (minor, UX): red badges everywhere.** On the 4x2 nav, 6 of 8 tiles showed a red badge at once (Event,
Index, Quests, Levels, Upgrade, Rebirth). At 44 px tiles the dots cover the tile corners and lose meaning.
Consider badges only for claimable rewards.

**N9 (hygiene): audio sources moved to the wrong folder.** The three generated WAVs were moved from
`Assets/Audio/` to `Assets/StorePage/` (store-art folder). `Config.luau` comments and
`tools/make_audio_halloween.py` (writes to `Assets/Audio`) still point at `Assets/Audio`.

**Checked and fine:**
- Every candy and bucket can be reached:
  - Pathfinding from inside each area reached all 30 candies and 6 buckets.
  - Walking the character collected C26 (castle corner by a tower), C27 (inside the castle walls), and C09,
    C11, C12 (near mounds).
- Track cards as buttons fire `ClaimEvent` for locked or claimed cards too; the server ignores those. No
  double grants.
- Tapping the quest card claims only when the quest is done (otherwise it opens Quests).
- Console clean (server and client LogService) for the whole session.

---

## Scores

| # | Category | R1 | R2 | Reasons |
|---|---|---|---|---|
| 1 | Visual | 6 | **7** | Plus: a real castle landmark, graveyard paths/crypt, village dressing, edge rocks, better night palette, dark silhouettes. Minus: still a flat grid slab; Castle front half and Village largely bare; blob mounds (N7); path still orange-red under the lamps. |
| 2 | Gameplay | 5 | **6** | Plus: pacing now days not hours, daily soft cap, Bonus Chests, Personal Drops paused. Minus: N1 lets veterans farm locked belts at event Lv0; Grim Goober capstone still beats every Goober; candy sinks still thin after one Count Goobula. |
| 3 | Progression | 5 | **6.5** | Plus: soft-lock fixed, layered gates, bonus track, merged banners, small milestone candy. Minus: N1 undermines the event gates; stale hints (N2); permanent Castle lockout after the event (N5). |
| 4 | UI/UX | 6 | **7.5** | Plus: panel-tap bug fixed, whole-card claims, quest-card claim, default tab and scroll reset, loading-safe thumbnails, cooldown feedback. Minus: badge overload (N8); misleading toast (N3); collection grid still left-aligned; track state bar still below the fold on desktop. |
| 5 | Mobile | 5 | **7** | Plus: 44x47 tiles, 38 px thumbstick clearance and 27 px jump clearance measured, no mid-word wrap, card and quest-card tap targets. Minus: tabs 91x42 (just under 44); nav labels about 7-8 px; track state bar cut off (tap still works); not checked on a real device. |
| 6 | Audio | 3 | **6.5** | Plus: distinct main and island themes live, smooth 2.5 s crossfade measured, all 8 new SFX present on the right regions. Minus: can't hear quality; 40-48 s loops; Halloween loop-seam jump unchanged (likely click). |
| 7 | Technical | 7 | **6.5** | Plus: every round-1 fix verified (M1, M3, M5, m1, m2, m3). Minus: **N1 is a new server-authority gap**, plus N4/N5/N6. Lower than R1 because a gate that was enforced is now bypassable. |
| 8 | Performance & release | 6 | **7** | Plus: clean console, collidable precise meshes 1,203 -> 509, 0 shadow lights. Minus: parts 2,052 -> 2,342, lights 62 -> 88; whole island still always streamed; two-player regression still not run; N9 asset hygiene. |

**Overall: 6.5 / 10.** A clear improvement and most round-1 defects are really fixed. It isn't higher
because the main new design control (event-level gates) can be bypassed server-side (N1), the capstone is
still out of balance, and stealing remains unverified.

## Remaining problems (ranked)

**Major**
1. **N1: snag locked-area belts from outside the gate** (no event-level check in `ConveyorService.Snag`;
   belt ends are 12 studs inside the fence). Fix as described above.
2. **M2 remainder: the Lv25 capstone is Grim Goober (9,000/s)**, above Chaos Goob and Glitch, reachable in
   about 1.5-2 days of heavy grinding. Make it cosmetic, or a capped-income exclusive, or move the Secret
   behind the full collection.
3. **Stealing on the new content is still unverified** with two players: Halloween Goober thefts, the
   portal-with-stolen-Goober refusal, victims away on the island.

**Minor**
4. N5: the post-event state is inconsistent (candy still flows; permanent Castle lockout).
5. N2: stale quest 7/10 hints.
6. N3: Castle/Graveyard toasts shown to players without the event level.
7. M7 remainder: flat slab, bare Castle front and Village, blob mounds (N7), red-orange lamp-lit path.
8. m9: Halloween loop seam (about 2,150-sample jump) and short loops. Fade or crossfade the loop point in
   `make_audio_halloween.py` and re-upload.
9. N8: badge overload on the 4x2 nav.
10. M4 remainder: tabs 42 px tall at phone scale; nav labels about 7-8 px.
11. N4: Bonus Chest overflow isn't paid until the next XP gain.
12. N6: `Enabled = false` doesn't hide the client tabs or portal.
13. N9: WAV sources moved into `Assets/StorePage`.
14. Collection grid left-aligned (7 columns, empty right side).

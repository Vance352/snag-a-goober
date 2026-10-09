# Halloween update - independent review, round 1

Reviewer: independent QA agent. Date: 2026-10-09. Build: `6273040` (git clean; Studio sources of
EventService, QuestService, CarryService, Halloween, Config, GooberData, UI, EventUI, Halloween (client),
Effects and Feedback byte-identical to `src/`). Place: Snag A Goober (90695592143707), Studio Play, solo client
(cooolvance55), 1429x674 viewport (later 1429x852), plus a forced 750x381 phone layout.

## Limits of this review

- **One real player only.** Two-player stealing was not tested: not stealing Halloween Goobers, not the
  "no portal with a stolen Goober" rule (checked in code only, EventService.luau:391), not victims away on
  the island. Those verdicts come from reading the code.
- **Audio can't be heard.** I checked the WAV files with a script (length, peak level, loop seam) and checked
  in the client which Sound instances exist. I listened to nothing.
- Mouse clicks came from Studio's synthetic input (MCP). The "tap on a panel closes it" bug was confirmed by
  hooking the backdrop's `Activated` event (it fired). It is still worth one real-mouse/touch check.
- Test-account changes I made (all through the harness, then mostly put back): sold 3 cheap classics
  (Blorp and 2 Pebble Pete, stands 21/20/8); +1 Boo Blob (track reward) and +2 Pumpkin Pip (one placed, one
  auto-landed) are now on stands; coins went up from income. Level is back to 30 and xp to 200. Halloween state
  is back to candy 68, event Lv2 with 1-2 claimed, C01/C02 found, milestone 3 claimed, chain 3. Daily
  progress and bucket cooldowns were reset. Saved. Playtest stopped.

## What I tested in Studio (evidence)

| # | Test | Result |
|---|---|---|
| 1 | Reset Halloween, Lv5, walk into the main Spooky Portal (pathfinding) | PASS. Lands at island arrival (0,2.3,594), night lighting, intro opens (3 pages, Next and Skip work), quest 1 done, CLAIM on the HUD card gives +20 Candy +40 Event XP |
| 2 | Level gate at Lv5 | PASS. Pathfinding can't route through the Forest barrier; server tp into the Forest is pushed back to (62,2.3,640) within 1.6 s with "Haunted Forest unlocks at Level 8." |
| 3 | Candy C01 by walking | PASS. +10 candy, +20 Event XP, Event Lv 0->1. Far `CollectCandy C30` ignored |
| 4 | Bucket B1 with real E-hold, again, then B2 from 52 studs | PASS. +4, then "refills in 4:59", far request ignored |
| 5 | Snag Boo Blob on the Pumpkin belt, walk to the return portal, walk home | PASS. Placed, Halloween dex 1/16, chain quest 2 done, +15 Event XP, daily "8 Goobers" +1 |
| 6 | Event track: claim 1, claim 1 again, claim 2 (not reached), 0 / -1 / NaN | PASS. Granted once, everything else silently ignored |
| 7 | Quest chain claim twice, daily claims (not done / 1.5 / "1" / 99), milestone 5 twice, milestone 10 at Lv6, HDex 4 with 1 found | PASS. Granted once each, rest refused |
| 8 | Candy Shop: Spooky Boost, Hex (can't afford), bogus key `__index` | PASS. Boost doubles rate (3392 -> 6784/s); Hex refused with a message; bogus ignored |
| 9 | Track claim 10 (Goober) with a full base | PASS. "Your base is full! Make room..." and nothing is marked claimed |
| 10 | Shortcuts: far PortalOut, Base, Island within the 4 s cooldown, bogus "Castle", Base while carrying | PASS (server). Note: the cooldown press gives the player no feedback |
| 11 | Save then readStore | PASS. v2, candy, event, candyFound, quests (daily list and day), levelClaimed, flags, lock all written; migrateTest and sanitizeTest OK |
| 12 | **Area-quest repeat** (enter Forest, then set chain to 7 "Enter the Haunted Forest", leave, re-enter) | **FAIL.** No AreaEnter and quest stays 0/1 (see M1) |
| 13 | **Reset while carrying a Halloween Goober from the island** | **FAIL (progress loss).** Goober lands later (now 4 Halloween on stands) but Event XP stayed 80 and daily "8 Goobers" stayed 1 (see M6) |
| 14 | **Tap empty part of an open panel** (Event panel header row) | **FAIL.** Panel closes; backdrop `Activated` fired (see M3) |
| 15 | Panels: Event (Track / Candy Shop / Collection), Quests, Levels, Index | Render. Problems listed below |
| 16 | Forced phone layout 750x381 (Root UIScale 0.762, 36 px top inset) | Problems: see Mobile |
| 17 | Music on the client | MusicMain and MusicIsland are both `rbxassetid://85469046329980` (the 34.3 s original); island track never plays; no Portal/Candy/Quest/EventLevel Sound objects exist (fallbacks only) |
| 18 | Console (server + client LogService) | No warnings, no errors across both sessions |

---

## Scores

### 1. Visual quality - 6/10
Good:
- Clear area themes: pumpkin field, forest with glowing mushrooms, gravestones.
- The Great Pumpkin hub, readable gantries and signs.
- Original 2D icons.
- Goober thumbnails match the classic art style.
- The night lighting change works and the Forest at night has atmosphere.

Deductions:
- **(-1.5) Thin endgame.** The island is a flat 400x320 slab split into an even 2x3 grid of rectangles,
  floating in a blue void (edit-mode overview). The Village is mostly empty paving. **Phantom Castle (the Lv25
  endgame area) is three separate towers and some mushrooms on a bare purple floor**: no castle, walls,
  courtyard or landmark. The Graveyard is a uniform grid of headstones.
- **(-1) Lighting and readability.** Night `ColorShift_Top` orange (Halloween.luau:248) washes the Village
  path and ground orange-red, so it reads as sunset more than night. Goobers on the island belts turn dark and
  muddy at night (a Pumpkin Pip on the Forest belt was a dark red blob).
- **(-0.5) Polish.** The "QUEST BOARD" sign is clipped to "QUEST BOAR". Lamp-post pumpkin heads float beside
  the pole tops. Belt end caps are bare black boxes. Gantry odds text is tiny and wraps ("Secret 0.5%" drops to
  a second line). Candy is sparkle-lit in open fields, not "hidden" (the quest hint says "Look behind things!").
- **(-1) Panel art.** Shop and Collection thumbnails show only floating eyes while meshes load (Count Goobula
  still did after many seconds). Collection silhouettes leave the native eye parts white, which gives away
  details. The collection grid is left-aligned with a big empty right side.

### 2. Gameplay quality - 5/10
The loop works and fits the game: snag on a spooky belt, carry it through the portal, place it, earn XP.
Deductions:
- **(-2) Event pacing is far too fast for a 31-day event.**
  - XP to go from event level 0 to 25 = sum over L=0..24 of (60+25L) = **9,000**.
  - A Pumpkin-belt trip (snag, about 120 studs to the portal, about 210 studs home) takes about 20-30 s and
    averages about 24 Event XP (62% x 15 + 30% x 30 + 7% x 60 + 1% x 120). That is about 3,000 XP/h, plus the
    chain (2,010), 600 from candy and dailies.
  - A **brand-new Lv1 player can finish the whole track in about 3-4 hours** of snag, carry home, sell for
    50% back (a Pip costs 40 and sells for 20).
  - A rich veteran on the Graveyard/Castle belts averages 84-140 XP per trip and **finishes in under an hour**.
  - After that the event offers only small dailies.
- **(-1.5) The track capstone breaks the economy.** Track Lv25 = **Grim Goober, 9,000/s base**, the best
  Goober in the game (above Chaos Goob 8,000 and Glitch 6,000), free and reachable by a new player in an
  afternoon. Lv22 Dolly Dread (1,500/s) is also huge for a new player.
- **(-1) Level gates don't gate veterans.** They use the old player level. Most veterans are already above
  15-25 (the test account is 30), so the "unlock new areas as you level" arc is skipped on day one. They also
  claim every level milestone at once (Lv30 = 960 candy + coins). The pre-existing Cash-Pad XP rule (up to
  50 XP per collect, about once a second; BaseService.luau:292-297) gives rich players up to about 50 XP/s, so
  Lv25 takes minutes for them.
- **(-0.5) Island time costs Personal Drops.** Personal Drops keep spawning on the Main belt and expire while
  you are on the island (ConveyorService.luau:241-254). I saw drops of Bubbles McGee and Gumbo during island
  trips. Lucky-pass owners lose the value they paid for. The HUD keeps counting "Personal Drop in 0:00".
- Candy economy is fine early, then piles up. After one Count Goobula (1,800) the only sinks are boosts and
  Bag of Slop. Halloween Goobers are about +10% better per coin than classics (OK), but the real limit is stand
  count, so mid-tier Halloween Goobers don't matter to veterans.

### 3. Progression - 5/10
Good: XP bar, Levels panel with area locks, milestones, 25-level track with a next-reward preview, collection
milestones. Claims are server-side and idempotent (tests 6-9).
Deductions:
- **(-2) Quest 7 / quest 10 soft-lock (M1).**
- **(-1.5) Pacing (see Gameplay).** The track is done in hours. Nothing exists past event level 25 (XP is
  thrown away at the cap, EventService.luau:180-182).
- **(-1) Veterans skip the area-unlock arc** (see Gameplay).
- (-0.5) No "claim all" for the track. A Lv25 player must tap 25 small buttons through a nested scroller.
  Several level-ups at once fire one banner plus one sound each in the same frame (Feedback.luau:229-231).

### 4. UI/UX - 6/10
Good:
- The chunky style is coherent: thick dark outlines, colour-coded rounded buttons, a 3x3 left nav (Event,
  Shop, Index, Quests, Levels, Upgrade, Rebirth, Settings).
- Top travel tabs, top-right player card and quest card with inline CLAIM, coin and candy pills with the event
  countdown, original icons throughout.

Deductions:
- **(-1.5) Tapping any empty spot on a panel closes it (M3).**
- **(-1) Hard to reach.** The track reward cards are cut off at the panel's bottom edge on desktop: you must
  scroll the outer panel to see CLAIM, inside a horizontal scroller (EventUI.luau:135+). The open tab and
  scroll position are remembered, so the panel reopened scrolled to the bottom of Collection.
- (-0.5) Main-world Epic and Legendary spawns ("EPIC Moai Goob is on the belt!") still pop up while you are
  on the island. Only island spawns are filtered (Feedback.luau:339-345). Big toasts sit over the middle of the
  view.
- (-0.5) Small stuff:
  - The Quest card CLAIM button covers the progress-bar count.
  - Red badges hang over the neighbouring buttons.
  - Pressing a travel tab during the 4 s cooldown does nothing, with no message.
  - Tab names are "Belt" / "Spooky" rather than the brief's "Plaza" / "Spooky Island" (acceptable).
- (-0.5) The HUD takes a lot of the screen even on desktop: left column about 310x530 px and right column
  about 340x470 px of a 1429x674 view.

### 5. Mobile usability - 5/10
Measured with the forced 750x381 layout (UIScale 0.762):
- **Touch targets below 44 px:**
  - Quest card CLAIM 73x24 px
  - Event track CLAIM 76x24 px
  - Top travel tabs 85x35 px
  - The nav tiles (53x47) and panel X (54x45) are OK.
- **Mid-word wrap:** the Island tab reads **"SPOOK / Y"** on two lines (the dev log says mid-word wrapping
  was fixed).
- **Thumbstick and jump overlap.** The nav grid ends about 303 px down a 381 px screen. Rebirth/Settings
  overlap the classic thumbstick spot by about 9 px. The dynamic-thumbstick area in the bottom-left is cut to a
  strip about 78 px tall. With all status pills showing, the Personal Drop pill sits about 12 px under the jump
  button.
- **Unreadable text.** The quest card reward line and the "Lv 10: Gold Line unlocked" line are about 6-8 px
  tall. "Reward: +30 Candy +60 Event XP" wraps into a 3rd line.
- The Track tab at phone scale shows only the card tops. CLAIM is below the fold, inside a nested scroller.
- The tap-to-close bug (M3) is worst on touch.

### 6. Audio - 3/10 (mostly unverifiable)
- **(-5) Nothing new is audible in game.** `Config.Audio.MainTheme`, `HalloweenTheme` and `Sprite2` are `""`
  (Config.luau:359-361). The client has MusicMain and MusicIsland both on the original 34.3 s loop. Because the
  ids match, the island track is never played (Effects.luau:135-140), so there is **no zone music change**. New
  SFX map to old ones (Portal->Event, Candy->Coin, Quest->Upgrade...). The brief's new main theme, island theme
  and new SFX are not delivered until upload.
- Good: crossfade logic is sound. Sine 2.2 s fades, a single track when ids match, the Music setting is
  applied instantly on the first snapshot, pause at volume 0.
- (-1) Files:
  - The themes are short loops (48.0 s and 40.0 s, mono, 32 kHz) and will repeat a lot over a long island
    session.
  - The HalloweenTheme loop seam jumps from sample -3277 (last) to -1125 (first), about 2,150, where
    neighbouring samples typically differ by about 300. That is a likely click every 40 s. Check by ear.
  - Main theme seam is fine (271 -> -50).
  - No clipping in any file (peak 29,490).
- (-1) Multi-level event jumps play N EventLevel sounds at the same moment.

### 7. Technical quality - 7/10
Good:
- Server authority is solid. Every grant is server-side.
- Candy: 9-stud 3D radius plus a MoveGuard plausibility check.
- Buckets: 12 studs flat, saved per-bucket cooldown with a clock-jump clamp.
- Portals: 16 studs plus MoveGuard. Area gates are enforced by the server ejecting players. Belt snags check
  the line's `levelRequired` (ConveyorService.luau:182-185).
- Claims use the saved claimed sets (no double claim, tests 6-9); rate limits are in place.
- Wrong types and NaN are ignored. Track Goobers check the base slot before marking claimed. A stolen Goober
  can't use the portal.
- Carry-path offsets move with ServerMove, so portal trips don't trip the anti-teleport and give no shortcut.
  I worked a main-belt -> portal -> island -> portal round trip: net start-position shift is about
  (-22, +26) studs, which is harmless.
- Saves are versioned, reconciled and sanitised.

Deductions:
- **(-1.5) M1 quest soft-lock; M6 hooks skipped on "waddle home".**
- (-0.5) **Boost stacking.** "Seconds of income" coin rewards use `st.rate`, which includes the active 2x
  boost (EventService.luau:79-83, Session.luau:113-120). Buy a 120-candy Spooky Boost, then claim track,
  milestone or quest coin rewards or Bag of Slop for 2x coins. Seen: Lv2 reward preview went from about $407K to
  $814K while boosted.
- (-0.5) **Double discovery.** Reward/shop Goobers are discovered twice: `Base.Place` already calls
  `Progress.Discover` (BaseService.luau:129) and `grantGoober` calls it again (EventService.luau:120). The
  dex "times collected" count is inflated. Harmless otherwise.
- (-0.5) Stealing on the new content was not verified with two players (limit of this review).

### 8. Performance and release readiness - 6/10
Good:
- Console clean (server and client) across two sessions.
- Island built from anchored parts, 0 shadow-casting lights (62 PointLights, average range 12.7).
- Belt count normal (37). Server Lua heap about 2 MB.
- Studio sources match git.

Deductions:
- **(-2) Audio not uploaded.** This is a brief requirement that ships as nothing new.
- (-0.5) **Collision cost.** 2,052 parts on the island, including **1,203 collidable MeshParts with non-Box
  collision fidelity** (pumpkins, mushrooms, headstones, trees). Small decor should be `CanCollide=false` or
  Box.
- (-0.5) **Streaming does nothing here.** The island is 700 studs from the plots, well inside the default
  streaming radius, so the client streamed everything (4,580 parts) while on the island.
- (-0.5) **No end state.** `EndsAt` only feeds a countdown. After 2026-11-10 the event keeps running:
  event XP, dailies, shop and portal all continue. `Halloween.Enabled=false` only drops the island belts from
  Config, so tabs, portal travel and EventService stay live and the island stays in Workspace.
- (-0.5) The two-player regression for the new content is still missing.

### Overall - 5.5/10
No save or security hole was found and the systems are solid server-side. That is better than the average
suggests on technical grounds. Holding it back:
- a progression bug that silently blocks the quest chain,
- an event track that finishes in hours and hands out the best Goober in the game,
- a UI bug that closes panels on any stray tap (worst on phones),
- the audio deliverable not being in game at all.

Not release-ready until M1-M4 are fixed and the audio is uploaded.

---

## Ranked problems

### Critical / release blocker
**C1. New music and SFX are not in the game.**
- Evidence: Config.luau:359-361 are `""`. Client test 17: both music Sounds use `85469046329980`, the
  island never switches track, and no Halloween SFX Sounds exist.
- Fix: upload SAG_MainTheme.wav, SAG_HalloweenTheme.wav and SAG_SFX2.wav, set the ids, re-check that the
  `Regions2` timings match SAG_SFX2.json, and listen to the Halloween loop seam (see A2).

### Major
**M1. Quest chain soft-locks on "Enter the Haunted Forest" (quest 7) and "Enter the Cursed Graveyard" (quest 10).**
- Cause: `EventService` fires the `area` hook only on the first entry per session (`t.areasSeen`,
  EventService.luau:484-487). `QuestService` counts area progress only while that quest is active
  (QuestService.luau:129-133).
- Who hits it: anyone at Lv8+ who visits the Forest before reaching quest 7. That is nearly every veteran,
  because quest 2 sends you to the belts. The quest won't advance until they rejoin the server.
- Repro: test 12.
- Fix: keep a saved `areasVisited` set and treat `area` like `candy`/`eventlevel` (a live count in
  `chainProgress`), or fire the hook on every entry.

**M2. Event track pacing and capstone value.**
- 9,000 XP total. Placement XP is unlimited (EventService.luau:463-468), and snag, carry, sell is a
  near-free loop (sell gives 50% back). New players finish in about 3-4 h, rich veterans in under 1 h.
- Lv25 gives Grim Goober (9,000/s, the best Goober in the game) free; Lv22 Dolly Dread 1,500/s.
- Fix:
  - Tune for the ~31 days: about 3-4x the XP curve, and/or per-day diminishing returns on placement XP (e.g.
    full XP for the first 20 per day).
  - Make dailies the main XP source.
  - Swap the capstone for a cosmetic or capped-income exclusive, or gate it behind a later date.
  - Add a repeatable reward after level 25.

**M3. Tapping any non-button area of a panel closes it.**
- Cause: `panelShell` puts a full-screen invisible close `TextButton` under the `Panel` Frame
  (UI.luau:434-445). Frames don't sink clicks, so taps on headers, labels or gaps go through to it.
- Repro: test 14 (the backdrop's `Activated` fired). On phones this happens constantly.
- Fix: make `Panel` a non-auto-colour `TextButton`/`ImageButton` (it sinks input), or in the close handler
  ignore inputs inside the panel's AbsolutePosition/Size.

**M4. Mobile layout issues.**
- CLAIM buttons 73-76x24 px and travel tabs 85x35 px at 750x381, below 44 px.
- "SPOOK/Y" wraps mid-word.
- The nav grid's bottom row overlaps the thumbstick area and the Drop pill sits under jump.
- Reward and unlock text is about 6-8 px.
- Fix:
  - Make claim buttons and tabs at least 58 design px tall (44 / 0.762).
  - Set MinText so "SPOOKY" fits on one line, or shorten it to "ISLAND".
  - On small screens use a 4x2 nav or move the nav up, and cap the right column so it ends above
    `1 - 100 px`.
  - Hide or shorten the reward line.

**M5. Personal Drops spawn and expire while the player is on the island** (ConveyorService.luau:241-254).
- Seen in the notes: Bubbles McGee and Gumbo drops during island trips.
- Fix: pause `nextDropAt` while the server-side zone is Island (EventService already tracks `t.zone`), or
  hold the drop until they return.

**M6. Level gating and milestones are moot for existing players.**
- Areas and milestones key off the legacy player level (most veterans are already at 15-30+). Rich players
  also gain up to about 50 XP/s on the Cash Pad (BaseService.luau:292-297).
- Fix (design): gate areas by event progress (e.g. event level or chain step), or add per-area entry quests,
  so veterans also get the unlock arc. Consider capping pad XP per minute.

**M7. Phantom Castle (Lv25 endgame) and the island overall look unfinished:** three towers on an empty floor, a
flat rectangular slab, an empty hub (see Visual).
- Fix: build a real castle silhouette (walls, gate, keep) as the landmark, add height variation (hills,
  stairs, cliffs), cluster props instead of spreading them evenly, and dress the Village plaza.

### Minor
1. **Waddle-home skips progress.** Goobers that "waddle home" after death, reset or shutdown give no Event XP
   and no quest/daily progress: `CarryService.LandPending` doesn't fire `placed` (CarryService.luau:201-211).
   Seen in test 13. Fire the hook with source "belt" there.
2. **Boost stacking** on coin rewards (see Technical). Compute reward coins from the un-boosted rate.
3. **Double discovery** of reward/shop Goobers (BaseService.luau:129 plus EventService.luau:120). Drop the
   second call.
4. Main-world Epic/Legendary toasts appear on the island (Feedback.luau:339-353). Filter classic lines while
   on the island, or make it one small "Plaza" toast.
5. **Thumbnails and silhouettes.** Shop/collection thumbnails show floating eyes while meshes load. Add a
   placeholder or wait for `ContentProvider` before showing. Silhouettes don't darken native eye parts.
6. "QUEST BOARD" sign text is clipped. Gantry odds text wraps.
7. Night `ColorShift_Top` orange washes the ground; Goobers are dark at night. Lower ColorShift and add a
   cool moon light or brighter belt lighting so rarity colours read.
8. Candies are sparkle-lit in the open, not hidden, which doesn't match the "Look behind things!" hint.
9. HalloweenTheme loop seam likely clicks (about 2,150-sample jump at the wrap). Themes are short loops
   (40-48 s).
10. Multi-level event jumps fire N banners and N sounds at once. Merge them into one "EVENT LEVEL x->y".
11. No feedback when a travel tab is pressed during the 4 s cooldown.
12. Comment and code disagree: the Halloween.luau:134 comment says coin rewards have a "min 1000", but the
    code gives at least `seconds*2` (EventService.luau:82).
13. **No event end handling** (`EndsAt` is display-only), and `Enabled=false` doesn't turn off travel, tabs or
    the island.
14. 1,203 collidable precise-collision decor MeshParts on the island. Set small decor to `CanCollide=false`
    or Box.
15. The "Collect 5 minutes of income" daily target is set from the boosted rate if the day rolls during a
    boost (QuestService.luau:76-78).
16. Event panel remembers its tab and scroll position; it reopened scrolled to the bottom of Collection.
    Reset to the top of Track, or to the first claimable card.
17. The "Spooky" tab is shown during the classic tutorial, so new players can teleport away mid-tutorial.
    Consider hiding it until the tutorial is done (the portal guide beam already waits for that).

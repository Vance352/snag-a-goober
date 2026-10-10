# Snag A Goober - Goober Breach overhaul: final report

Date: 2026-10-10. Place 90695592143707. Final commit: `7a2a31f` (all scripts synced to Studio, not yet published).

## Headline

- **Final reviewer score: 7.0 / 10 (round 3).** The target was 8, and it was not reached in the three rounds.
- Round history: 6.0 → 5.5 → 7.0.
- The reviewer's two remaining "major" items from round 3 were fixed afterwards and retested, but **no reviewer has scored that build**:
  1. the leave-refund discount;
  2. teleporting home while carrying.
- What still holds the score down:
  - **Blender models and sound.** The models for the Breach, the Blaster and the Mart stall aren't imported yet, so stand-ins show. The new SFX aren't uploaded. The reviewer put this at 1–1.5 points in three categories.
  - **A few minor UI items** (listed at the end).

## 1. What was implemented

- **Goober Breach** replaces the conveyor belts, which are fully removed in git and in Studio.
- **Goober Blaster** combat: hit a carrier to knock the Goober loose.
- **Global leaderboards**, with physical boards plus an in-game panel.
- **New game pass:** Goober Glam. The other passes were rebalanced for combat.
- **Hub rebuilt:**
  - Breach Arena, Champions Plaza and the east market square.
  - The Goober Mart opens the Shop.
  - Hills, trees and mountains.
- **Halloween Island cauldrons** turned into mini-breaches.
- **Phone layout pass.**
- **New stats** (save v3; old saves migrate): `delivered`, `combatSteals`, `recovered`, `hits`, `stealCredit`.

## 2. Acquisition mechanic and the gameplay loop

**The Breach cycle.** The Breach in the arena runs a 15.5 s cycle:

| Stage | Length |
|---|---|
| Cooldown | 3 s |
| Charging | 8 s (the meter shows the blast type) |
| Unstable | 3 s |
| Blast | 1.5 s |

**Blast types:**
- **SLOP SURGE** – ordinary Goobers.
- **GOLD RUSH** – Gold Goobers, Level 10.
- **RARE RIFT** – luck ×4, announced to everyone.

**How Goobers move:**
- Each blast flings Goobers across the field. Each one's flight and hop plan is a pure function of time (`Shared/Breach.luau`). The client animates it and the server validates snags with the same maths.
- Rare and better Goobers keep hopping, so they have to be chased.
- Unsnagged Goobers dive back in after 38–55 s.
- Personal Drops (half price for their owner) land on your side of the field.

**The loop:** watch the meter → rush the blast → snag (you pay the price) → carry it home, a little slower for rarer Goobers → defend it or get blasted → it earns income on a stand → upgrades, rebirth and leaderboards.

**The island.** Each Halloween Island area has a cauldron that works the same way. Cauldrons rest while nobody is near them.

## 3. Combat rules

**Firing.** Click or Q on PC, R2 on controller, the BLAST button on touch. Touch and controller auto-aim at the nearest carrier.

**What the server checks on every shot:**
- range 14 studs and an aim cone;
- aim within 60° of where you face (re-checked 0.2 s later if your turn hadn't replicated yet);
- line of sight;
- cooldown 1.1 s and a rate limit;
- you have no Goober in your hands;
- lag compensation up to 0.25 s.

**A hit:**
- stuns the carrier for 0.75 s and pushes them 4 studs (server move, wall-checked);
- flings the Goober 11 studs to the side, away from base doorways;
- locks out both the carrier and the shooter for 1 s, after which anyone within 8 studs can grab it.

**Protections:**
- your own base;
- 5 s after spawning;
- 1.5 s after a snag, or until you've carried it 6 studs;
- 4 s after being hit;
- the same attacker on you within 8 s;
- players below Level 3 or still in the tutorial.

**Theft handling:**
- A Goober stolen from a base goes straight home when the thief is blasted.
- Dying drops your Goober. If nobody grabs it in 20 s, it waddles home to you, and its stand stays reserved meanwhile.
- **Leaving** drops it for anyone, with no refund. Server shutdown lands it at home instead.
- Teleporting while carrying pulls you back.
- A combat steal counts toward stats and leaderboards once per 5 min per pair of players. This is saved, so it survives server hops.
- A knocked-loose Goober keeps its paid value for the thief's sell or release (a transfer of loot). The reviewer found no sequence that creates coins or duplicates a Goober.

## 4. Game passes

All seven are live, and their prices match Config (checked by `verifyMarketplace`):

| Pass | ID | R$ | Notes |
|---|---|---|---|
| VIP Club | 2022824311 | 249 | cosmetic |
| Double Slop Coins | 2022452299 | 399 | |
| +4 Goober Stands | 2023412292 | 199 | |
| Sprint Boots | 2022320299 | 99 | **changed:** rests while carrying a Breach Goober and for 3 s after you fire |
| Auto Collect | 2023184287 | 149 | |
| Lucky Goober | 2021996302 | 199 | Personal Drop luck |
| **Goober Glam** | **2026448294** | **149** | **new**, cosmetic: rainbow name and trail, golden Blaster visible to everyone, delivery glitter |

The developer products (Slop Sack, Barrel, Tanker, 2× Income) are unchanged.

No setup is left in the dashboard. No real purchase was made during testing.

## 5. Leaderboards

**Storage.**
- OrderedDataStores: `SAG_LB_v1_<key>` live, `SAG_LB_Studio_v1_<key>` in Studio.
- Writes use UpdateAsync and keep the higher value. They happen at most every 2 min, and also on leave in a separate thread, so the save never waits on them.
- Test players and unsaved sessions never rank.

**Categories:**

| Board | What it counts |
|---|---|
| Top Earners | `totalEarned`: income and rewards. Refunds, compensation and Robux coin packs no longer count; old totals from before this change can't be corrected. |
| Goobers Collected | `delivered` |
| Master Thieves | base steals + credited combat steals |
| Highest Level | level |
| Rare Collectors | distinct Epic, Legendary and Secret Goobers in your Index |

**Display.** The top 10 refreshes every 90 s. It shows on five boards in Champions Plaza and in the TOP panel (GLOBAL / THIS SERVER, plus a "You: #rank" line). The boards show real data, for example Vance at $117M and Level 30.

## 6. Map and assets

**Hub layout:**
- **Breach Arena:** the Breach with rune circles, benches and lamps.
- **Champions Plaza** (west): five large boards, a medal mosaic, and the Rebirth Shrine moved to the side so it doesn't hide a board.
- **East market square:** paths joining the arena, Chaos Rift, Goober Mart and Spooky Portal, with lamps and planters.
- **Surroundings:** grass ground, a ring of hills, tree clusters and distant mountains.

**Blender models waiting for you to import** (`Assets/Exports/SAG_Hub.fbx`; a copy is in `Desktop\Goober Uploads`):
- P_GooberBreach
- P_BreachRing
- P_GooBlaster
- P_MartStall

**Other assets:**
- New icons (crown, breach, blaster, Glam) are uploaded.
- The SFX sprite (`SAG_SFX3.wav`) is waiting for you to upload.

## 7. Key files

**New:**
- `Shared/Breach.luau`, `Shared/Leaderboards.luau`
- `Services/BreachService.luau`, `CombatService.luau`, `LeaderboardService.luau`
- Client: `BreachFx.luau`, `Blaster.luau`, `LeaderboardUI.luau`
- Blender: `hub_props.py`, `export_hub.py`
- Audio: `make_audio_breach.py`

**Modified:**
- Shared: `Config`, `Halloween`
- Services: `Data`, `Carry`, `Character` (now builds the Blaster on the server), `Monetization`, `Steal`, `Session`, `Base`, `Model`, `Main`, `Net`
- Client: `World`, `UI`, `Feedback`, `Effects`, `Guide`, `ClientMain`
- Tools: `MapBuilder`, `IslandBuilder`, `TestHarness`, `process_import`

**Removed:** `ConveyorService`

## 8. Mandatory playtests

All tests ran in real Studio sessions (server plus two or three clients). Full evidence is in `QA/test-log.md`; the reviewer's tables are in `QA/overhaul-review-r1..r3.md`.

| # | Test | Result |
|---|---|---|
| 1 | Acquisition | **PASS.** Cycle timings exact on all 5 sites; snag charges the price; a second snag is ignored |
| 2 | Delivery | **PASS.** Placed on a stand, income, `delivered` +1, Index discovery |
| 3 | Combat | **PASS.** Hit, stagger, exactly 4-stud push, drop, recovery |
| 4 | Counterplay | **PASS.** Equal 1 s lockouts; the drop lands about 11 studs from the carrier and 14–15 from the shooter; never auto-awarded |
| 5 | Race | **PASS.** A same-frame double grab gives one carrier and one model; the loser is told "Too slow" |
| 6 | Disconnect / reset | **PASS.** Death drops; a real `Kick` drops into the field; nothing duplicated; a full base never loses a drop |
| 7 | Safe zones | **PASS.** Own base, spawn, grace, immunity and new-player protections; walls block; facing is checked |
| 8 | Leaderboards | **PASS.** Real OrderedDataStore rows on the boards and in the panel; saved stats |
| 9 | Game passes | **Partial.** All IDs live with matching prices; ownership detected on the real account (Glam shows OWNED); Glam and Sprint Boots effects applied through the grant path. **No real purchase flow was run.** |
| 10 | Mobile combat | **Partial.** Layout measured at 750×381 (58 px inset): BLAST is 73 px and clear of jump; the nav clears the thumbstick to within about 1 px. **Not tested on a real touch device.** |
| 11 | Map inspection | **PASS** by screenshots in Edit mode and on clients. The stand-ins for the Blender props are still visible. |
| 12 | Halloween regression | **PASS.** Portal, island travel, cauldrons, candy, quests, Event XP |
| 13 | Original game | **PASS.** Cash Pad, income, upgrades, base theft by holding E, Rebirth panel |
| 14 | Console | **PASS.** Server and clients clean; the only errors came from probe scripts |

## 9. Known issues, limitations, not tested

**Pending on you:**
- Import `SAG_Hub.fbx`. After the import I need to run `process_import`, check moderation, and rebuild the map.
- Upload `SAG_SFX3.wav`, then set `Config.Audio.Sprite3`.
- Upload the Halloween thumbnail.
- **Save → Publish.** Nothing above is live until you do.

**Minor items from round 3, still open:**
- On phones the HUD covers part of the plaza boards.
- The phone nav sits about 1 px into the thumbstick zone.
- Old Top Earners totals still include past refunds.

**Behaviour change to know about:** players who disconnect while carrying lose that Goober to the field, with no refund. A death works the same way.

**Not tested:**
- real network latency (lag compensation, how often shots take the delayed check);
- real touch input;
- more than three players;
- a real server shutdown;
- a real rejoin;
- frame rate on a device;
- live purchases.

## 10. Reviewer scores

| # | Category | R1 | R2 | **R3 (final)** |
|---|---|---|---|---|
| 1 | Breach acquisition | 7.0 | 7.5 | **8.0** |
| 2 | Blaster combat | 5.5 | 7.0 | **7.0** |
| 3 | Map and polish | 5.5 | 6.5 | **7.0** |
| 4 | Leaderboards | 6.0 | 7.0 | **7.5** |
| 5 | Game passes and shop | 6.5 | 7.0 | **7.5** |
| 6 | UI/UX and mobile | 6.5 | 7.0 | **7.0** |
| 7 | Security and multiplayer | 6.0 | 4.0 | **6.5** |
| 8 | Performance and release | 6.5 | 5.5 | **6.5** |
| | **Overall** | **6.0** | **5.5** | **7.0** |

**Round 3 verdict:**
- Not ready to publish until its two major items were fixed. Both have since been fixed and retested by me, but not re-reviewed.
- Then do the pending imports and upload, and retest a real kick, a teleport while carrying and one blast race.
- The reviewer expected about +0.5 overall once the models and sounds are in.

# Snag A Goober - final handoff report (updated 2026-10-09 morning)

**Status: PASSED the independent release audit in round 15 - 8.08 / 10** (pass mark 8.0), no critical defects, every category >= 7.5. Rounds 1-14 (overnight, Studio not rendering, one client) scored 5.40-7.73 and failed; round 15 was scored with Studio rendering, phone emulation (750x381, touch) and a live two-player session, after this morning's mobile HUD fix and two-player theft tests. The experience is still **Private** until Vance publishes. Report: `QA/round15-audit.md`.

## 1. Name and project location
- **Snag A Goober**, Roblox PlaceId 90695592143707 / GameId 10769928826 (owner cooolvance55).
- Repo: `C:\Users\vance\snag-a-goober` -> github.com/Vance352/snag-a-goober (branch `main`).
- `src/` mirrors the Studio script tree (30 scripts). `tools/` holds the Studio sync, import and simulator tools. `Assets/` holds Blender sources, exports, audio and store art. `QA/` holds every audit report, the test log and the release checklist.

## 2. State of the playable experience
The full loop works in a single-player Studio playtest (verified every round):
- join, get a base, follow the tutorial;
- snag a Goober off the conveyor, carry it home, auto-place it;
- income, the Cash Pad, upgrades, levels;
- the Dex, the Gold Line at Lv 10, rebirth, Chaos events, and the store.

Save -> stop -> start restores progress identically. The console shows no script errors across 14 rounds of fuzzing (300-1,000 malformed remote calls per round). Not yet seen rendered on a phone, and not re-run with two players since the overnight anti-cheat work.

## 3. Systems and features
**Gameplay**
- Two conveyor lines (Main, Gold) with time-based belt motion.
- 25 Goobers in 7 rarities, plus Personal Drops (45 s, half price).
- Personal bases: up to 28 stands, Cash Pad, Lock pad, Slop-O-Matic upgrade console, unlockable decor.
- Upgrades: Zoomies (speed), Income, Stands, Lock.
- XP and levels with level rewards; rebirth with multiplier and a confirm step (server requires an explicit flag).
- Goober-dex with milestone rewards.
- GOOBER CHAOS events.

**Stealing**
- Level gate, new-player safety, base lock, steal protection, cooldowns.
- Server-timed steal hold; the owner tags the thief to catch them; compensation for the victim.
- Thieves move slower while carrying.

**Anti-cheat (MoveGuard)**
- Server-authoritative "could you have walked here?" checks on snags, steals and carries.
- Debt that freezes trust until the player has walked it off.
- Lag-stall tolerance.
- A carry floor from the carry's original start, so no carry finishes sooner than walking.

**Platform and data**
- 4-step first-minute tutorial with Skip.
- Mobile-first scaled UI.
- Original synthesized audio (SFX sprite + music).
- Session-locked, versioned DataStore saves with migrations, sanitising and retries.
- Monetization: 6 gamepasses, 4 developer products (idempotent receipts), Lucky odds disclosure, PolicyService gating.
- Studio-only test harness.

## 4. Original Blender models
All are made in code from primitives (`Assets/BlenderSource/scripts`), not downloaded:
- **25 Goober characters**, one per Dex entry.
- **12 props:** belt segment, Chaos Rift, flag, Goober Gusher, lamp post, mushroom tree, rebirth shrine, slop barrel, Slop-O-Matic, Slop Vat, stand, trophy.
- **226 meshes imported.** 216 were approved; the 10 "Eye" meshes were auto-rejected by moderation. Eyes and pupils are now native Parts built from Blender specs, and no rejected mesh is referenced.
- In the live place: 25 Goober templates (132 MeshParts) and 12 prop templates (51 MeshParts); about 1,700-1,850 MeshParts in Workspace.

## 5. Blender source and exports
- Editable source: `Assets/BlenderSource/SAG_AllAssets.blend` and the scripts `goober_lib.py`, `goobers.py`, `environment.py`, `renders.py`.
- Exports: `Assets/Exports/SAG_AllAssets.fbx`, plus one FBX per asset in `Assets/Exports/Goobers` (25) and `Assets/Exports/Props` (12).
- Metadata: `Assets/AssetDocumentation/palette.json` and `native_parts.json`.
- Store art: `Assets/StorePage` (icon + 5 thumbnails, 1920x1080).

## 6. Blender -> Roblox pipeline
See `Assets/AssetDocumentation/pipeline.md`:
1. Build in Blender by script.
2. Export FBX (forward -Z, up Y; mapping verified Blender (x, y, z) -> Roblox (-x, z, y)).
3. Import manually with Studio's 3D importer (it can't be scripted).
4. Run `tools/process_import.luau`. It colours the parts, builds the Root/Pivot/Anim skeleton, makes the native eyes, and writes the templates.
5. `MapBuilder` places the props.
6. Check mesh moderation through the Assets API after every import.

## 7. What was tested in Roblox Studio
Every QA round ran real Studio playtests against the live place. Tests:
- the core loop;
- tutorial steps;
- income and Cash Pad;
- upgrades and their effects;
- levels and rebirth;
- the Dex;
- pass revoke/grant (free-player values);
- remote fuzzing;
- save -> stop -> start;
- raw DataStore reads;
- the movement guard.

The guard was tested two ways:
- **Live:** client-driven teleports, speed hacks, simulated lag stalls, spoofed stalls.
- **Simulation:** fake-clock simulations of the real MoveGuard. The builder's `tools/guard_sim.luau` and the auditors' own harnesses ran thousands of trials. These are labelled as simulations.

Overnight, Studio was not rendering, so client visuals were frozen and screenshots timed out. Visual, layout and phone checks are therefore unverified.

## 8. Multiplayer results
- **Earlier session (2-3 real clients, Studio local server):** six theft paths passed (`QA/test-log.md`, 2026-10-08), along with plot reuse and theft-exploit retests through round 4.
- **After that:** the theft cancel/re-time rules were reworked repeatedly overnight and are **only code-reviewed or emulated, not tested with two real players**.
- Never tested: 8-player load (largest test was 3 clients).

## 9. Save/load results
- Verified every round: save, stop, start restores identical Goober uids, level, rebirths, upgrades, passes and base models.
- Raw DataStore reads match.
- A sale made right before stopping the server persisted.
- Migration and sanitising were tested through harness commands.
- Session locking and retries were code-reviewed.

## 10. Monetization results
- Every round, `verifyMarketplace` confirmed all 6 passes and 4 products are live, with prices matching Config.
- Simulated receipts sent twice granted once (idempotent).
- Revoking each pass removes exactly its benefit, and re-granting restores it.
- The Lucky pass shows odds before purchase and is hidden where paid random items are restricted (code-reviewed).

## 11. Marketplace-testing limits
- Studio can't make real Robux purchases. Receipts were simulated, and no real purchase was made.
- The creator account owns every pass automatically.
- The real purchase prompt UI and live receipt delivery are unverified.

## 12. Gamepasses (configured and live)
| Pass | Price (R$) | ID |
|---|---:|---|
| VIP Club | 249 | 2022824311 |
| Double Slop Coins | 399 | 2022452299 |
| +4 Goober Stands | 199 | 2023412292 |
| Sprint Boots | 99 | 2022320299 |
| Auto Collect | 149 | 2023184287 |
| Lucky Goober | 199 | 2021996302 |

## 13. Developer products (configured and live)
| Product | Price (R$) | ID |
|---|---:|---|
| Slop Sack | 25 | 3717345239 |
| Slop Barrel | 99 | 3717345325 |
| Slop Tanker | 299 | 3717345363 |
| 2x Income (15 min) | 49 | 3717345400 |

## 14-15. Final independent scores (round 15, build 931d510) - PASS
| Category (weight) | Score |
|---|---:|
| Functional correctness and reliability (20%) | 8.5 |
| Core loop simplicity and enjoyment (15%) | 8 |
| Replayability and progression (15%) | 8 |
| Visual, Blender, animation, audio (10%) | 8 |
| UI/UX and mobile (10%) | 8 |
| Multiplayer, networking, performance (10%) | 7.5 |
| Data, economy, exploit resistance (10%) | 8 |
| Monetization and compliance (5%) | 8.5 |
| Onboarding / first minute (5%) | 8 |
| **Weighted total** | **8.08 / 10 - PASS** |

Previous final (round 14, build 80cf75b, overnight):
| Category (weight) | Score |
|---|---:|
| Functional correctness and reliability (20%) | 8 |
| Core loop simplicity and enjoyment (15%) | 7.5 |
| Replayability and progression (15%) | 7.5 |
| Visual, Blender, animation, audio (10%) | 7.5 |
| UI/UX and mobile (10%) | 7.5 |
| Multiplayer, networking, performance (10%) | 7 |
| Data, economy, exploit resistance (10%) | 7.5 |
| Monetization and compliance (5%) | 8 |
| Onboarding / first minute (5%) | 7.5 |
| **Weighted total** | **7.58 / 10 - FAIL** (pass needs 8.0) |

The two small doc and dead-code fixes made after round 14 (`MoveGuard` header, unused `STALL_MAX`, checklist wording) were not re-audited.

## 16. QA rounds completed: 15
Each round was a fresh, separate auditor following `.claude/agents/independent-release-auditor.md`.

Scores by round:

| Round | Score |
|---:|---:|
| R1 | 5.40 |
| R2 | 6.60 |
| R3 | 7.00 |
| R4 | 6.95 |
| R5 | 7.28 |
| R6 | 7.03 |
| R7 | 7.33 |
| R8 | 7.38 |
| R9 | 7.58 |
| R10 | 7.68 |
| R11 | 7.68 |
| R12 | 7.73 |
| R13 | 7.38 |
| R14 | 7.58 |
| R15 | **8.08 PASS** |

Every report is in `QA/`. The builder's retest evidence for each round is in `QA/test-log.md`.

## 17. Major issues found and fixed (by theme)
**Movement exploits** (most rounds). Each was fixed and then retested by the auditor:
- teleport-snag/steal;
- teleport-home theft;
- hover/fly;
- speed hacks;
- reset-to-skip-the-walk;
- respawn grace;
- multi-hop and hop-and-back teleports;
- debt forgiveness trusting any spot;
- spoofed-idle teleport (round 13 critical, fixed in round 14).

The final MoveGuard:
- checks every position against every real sample in a 20 s window (newest real sample never dropped);
- skips network-stall samples for at most 5 s;
- re-arms a stall only after movement;
- floors carries from their original start.

**Lag false positives** (rounds 4-12), where legit players were refused or thefts cancelled during lag:
- iterated to stall detection with catch-up handling;
- validated with deterministic simulations against old and new builds.

**Data:**
- Saves first failed to persist (BindableEvents deep-copy tables), fixed with callbacks;
- release retries;
- sanitising that keeps `paid`;
- over-capacity Goobers stop earning.

**Economy:**
- sell refunds and stolen value use what was actually paid (no laundering);
- steal XP limited per victim;
- compensation cooldown.

**Monetization honesty:**
- the VIP chat tag was implemented;
- the Lucky pass copy was corrected, with odds shown;
- pass grants are only trusted from server-issued prompts.

**UI and mobile:**
- touch targets, label fit, panel sizing, close buttons;
- tutorial hints that fit, Skip size;
- hint/status overlap;
- chat placement.

**Moderation:** the rejected eye meshes were replaced by native parts.

## 18. Remaining bugs, risks and unverified features
- **UNVERIFIED:**
  - all two-player paths since the overnight changes (live theft, catch, cancel vs re-time, victim UI, leaving mid-theft);
  - phone layout and the rendered look;
  - first-minute onboarding on a fresh profile;
  - 8-player load;
  - real audibility;
  - real purchases;
  - real-network lag behaviour.
- **Known anti-cheat trade-offs** (documented in `RELEASE_CHECKLIST.md`):
  - stalls of up to ~3 s including the catch-up are forgiven;
  - longer or clustered stalls, and stalls where the server sees zero velocity, can cancel a legit theft;
  - a cheater faking a stall can appear up to ~120 studs (~5 s of walking) from their last confirmed spot, once per movement;
  - a constant slack of about 8% over walking speed.
- **Store page:**
  - the public thumbnails API lists only 1-2 thumbnails, with the same image hash;
  - the maturity questionnaire is not done;
  - the experience is not public.
- Characters walking straight into the belt frames need to jump to cross between the lines (minor).

## 19. Manual actions still required (Vance)
1. **Save + Publish in Studio.** Studio holds the synced script changes; they are in git too, but players only get published code.
2. Check that all 5 thumbnails and the icon are approved and distinct on the Creator Hub.
3. Complete the Maturity & Compliance questionnaire.
4. Run a **two-player test** (Studio Test -> Clients and Servers with 2 players, or a private server): a steal, a catch, a steal reaching home, and a thief leaving mid-steal.
5. Watch the game **rendered** and on **Test -> Device** (phone landscape).
6. Then run one more QA round. Those two checks are what can lift the capped categories.

## 20. Steps to publish safely
1. Do the manual actions above.
2. Fix anything the 2-player and rendered checks reveal, then re-audit.
3. File -> Save to Roblox, then File -> Publish to Roblox.
4. Optional: turn HTTP Requests off (runtime doesn't use them).
5. Creator Hub -> Audience -> Public.
6. Don't buy ads to compensate. Watch the first sessions and the error report before promoting.

Full checklist: `QA/RELEASE_CHECKLIST.md`.

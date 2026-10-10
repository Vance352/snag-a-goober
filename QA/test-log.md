# Snag A Goober - builder test log

Evidence from real Roblox Studio sessions (place 90695592143707). "Harness" =
Studio-only `ServerStorage.SAG_Test` (src/ServerScriptService/Testing/TestHarness.luau).

## 2026-10-10 - Review round 1 fixes, two-player retest (Studio server + 2 clients)

Player1 (-1), Player2 (-2), Lv 10 / tutorial done. New harness helpers: `get`, `tpLook`, `char`.

| Check | Result |
|---|---|
| Blaster visible to others | PASS - server builds GooBlaster on both characters; Player1's client sees Player2's |
| Snag grace | PASS - blast 0.3 s after snag refused while the carrier hadn't moved; after the carrier moved 7 studs a blast 0.28 s after the snag hit |
| Drop race | PASS - hit at 6 studs: Goober landed (-54.5, -13.1), 10.8 studs from the carrier and 13.8 from the shooter; shooter "recoiling", carrier "dizzy" for 1 s; shooter at 13 studs told "Get closer" (8-stud drop range) |
| Pair steal credit | PASS - first combat steal +1; same pair again 10 s later: delivered +1, combatSteals unchanged |
| Leave mid-carry | PASS - real `Carry.OnRemoving`: Goober dropped in the field, refund $25 of $50, delivered unchanged, no carry; re-grabbing as the leaver charged the $25 back |
| Full base + drop | PASS - drop kept its stand (16 used with drop), base filled to 18/18 -> new snag refused "Your base is full!"; drop expired and waddled home (17 -> 18 Goobers), nothing lost |
| Facing check | PASS - shooter facing away with aim at the carrier: no hit; facing them: hit |
| Sprint Boots rest | PASS - WalkSpeed 21.5 -> 17.5 right after firing -> 21.5 after 3 s |
| Death drop | PASS - Health 0 while carrying: Goober dropped (dropBy, paidBy set), stand still reserved |
| "Too slow" | PASS - second snagger told "Too slow - Player2 grabbed it!" |
| Island cauldrons idle | PASS - all four stay in Cooldown with nobody there (0 island Goobers); Player1 in the Pumpkin Patch: Charging -> Unstable -> Blast, 4 Goobers |
| Goober Mart | PASS - E at the stall opens the Shop |
| Champions Plaza | PASS - client screenshot: all five boards visible from the entrance, shrine to the side |
| Leaderboard panel | PASS - short tabs, "You: $59.7M  •  not in the top 10 yet" (test player never ranks) |
| Console | Clean on server and client (one error came from a probe script) |

## 2026-10-10 - Goober Breach + Goober Blaster, two-player tests (Studio server + 2 clients)

Player1 (-1), Player2 (-2), both set to Lv 10 / tutorial done. Session started by Claude through Studio's Test menu
(Server and Clients + Add Clients x2). Harness `call` runs the real handlers the remotes reach.

| # | Brief test | Result |
|---|---|---|
| 1 | Breach blast -> snag -> carry | PASS - every site cycles Charging/Unstable/Blast; 18 Goobers on the field after one cycle (Central 5 + drop, cauldrons 4/3/3/2); snag removes it from the field, second snag ignored |
| 2 | Delivery | PASS - carried home, placed, `delivered` +1 (solo test earlier) |
| 3 | Combat hit | PASS - blast inside the 1.5 s snag grace refused ("They only just grabbed it!"); real hit: HitConfirm / GotBlasted, carrier staggered (WalkSpeed 0), pushed exactly 4 studs, Goober dropped beside them |
| 4 | Counterplay / not auto-awarded | PASS - the hit carrier is "dizzy" for 1.2 s, then anyone can grab; the attacker had to walk over and grab it (free), victim told "grabbed your Goober" and later "got it home"; attacker `combatSteals` +1 only on delivery; carrier re-grabbing their own drop counts as `recovered` |
| 5 | Race | PASS - both players grabbed the same dropped Goober in the same frame: exactly one carrier, one model |
| 6 | Disconnects / resets | PASS - dying drops the Goober where you fell (no reset escape); unclaimed drops waddle home to the dropper; dropper leaving removes it from the field (it lands home before the save); carrier leaving leaves no model or duplicate behind |
| 7 | Safe zones / limits | PASS - out of range (22 studs), through a leaderboard board, just-hit immunity, shooter carrying, shooter below Lv 3, target 1 stud outside their own base, target within spawn protection: all refused with a reason |
| - | Console (server) | Clean |

Not covered here: real touch input (Studio-emulated only), saving of the leaving players' Goobers (Studio test players don't persist - checked in a solo session instead).

## 2026-10-09 - Halloween update, two-player theft tests (Studio server + 2 clients)

Players: Player1 (-1), Player2 (-2), build after review round 3 (6bd5743 + badge/daily-copy fixes). Session started
from Studio's Test > Start Test Session > Server and Clients (+ Add Clients x2). Harness `call` runs the real handlers.

| # | Test | Result |
|---|---|---|
| A | P1 steals P2's Hex (Rare Halloween), carries it home | PASS - Hex moves to P1 (new record), P2 gets StealAlert, StolenFrom with $1,250 (25%) insurance and 120 s shield; P1 Halloween Index 1/16; no Event XP for a stolen Goober (belt only, by design) |
| B | P1, carrying the stolen Hex, at the Spooky Portal: PortalIn, then the Island shortcut | PASS - "You can't escape through the portal with a stolen Goober!" and "shortcuts only work with empty hands"; P1 stays on the mainland |
| C | P1 on Halloween Island; P2 starts stealing P1's Hex; P1 uses the Base shortcut and tags P2 | PASS - P1 gets the alert on the island, the shortcut lands P1 at their base instantly, Caught / CaughtThief fire, Hex stays with P1 |
| D | P1 steals P2's Lantern Lurker (Epic Halloween) and is kicked mid-carry | PASS - Goober back on P2's stand with the same uid, nothing in transit, no carried models left, P2 gets StealFailed |
| - | Console (server) | Clean |

## 2026-10-09 - Halloween update, builder playtests (Studio, solo client)

Player cooolvance55 (Vance's Studio account). Harness `call` runs the real service
function the remote would reach; the client-side items were driven in the client.

| # | Brief test | How | Result |
|---|---|---|---|
| 1 | New player / portal | Reset Halloween data; Travel PortalIn from 30 studs, then from 4 studs | PASS - 30 studs refused; 4 studs lands at the island arrival, quest 1 done, intro opens (3 pages, Skip/Next; IntroSeen saved) |
| 2 | Exploration + candy | Stood next to C01, C02 (client auto-pickup); CollectCandy C30 from far away; bucket B1 twice | PASS - both found (+10 candy, +20 Event XP each), far claim ignored, bucket +4 then "refills in 4:59" |
| 3 | Goober collection | Snagged Pumpkin Pip off the Pumpkin Patch belt, carried it through the return portal, home | PASS - placed on a stand, Halloween discovery 1/16, chain quest 2 + daily "8 Goobers" advanced, +15 Event XP |
| 4 | Level progression | setLevel 5 -> walked into Haunted Forest; setLevel 8 -> again; ClaimLevel 3 twice, ClaimLevel 10 at Lv 8 | PASS - Lv 5 moved back to the gate with "unlocks at Level 8"; Lv 8 enters (AreaEnter), client barrier opens only for the Forest; Lv 3 reward once, Lv 10 refused |
| 5 | Event rewards | ClaimTrack 1, 1 again, 2, 3 (not reached), "1", 1.5; Candy Shop Pumpkin Pip, Hex (can't afford), bogus key | PASS - each reward once, coins scale with income, wrong types ignored, shop charges 60, refuses Hex/bogus |
| 6 | Saving | Saved, read the DataStore record, stopped and restarted the session | PASS - candy, event level/claims, candies found, quests, intro flag, v2 all persisted and reloaded |
| 7 | Teleportation | Died on the island; Travel shortcuts Island/Base; travel while carrying | PASS - respawn at base, day lighting back (after fixing a tween bug), shortcuts work, portals carry belt Goobers |
| 8 | Audio | Island<->Base with two distinct track ids (stand-in id, real tracks not uploaded yet); Music off/on | PASS (logic) - 2.2 s crossfade both ways, never two tracks at full volume, off silences both. Real tracks: pending upload |
| 9 | Mobile UI | Root forced to a 750x381 phone layout (UIScale 0.762), HUD + Event + Quests panels | PASS after fixes - labels wrapped mid-word (min text size) and nav ran close to the thumbstick; fixed |
| 10 | Regression | Classic Slop Line snag -> home, Auto Collect, Zoomies upgrade, console | PASS - all normal, console clean. Stealing (2 players) still to run |

Bugs found and fixed while testing: camera spawning inside the portal (arrivals moved out, camera turned after travel);
night lighting stuck after leaving the island (tween goal held a non-property key); track/milestone coin rewards showed
build-time amounts; bucket cooldowns reset on rejoin (now saved); Classic Index milestones counted Halloween Goobers.

## 2026-10-08 - two-player theft tests (Studio local server, 2-3 real clients)

Players: Player1 (-1, base 1), Player2 (-2, base 2), later Player3 (-3, base 2 reused).

| # | Test | How | Result |
|---|---|---|---|
| 1 | Placement protection | Thief forced StealHold+Steal remotes on a Goober placed <45 s ago | PASS - client prompt hidden; server: "That Goober was just placed and is protected." |
| 2 | Successful theft | Real keyboard hold E (1.5 s) on Steal prompt, thief walked home, victim far away | PASS - Captain Spork moved P1->P2, P1 got $375 (25%) insurance + 120 s shield, P2 60 s cooldown, Dex discovery, banners both sides |
| 3 | Thief caught | P1 stole from P2, owner P2 walked into thief | PASS - Goober back on stand, thief 90 s cooldown, stun then speed restored (13.6 -> 16), caught stat |
| 4 | Base lock | P2 stepped on Lock pad, P1 tried to steal | PASS - intruder ejected 6 studs outside entrance, prompt disabled, server rejected (no valid in-range hold) |
| 5 | Thief disconnects mid-theft | Server kicked thief while carrying | PASS - Goober returned to victim (same uid), thief save has only legit Goobers, lock released |
| 6 | Victim disconnects mid-theft | Server kicked victim while thief carried | PASS - thief carry cancelled ("owner left"), thief gained nothing, victim save still holds the Goober (same uid), no stray models |
| - | Pair cooldown | Repeat thief on same victim within 5 min | PASS - "You already hit this base. Try again in 0:56." |
| - | Plot reuse | Player2 left, Player3 joined | PASS - got base 2, no leftover models, sign "Player3's Base" |

## 2026-10-08 - single-player checks

- Teleport-snag exploit (client sets HRP CFrame near far belt Goober, waits for replication, fires Snag): rejected "Whoa, slow down!" (MoveGuard).
- Legit snag by walking + walk home: placed normally.
- Auto Collect pass: +22 XP in 10 s, tutorial Collect step advanced.
- Save -> stop -> rejoin: Goobers, coins, level, upgrades, tutorial, dex restored.
- Receipt replay (same PurchaseId twice): granted once.
- Marketplace: all 10 ids live, names/prices match Config.
- Audio on a client: music loaded (34.29 s, playing), SFX sprite loaded (15.05 s), 15 Sounds; audible quality not verifiable by the builder.

## Moderation check (2026-10-08)
Assets API moderation state for all 239 uploaded assets: 226 meshes (216 Approved,
10 Rejected - all "Eye" meshes), 11 images Approved, 2 audio Approved. Eye meshes
replaced with native parts; no rejected asset is referenced in the place.

## 2026-10-08 - after QA round 2
- Server size: Roblox games API `games.roblox.com/v1/games?universeIds=10769928826` returns `maxPlayers: 8` (Studio local test sessions report their own default of 60).
- Experience description set (games API returns it). Lucky pass description now states the exact example (18% -> 24.8%), verified by hand: rare+ weight 18 x 1.5 = 27 of 109 = 24.77%.
- ServerStorage.RawImport removed from the place (re-import the FBX to reprocess).

## 2026-10-08 - builder retest of round-2 exploits (new 2-client session, build 85e5891)
| Test | Result |
|---|---|
| Teleport-home theft (real hold E, wait 3.2 s, one HRP CFrame write ~45 studs into own base) | BLOCKED - carry cancelled "no shortcuts!", victim keeps Fluffernaut |
| Hover-glide theft (+11 studs, 12 st/s straight line through walls) | BLOCKED within 1.1 s, victim keeps Snorkel |
| Legit belt carry walked home | PASS - Gumbo placed |
| Steal prompt during pair cooldown | hidden on client until cooldown ended (208 s) |
| Legit theft (real hold E, walked home) | PASS - Mushy transferred, Dex discovery |

## 2026-10-08 - builder retest of round-3 exploits (2-client session, build 8f3f851)
| Exploit (auditor round 3) | Result |
|---|---|
| Teleport 55 studs to belt, wait 3.4 s, snag | snag allowed at 3.4 s = same time as walking (debt model works; tightened afterwards so teleporting is strictly slower: d/(speed*1.1)+1.5 s) |
| Teleport 48 studs into victim base, wait 3.3 s, steal | allowed at ~walking time (tightened as above) |
| Carry stolen Goober at 20 st/s along an open path | CANCELLED after 1.5 s ("no shortcuts!"), victim keeps Disco Dan |
| Snag then reset (Health = 0) immediately | "waddling home on its own (2s)", landed ~2 s later, not instantly |
| Reset after carrying for minutes | placed immediately (walk time already elapsed) - correct |
| Chat window on desktop | ChatWindowConfiguration Left/Bottom (off the HUD menu) |

## 2026-10-09 - builder retest of round-4 findings (single-player Studio Play, build after round-4 fixes)
The 2-client session could not be restarted overnight (needs the owner), so two-player paths were not re-run this time.
| Test | Result |
|---|---|
| Reset, then teleport 50 studs to the belt during the old 4 s respawn grace, snag x14 | BLOCKED - every attempt "Whoa, slow down!" (respawn now anchors at the server spawn; no grace) |
| Legit walk to belt + snag | PASS |
| Carry home by CFrame at 20.7 st/s after standing still 1.5 s (server WalkSpeed 16) | CAUGHT - "No shortcuts!", placed after 5.1 s vs ~1.5 s legit |
| Same at server WalkSpeed 20 (Sprint Boots owned) | not flagged - correct (within 5% of real speed) |
| Legit MoveTo carry at 16 | PASS, placed 1.7 s, no warning |
| Single 15-stud bump then snag | first snag succeeds at 0.6 s (was ~6 s lockout) |

## 2026-10-09 - builder retest of round-5 findings (single-player Studio Play)
Two-player paths not re-run (2-client session needs the owner present).
| Test | Result |
|---|---|
| Two-hop teleport (hop to belt, then hop again) and snag | BLOCKED - no snag within 16 s vs a 10.2 s walk; every refusal "Whoa, slow down!" |
| Carry with a 0.5 s client freeze + catch-up (simulated hitch) | PASS - placed at 1.6 s (clean walk 1.2 s), no "No shortcuts" (MIN_AGE 0.6) |
| Reset, wait 1.2 s, teleport next to belt (spawn ~2 s walk away), snag | snag at 3.4 s after spawn >= 2.0 s walk; earlier tries "Whoa, slow down!" |
| Reset, teleport repeatedly beside the farthest belt Goober (90-140 studs), snag x13 | first success 7.8 s after spawn vs 6.9 s legit walk - never faster than walking |
| Legit Humanoid:MoveTo carry home from that far spot (WalkSpeed 20) | PASS - placed after 6.1 s, no warning |
| Console | no script errors |

## 2026-10-09 - builder retest of round-6 findings (single-player Studio Play)
Note: Studio was not rendering overnight (viewport 1x1, RenderStepped 0/s), so client belt visuals were frozen; tests use the
belt's analytic position (same formula as the server). Two-player paths not re-run.
| Test | Result |
|---|---|
| C1 hop-and-back (25-stud hop, back, teleport 147-199 studs to belt, snag spam) | BLOCKED - 3 runs no snag within 12 s; with a 0.5 s replication wait, first plausible reply 6.0-6.1 s after a 147-stud teleport (walk 7.3 s) |
| Plain teleport 147 studs after standing 2.5 s | plausible after 5.2 s vs 7.3 s walk (stated budget: up to ~2 s of credit after standing still) |
| Sustained speed 1.0x / 1.15x / 1.25x for 9 s | not flagged (within the ~2 s gain budget) |
| Sustained 1.36x / 2.0x | caught at 6.2 s / 2.6 s, then held in debt until walked off |
| Walking with 0.5 / 1.0 / 1.0 / 1.5 / 1.5 s client freeze + catch-up | PASS all, 0 refusals in 12 probes each (round 6: 1.0 s gave ~6 s of refusals) |
| Legit Humanoid carries (2 short, 1 99-stud long, 1 via entrance) | PASS, no warnings |
| Carry with 1.0 s freeze + catch-up | PASS, placed 3.1 s, no warning |
| Teleport home while carrying | "No shortcuts!" and placement held to walking time |
| 1.5x carry away from home | caught ("No shortcuts!") |
| 1.5x carry straight home | placed ~2.4 s server-side vs 2.6 s straight walk (MinTravelTime floor, tightened to d/(1.05 v) - 0.1) |
| Tutorial Skip | 112x54 design px (about 84x40 at phone scale 0.75; auditor's 57x26 was the 0.62 floor scale on a 1x1 viewport) |
| Console | no script errors |

## 2026-10-09 - builder retest of round-7 findings (single-player Studio Play, Studio not rendering)
Verified first: the server sees a walking Humanoid's replicated velocity (~20 st/s), and a stalled client as a frozen
position with walking velocity - the pattern the lag bank now requires. Two-player theft paths not re-run (CODE-REVIEWED).
| Test | Result |
|---|---|
| Stall 0.5 / 1.0 / 1.5 s (position frozen, velocity kept) + catch-up, then walking | PASS - 0 refusals in 12 probes each |
| Freeze 1.0 s with velocity 0 (not a real stall pattern) | 2 refusals (~1 s), then fine |
| Stand 2.5 s, teleport 38 studs, snag | plausible only after 2.0 s (walk 1.9 s) - no gain (round 7: snag 0.43 s) |
| Sustained 1.2x / 1.3x / 1.5x | caught at 6.2 s / 3.6 s / 2.1 s (round 7: 1.3x passed 8.1 s) |
| Hold off-map 30 s (debt forgiveness), then teleport 120 studs | server returned the character to its last trusted spot at 30.5 s; teleport refused (Whoa x6) |
| Hop-and-back then teleport 147 studs | plausible after 6.5 s (walk 7.3 s) |
| Legit Humanoid carries (short, 70 studs out) | PASS, no warnings |
| Teleport home while carrying (belt) | warning, placed at 4.0 s = walk time |
| Theft teleport home | CODE-REVIEWED: excess > 10 studs during a theft calls Fail("teleport") immediately; hovering too |
| Console | no script errors |
State: sold 6 cheap Goobers (Toastie x2, Sir Puddle, Gumbo x3) to free base space for carry tests.

## 2026-10-09 - builder retest of round-8 findings (single-player Studio Play, Studio not rendering)
| Test | Result |
|---|---|
| Theft + smooth 3x move home | CODE-REVIEWED: any MoveGuard violation during a stolen carry (debt entry or CarryStep failure) now calls Fail("teleport") - no re-time path left |
| Faked stall (pinned, velocity 20) 1.8 s + 45-stud hop | plausible 0.45 s after the hop = 2.25 s total = walking time (time-neutral; once per 10 s) |
| Hop chain 5 x (1.75 s faked stall + 48-stud hop) | 242 studs plausible only after 12.6 s vs 12.1 s walk (round 8: 9.45 s) |
| Real-stall pattern 0.5 / 1.0 / 1.5 s while walking | PASS, 0 refusals in 12 probes each |
| Tutorial hints (all 6 texts) at 0.62 scale | TextFits = true for every one |
| Legit 70-stud carry | PASS, no warnings |
| Teleport home while carrying (belt) | warning, placed at 4.1 s (walk 4.0 s) |
| Console | no script errors |

## 2026-10-09 - builder retest of round-9 findings (single-player Studio Play, Studio not rendering)
| Test | Result |
|---|---|
| Walking with stalls: 1.0 s; 1.5 s; two 1.0 s 3.5 s apart; 1.5 s + 1.0 s 5 s apart; three 0.8 s | PASS - 0 refusals in 18 probes each (round 9: repeated stalls flagged) |
| Faked stall with velocity sideways + 45-stud hop | plausible 1.75 s after the hop (walk 2.25 s) - no stall credit |
| Faked stall with velocity aimed at the hop + 45-stud hop | 0.47 s after the hop = 2.27 s incl. the stall (time-neutral; documented residual) |
| Hop chain 5 x (1.75 s faked stall aimed at the hop + 48-stud hop) | 244 studs plausible after 11.1 s vs 12.2 s walk (~1.1x = slack bound) |
| Sustained 1.2x / 1.3x / 1.5x | caught at 6.2 / 3.6 / 2.1 s |
| Rebirth remote fired without the confirm flag (x2) | ignored, rebirths 0 -> 0 |
| Theft: lag-sized flag vs shortcut | CODE-REVIEWED: excess > 10 studs, flying, or a violation lasting > 1 s cancels; a brief flag re-times from the last trusted spot |
| Legit 70-stud carry | PASS, no warnings |
| Console | no script errors |
State: one Blorp (paid 10) sold to return the base to 21 Goobers after test carries.

## 2026-10-09 - builder retest of round-10 findings (single-player Studio Play, Studio not rendering)
MoveGuard lag handling redesigned: no credit bank. Frozen "stall" samples (stationary, straight out of walking pace,
walking velocity, <= 3 s) and the catch-up samples in the 1 s after them are not used as constraints; the real
samples before the stall bound everything to walking speed over a 20 s window. Tests in an open lane (z = -27):
stall tests next to plot walls were invalid (client physics zeroed the velocity at the wall).
| Test | Result |
|---|---|
| Stalls (velocity kept): 1.0 s, 1.5 s, 2.0 s, two 1.0 s 3.5 s apart, 1.5 s + 1.0 s, three 0.8 s | 0 refusals in nearly every run; a few runs (mostly the first after Play start) had the server never see walking velocity during the simulated stall - a limit of simulating a stall by pinning the client, since a real stall keeps the last velocity |
| Walk-in + spoofed stall 1.8 s + 40-stud hop | plausible 0.57 s after the hop = 2.4 s incl. stall vs 2.0 s walk (no gain) |
| Spoofed velocity while standing (no walk-in), or a 6 s "stall" | no credit (plausible ~1.6 s after a 40-stud hop) |
| Hop chains 5 x (walk 0.5 s or 1.2 s, spoofed stall 1.75 s, 48-stud hop) | plausible only at walking time: 14.8 s vs 14.7 s, 18.1 s vs 18.3 s |
| Sustained 1.2x / 1.3x / 1.5x | caught at 4.7 / 3.1 / 1.6 s |
| Theft cancel rule | CODE-REVIEWED: Offence gets the current excess every tick (debt re-measured with ping slack); cancels at > 10 studs, flying, or 8 s out of range; lag-sized flags re-time |
| ExtraSlots revoked with 21 Goobers | capacity 18; Goobers on stands 19-21 stop earning (3372 -> 3234/s), re-grant restores 3372 |
| Legit 70-stud carry | PASS, no warnings |
| Console | no script errors |
State: sold one Toastie (paid 30) to return the base to 21 after a test carry.

## 2026-10-09 - builder retest of round-11 findings (single-player Studio Play, Studio not rendering)
| Test | Result |
|---|---|
| Auditor repro: walk 1.5 s, stall 1.0 s, walk 0.6 s, stall 1.5 s (open lane z=-27) | 0 refusals, twice (round 11: +17 studs -> theft cancel) |
| Stalls 1.0 s + 1.0 s, 0.5 s apart | 0 refusals |
| Hop chains 5 x (walk 0.5 / 1.2 s, spoofed stall 1.75 s, 48-stud hop) | plausible only at 14.5 s vs 14.7 s walk, 17.6 s vs 18.2 s walk |
| 1.15x CFrame carry home from the belt | placed at 2.38 s = the d/(1.05 v) floor from the carry's original start (plot edge ~53 studs; honest 2.65 s) |
| Legit 70-stud carry | PASS, no warnings |
| Shutdown save: sell a Goober, stop play immediately, restart | the sale persisted (21 Goobers, sold uid gone) |
| Console | no script errors |
State: one Blorp (paid 10) and one Pebble Pete sold. CORRECTION (found by audit 12): the base ended at 22, not 21 - the 1.15x test carry placed one more Goober after the last sale.

## 2026-10-09 - builder retest of round-12 findings (single-player Studio Play + deterministic simulator)
New tool: `tools/guard_sim.luau` runs the real MoveGuard module (fake clock) against a simulated network: lag 0.3 s,
stalls in which the server copy freezes, 1-3 catch-up bursts, jittered server ticks, theft cancel rules. Validated
against the previous build dd0ba30, where it reproduces the auditor's failures (single 1.5 s stall: 15% cancels at
speed 29.75, 5% at 26; three-stall cluster: 20% at 20, 32% at 26).
| Scenario (simulator, 100-150 trials per cell) | dd0ba30 | this build |
|---|---|---|
| Single 1.0 / 1.5 / 2.5 s stall, thief speeds 13.6-29.75, ticks 0.10-0.12 s | up to 15% cancel | 0% (0 flags) |
| 1.0 s + 1.5 s stalls 0.6 s apart, all speeds | - | 0% |
| Three stalls (1.0, 1.5, 2.0 s; 0.6/0.5 s apart), all speeds | 20-32% cancel | 0% |
| Single 1.5 s, ticks 0.10-0.20 s; three stalls, ticks 0.10-0.35 s | - | 0% |
| 1.5 s stall with velocity 0, simulator pretending ReceiveAge grows (CORRECTION, audit 13: ReceiveAge does not grow in Studio, so this row is not evidence about real networks) | - | 0% |
| 1.5 s stall with velocity 0 AND no ReceiveAge growth (no stall cue at all) | - | 27-70% cancel |
Live (open lane z=-27): three-stall cluster 0/0 refusals; a stall at the very start of walking (round 12 m1) 0; single 2.0 s 0.
Exploits live: stand + spoofed stall 2 s + 40-stud hop -> plausible 2.58 s after the spoof began (walk 2.0 s); hop chains
5 x (spoofed stall 1.75 s + 48-stud hop) -> ~1.14x over 10-13 s (the 1.08x free-roam slack + constants; carries also have
the 1.05x original-start floor); 1.2x caught at 6.2 s, 1.5x at 1.6 s.
BasePart.ReceiveAge is readable but hovered at 0.08-0.13 s while walking and did not grow when idle, so it is probably
not a reliable stall signal; it is kept as a secondary cue (worst case it skips constraints, which is time-neutral).

## 2026-10-09 - builder fix of round-13 C1 (spoofed idle -> teleport) + retest
Cause: stalls re-armed every 3 s while standing still and the 20 s prune then dropped the last real sample, leaving
nothing to bound a hop. Fix: the newest real sample is never pruned; stall + catch-up may skip at most 5 s past it
(STALL_BUDGET); a new stall needs movement since the last one; catch-up window 0.6 s.
tools/guard_sim.luau: ReceiveAge now behaves as measured live (does not grow) unless a test opts in; exploit mode
(spoofed idle then hop, must be flagged); pcall + guaranteed cleanup of its temporary floor.
| Test | Result |
|---|---|
| LIVE auditor C1 repro: pinned at (-190,3,-27) spoofing velocity 20 for 22 s, hop 286 studs, Snag x4 | "Whoa, slow down!" x4 |
| Sim exploit: spoofed idle 22 s + hop 256 / 7 s + 140 / 6 s + 110 / 10 s + 150 (speeds 20, 29.75) | flagged 100% |
| Sim legit: single 1.0 / 1.5 / 2.5 s stalls, speeds 13.6-29.75 | 0% cancel, 0 flags |
| Sim legit: stall pair 1.0 s + 1.5 s, 0.6 s apart | 0% |
| Sim legit: single 1.5 s with ticks 0.10-0.35 s | 0% |
| Sim legit: single 1.5 s with 0.6 s lag | 0 cancels (43/100 brief flags at speed 29.75) |
| Sim legit: three stalls (1.0, 1.5, 2.0 s) inside ~6 s | ~50% cancel - KNOWN LIMIT (exceeds the 5 s budget) |
| Sim: velocity 0 during a stall (no stall cue) | still cancels - KNOWN LIMIT |
| LIVE legit (lane z=-27): single 1.5 s, single 2.5 s, pair, stall at walk start | 0 refusals each |
| LIVE speed hack 1.2x / 1.5x | caught at 5.2 s / 2.6 s |
| Console | no script errors |
Inherent trade-off (documented): while a client appears stalled, the server can't know where it is, so a cheater who
fakes the stall pattern can appear anywhere within ~5 s of walking (~100 studs at speed 20) of their last confirmed
spot, once per movement; never further, never chained.

## 2026-10-09 (morning) - TWO-PLAYER theft tests (Studio Test, 1 server + 2 clients, latest server code)
Server confirmed running the latest MoveGuard (STALL_BUDGET 5.0, no STALL_MAX). The client HUD in this session was the
previous layout (session not restarted after the mobile HUD change). Player1 = id -1 (plot 1), Player2 = id -2 (plot 2).
Movement driven by Humanoid:MoveTo from each client's own window; steals through the real StealHold/Steal remotes.
| Test | Result |
|---|---|
| Catch: P2 steals P1's Fluffernaut while P1 stands at his spawn (inside 7-stud catch radius) | P2 "Caught" 1.1 s after StealStart; P1 got StealAlert + CaughtThief; Goober back on P1's stand at its original spot, owner P1; P2 got nothing, ~70 s cooldown |
| Successful theft: P2 away at the belt; P1 steals P2's Disco Dan (paid 3000) and walks home | placed after a 4.3 s carry (StealSuccess); P2 lost the record and model; P1 got a new record paid=1500 (half, no laundering); P2 compensated exactly +750 (25%) and base auto-locked 120 s; P2 saw StealAlert + StolenFrom |
| Teleport-home cheat: P2 steals P1's Captain Spork, then pins his HRP at his own spawn | cancelled 0.2 s after the teleport ("The Goober slipped away - no shortcuts!"); Spork back on P1's stand |
| Lag stall mid-theft: P1 (fast thief, carry speed 26.35) steals P2's Snorkel; 1.0 s stall (frozen position, walking velocity) + catch-up halfway home | theft completed normally (StealSuccess), no warning |
| Thief leaves mid-steal: P2 steals the Spork, server kicks P2 while carrying | P1 keeps it (record + 1 model, back on its stand, StealFailed note); P2's saved profile: 12 Goobers, no Spork (no duplication), session lock released |
Cooldowns respected between tests (pair 300 s, thief 60 s); one attempt was silently ignored while the owner was also
using Player1's window. Not covered: victim leaving mid-theft, 3+ players, the lock pad / eject during a theft.

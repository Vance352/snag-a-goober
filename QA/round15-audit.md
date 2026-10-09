# Independent Release Audit - Round 15
Place verified: PlaceId 90695592143707 / GameId 10769928826 "Snag A Goober". I checked this on the Edit window 99449037, the server 65751cce, and both clients: d88a0a5a is Player1 (UserId -1) and 0a7f850a is Player2 (UserId -2). Both clients run at 750x381 with TouchEnabled true. A fifth Studio entry, 90532793, has no place open, so I left it alone.   Build: 931d510 (main HEAD; git clean before and after)

**Script sync:**
- All 30 Edit-mode scripts match `src/*.luau` on byte length and Adler-32 after CRLF normalisation. For example, UI is 41556 bytes / 2107225864 and MoveGuard is 16970 / 3099972610.
- The running server's copies of all game scripts have the same hashes.
- Player2's client UI module also matches (41556 / 2107225864).
- So the live session is running 931d510, including the top-left HUD.
- The server log shows a fresh start: only the "ready" lines, no script errors.

**Method:**
- Rendered screenshots of both phone clients.
- Taps sent as mouse clicks, which the emulator turns into touches. I measured the mapping: screen = GUI + (62, 20).
- Real keyboard E holds on the Steal and Snag prompts.
- Legitimate walking with `Humanoid:MoveTo` from each client.
- Harness `state`, `notes` and `guard` to observe the server.
- Note: the `character_navigation` tool teleports (MoveGuard flagged "+10 studs"). I used it only once per player at the start, before any test.

## Scores
| Category | Score | Why (evidence refs) |
|---|---|---|
| Functional correctness and reliability | 8.5 | **Successful theft, live** (P2 stole P1's Toastie `89f7a678`, paid 30):<br>- StealStart, then StealSuccess.<br>- P1 went 18 to 17 Goobers; P2 got `d0b154a3` with paid=15 (half).<br>- P1 got exactly +7 (25%) and a 120 s shield ("Locked 1:47" pill); plot1 Locked=true.<br>- P2 got a 60 s thief cooldown and a 300 s pair cooldown.<br>**Catch, live** (P1 stole P2's Gumbo `7850709d`, P2 walked up):<br>- Caught after the walk; Gumbo back on stand 8 at (-44, -62.5).<br>- P1 got a 90 s cooldown, a stun (WalkSpeed 0, back to 31), and caught +1.<br>**Teleport home during a theft:** "Careful!", then "slipped away - no shortcuts!", and Pebble Pete was back on stand 13.<br>**Tutorial flow on the phone:** snag, home, collect, upgrade, tips, then 99.<br>**Save + readStore** match the live state.<br>No script errors on the server or either client. |
| Simplicity/enjoyment of core loop | 8 | Seen rendered. Snag a $10 Blorp, carry it overhead ("Carrying Blorp - bring it home!" with a DROP button), placed after a 4.4 s walk, Cash Pad collect, $50 Zoomies. The steal/catch drama reads clearly on both screens (THIEF! / CAUGHT! / GOT 'EM!). |
| Replayability, progression, motivation | 8 | Seen live: Goober Chaos events (Chaos Rift, Slop Storm, Golden Hour schedule), a "SECRET SPOTTED!" spawn, Personal Drops at 50% off, Dex 13/25 with the next reward shown, the rebirth panel with resets/keeps/gains, upgrade levels. Long-term pacing UNVERIFIED. |
| Visual quality, Blender models, animation, audio | 8 | **Rendered:** distinct Blender Goobers (Snorkel, Mushy, Octo Goob, Toastie, Gumbo, Blorp, Nugget, Moai), about 2-4.4 studs tall; Dex thumbnails render; themed base, belt, signs and sparkle effects.<br>**Audio:** 14 SFX plus music loaded on the client; music is playing (34.3 s track).<br>**Against:** in-world label pile-ups (m3); Goobers read small from a distance. Real audibility UNVERIFIED. |
| UI/UX and mobile usability | 8 | **At 750x381, UIScale 0.762:**<br>- Coins and level sit top-left (6,5, 163x40).<br>- Menu buttons are 64x64; Settings 46x46; close buttons 55x46; upgrade buttons 130x46.<br>- Menu bottom is y 218; the thumbstick starts at y 230 (12 px clear). Jump (655,233) and the status column don't collide.<br>- All 5 panels and Odds open and close by tap; bodies scroll.<br>**Against:** m1 and m2. |
| Multiplayer, networking, performance | 7.5 | **Server:** 60 Hz, 2,474 parts, about 1.7 MB Lua.<br>**Client:** 89 of 307 BillboardGuis enabled; all have MaxDistance limits.<br>Two-player paths verified live (above).<br>The lag trade-off (R14 m1/m2) is unchanged; real-network stall behaviour is still untested. RenderStepped was 15/s in both windows (likely Studio throttling unfocused windows), so client FPS is UNVERIFIED. |
| Data persistence, economy security, exploit resistance | 8 | **Live StealHold spoof:** P1 faked an 8 s idle (pinned, velocity -31), then hopped 55 studs next to P2's Toastie and fired StealHold+Steal. The guard flagged "move +20 studs"; no hold was recorded and no StealStart was sent.<br>**Server cooldown:** Steal during cooldown gave "Steal cooldown: 66s".<br>**Fuzz:** malformed StealHold/Steal (nil, table, 100-char string, NaN, another player's uid) gave no errors.<br>Paid price halves on theft (no laundering). Save and readStore are consistent. The in-budget ~120-stud "fog" is still there by design. |
| Monetization accuracy and platform compliance | 8.5 | `verifyMarketplace`: all 6 passes and 4 products are live; prices match Config and the shop as displayed (399/149/199/199/99/249; 25/99/299/49).<br>Odds modal on the phone: Personal Drop Rare+ is 18%, With Lucky is 24.8%; it matches the pass description. Coin packs show the exact amount.<br>The players are not the creator, so passes=[]: the free experience was what I observed. |
| New-player onboarding and first minute | 8 | I replayed the tutorial (tutorial=0 on P2) on the phone:<br>- The hint pill with Skip sits at the top centre and doesn't collide with anything.<br>- Steps advance on real events (snag, place, Cash Pad, upgrade, "YOU'RE A GOOBER BOSS!" tips banner, then 99 automatically).<br>- Chaos and Secret banners compete with the hints (m2).<br>A fresh Lv1 / $0 profile's first 60 s was not observed (it would need a wipe): UNVERIFIED. |

Weighted total: **8.08 / 10** (8.5×.20 + 8×.15 + 8×.15 + 8×.10 + 8×.10 + 7.5×.10 + 8×.10 + 8.5×.05 + 8×.05 = 8.075)

## Critical defects (block release)
None found.

## Major issues
**M1. Store presence is incomplete** (owner-side; not scored against the build).
- Improved since round 14: `games.roblox.com/v1/games?universeIds=10769928826` now returns the name "Snag A Goober", isContentRestricted false and maxPlayers 8.
- Still missing: the thumbnails API lists only 1 Completed thumbnail (`e436f6cf…`); the checklist expects 5.

## Minor issues
**m1. Transient full-width banners overlap the Settings button on phones.**
- The Banner TextLabel spans x 139-611, y 100-152. SettingsBtn is x 146-192, y 84-130.
- Seen in screenshots with "SECRET SPOTTED!", "YOU'RE A GOOBER BOSS!", "GOOBER CHAOS: CHAOS RIFT!", "THIEF!" and "CAUGHT!".

**m2. Phone panel polish.**
- The Rebirth panel's action button (y 265-308) is clipped by the panel bottom (y 300).
- The Lucky Goober description is TextScaled down to 8 px (TextFits=false), though all of it is shown.
- The next-unlock line is about 10.7 px.
- The Shop shows only about 2 cards per screen; its canvas is 867 px against a 209 px window.
- Closing Odds Info also closes the Shop, instead of returning to it.
- Tutorial hints compete with Chaos/Secret banners in the same area.

**m3. World label clutter.**
- Belt and stand BillboardGuis stack on top of each other and on the player tag. Example from the belt screenshot: "YOUR PERSONAL DROP / COMMON Nugget $35 (50% OFF)" overlapping "COMMON Nugget +4/s" and "UNCOMMON Bean Boi".

**m4. The Steal prompt says "Steal!" when the thief's base is full.**
- `stealPromptState` (World.luau:169-197) doesn't check for free stands.
- The player holds for the full 1.2 s and only then gets "Your base is full!".
- Seen live: P1 had 18/18 and held E on P2's Gumbo.

**m5. Lag trade-off unchanged** (R14 m1/m2). Severe or clustered stalls and velocity-zero stalls can cancel thefts. Real-network behaviour is untested. The checklist now states this accurately.

**m6. Simulator gap unchanged** (R14 m5). `tools/guard_sim.luau` still doesn't assert the in-budget hop bound.

## Retest of previous round's findings
- **R14 M1 (store/public): PARTIALLY FIXED.** The title is available and the game isn't content-restricted. Only 1 of 5 thumbnails.
- **R14 m1 (5 s stall budget regresses severe-lag tolerance): NOT FIXED.** No MoveGuard logic change. Documented accurately at RELEASE_CHECKLIST.md:32.
- **R14 m2 (velocity-zero stalls): NOT FIXED** (known limit).
- **R14 m3 (docs/dead code): FIXED.** In the 40a5492 diff the MoveGuard header now says 5 s and `STALL_MAX` is removed; the checklist now says ~3 s / ~120 studs.
- **R14 m4 (constant slack): NOT FIXED** (by design).
- **R14 m5 (sim in-budget assertion): NOT FIXED** (tools unchanged).
- **R14 UNVERIFIED items now VERIFIED:** two-player theft, catch, cooldowns, victim UI, teleport-home cancel, spoofed stall against StealHold, the phone layout, and rendered visuals.
- **Builder claims in test-log 2026-10-09 (morning):**
  - Catch, successful theft (half paid, 25% compensation, shield) and teleport-home cancel: independently reproduced.
  - Lag-stall mid-theft and thief leaving mid-steal: not re-run (leaving needs a kick, which the session rules forbid).

## Verified / Code-reviewed / Unverified
- **VERIFIED:**
  - Place id; 30/30 script sync, Edit and running server; client UI hash.
  - Rendered base, belt, Goobers and Dex.
  - Phone HUD geometry and touch-control clearance; all panels plus Odds opened and closed by tap.
  - Live successful theft with both screens; live catch with both screens.
  - Server cooldown and pair-cooldown prompts ("Steal in 4:38", "Base locked").
  - Teleport-home theft cancel; spoofed-idle hop to StealHold refused; steal-remote fuzz.
  - Tutorial steps 0 to 99 on the phone.
  - Snag, carry, place, collect and upgrade.
  - Save and readStore; marketplace ids and prices; sounds loaded and music playing.
  - Server perf stats; clean consoles.
- **CODE-REVIEWED:**
  - The 931d510 UI diff (HUD move).
  - StealService (CanSteal, HoldBegan, Request, Fail, Offence, succeed, tick loop).
  - BaseService Place, RemoveRecord, Sell.
  - Conveyor/Carry paid-price handling.
  - TestHarness.
- **UNVERIFIED:**
  - A fresh-profile first minute (would need a wipe).
  - Victim or thief leaving mid-theft this round (needs a kick).
  - Real-network lag; client FPS on real phones; actual audibility; 3-8 player load.
  - Real purchases (none made); the maturity questionnaire.

## Decision: PASS
All gates are met:
- Weighted total 8.08 ≥ 8.0, and no category is below 7 (lowest is Multiplayer at 7.5).
- No open critical functional, security, data-loss, ownership or purchase defect.
- The core loop was verified live and rendered.
- The Blender Goobers and props are integrated and look acceptable in the rendered game.
- Major advertised features work: stealing, catching, events, Dex, upgrades, shop and odds.
- This is round 15.

Caveats:
- It is a narrow pass.
- The game reaches players only after the owner does Save -> Publish, and the remaining thumbnails should be approved.

## Top 5 fixes that would raise the score most
1. **m1/m2: give phone banners and panels their own space.**
   - Move or shrink the Banner so it clears x < 200, or anchor it below y 140.
   - Make the Rebirth body scroll or shrink so its button isn't clipped.
   - Give the Lucky description a minimum readable size (≥ 11 px), or shorten it.
   - Have Odds' close button return to the Shop.
2. **m4:** hide or relabel the Steal prompt ("Base full") when the thief has no free stand.
3. **m3:** de-clutter the world labels. Shorter belt tags, MaxDistance under 25 for stand tags, or show only the nearest few.
4. **m5/m6:** smarter stall budget (per round 14's suggestion) plus sim assertions; and one real weak-Wi-Fi phone test in a published private server.
5. **Owner:** approve all 5 thumbnails, finish the store page, then Save and Publish. Do a fresh-account first-minute check on a real phone.

## State changes made during this audit
- **Session:** I didn't stop the session, kick anyone or close windows. The main window is still in **Edit**. No code, map, Assets or Creator Hub changes; git is clean at 931d510.
- **Theft test** (P2 stole P1's Toastie `89f7a678`), reversed:
  - P2 sold the stolen `d0b154a3` (+7) and I set P2's coins −7.
  - The harness `place` gave P1 a new Toastie `9b2c8b42` (paid 30, stand 9 as before). I set P1's coins −7.
  - Stats reset: P1 stolenFrom 6, caught 2; P2 steals 6, sold 1. P2's xp −25 (steal XP).
  - Dex G03_Toastie set back to 2 for both.
  - Rates are back to 5880.6 / 643.
- **The catch** (P1 caught) and the **teleport-home theft** needed nothing restored beyond P1's caught count; both Goobers went back to their stands automatically.
- **Tutorial replay on P2:** I set tutorial=0; it finished at 99. Then:
  - Sold the snagged Blorp `52fd6213`.
  - Coins +55 (snag 10 − refund 5 + upgrade 50).
  - upgrades.Speed back to 0.
  - snags 10, sold 1, dex Blorp 1, xp 418.
  - `revokePass("DoubleCoins")` on a pass P2 doesn't own, only to re-apply WalkSpeed 16.
- **Left as is (my walking caused them; total wealth unchanged):**
  - Both players stepped on their Cash Pads during the walks, moving bank into coins. P1 coins are 10.41M (was 4.71M plus 2.52M bank, plus accrual); P2 coins are 31.99M.
  - That also gave collect XP: P1 616 (was 566), P2 468 (was 418).
- **Other harness calls:** `save` for both players; `clearNotes`.
- **Runtime only:** steal cooldowns expire on their own.
- **Plugin-VM helpers** (`_G.walk`, input loggers, `_G.AUD`) are cleared. The Shop scroll position is reset.
- **Positions:** P1 is back near its spawn (-91, -86); P2 is at its spawn (-28, -58).
- **Purchases:** no real purchases, no PromptPass or PromptProduct, no `Rebirth(true)`.

# Snag A Goober - release checklist (for Vance's approval)

The game stays **Private** until you approve this list. Nothing here costs money.

## Already done
- [x] Experience: name "Snag A Goober", description, server size 8 (games API confirms `maxPlayers: 8`).
- [x] Icon + 5 thumbnails uploaded (by Vance, 2026-10-08). The public thumbnails API listed only 1-2 of them overnight, so check that all 5 show (see below).
- [x] Genre Simulation / Tycoon (by Vance).
- [x] 6 gamepasses + 4 developer products live, prices match the in-game store (verifyMarketplace, re-checked every QA round).
- [x] Original audio uploaded and approved; all meshes in use are moderation-approved (10 rejected Eye meshes replaced by native parts).
- [x] Studio API access on (DataStores).
- [x] 15 independent QA rounds (reports in `QA/`). **Round 15 PASSED: 8.08 / 10** (pass = 8.0), no critical defects, lowest category 7.5 - scored with Studio rendering, phone emulation and a live 2-player session. Rounds 1-14 failed (best 7.73).

## Before going public
- [ ] **Save + Publish in Studio**: File -> Save to Roblox, then File -> Publish to Roblox. Studio has many unsaved script changes from overnight (all also in git); players only get published code.
- [ ] Check the icon and **all 5** thumbnails show as approved on the Creator Hub (Places -> Icon / Thumbnails).
- [ ] Complete the **Maturity & Compliance questionnaire** (Creator Hub -> Experience -> Questionnaire). Expected answers: no violence beyond cartoon "tagging", no blood, no romance, no gambling for real value. The Lucky Goober pass is a *probability modifier* (paid random item rules): odds are shown in-game before purchase and it is hidden where PolicyService restricts paid random items.
- [ ] Optional: turn off **HTTP Requests** in Game Settings -> Security (the game doesn't use HttpService at runtime; only Studio tooling did).
- [x] 2-player check in Studio (Clients and Servers, 2 players): catch, successful theft, teleport-home cancel, lag stall mid-theft, thief leaving mid-steal (builder, 2026-10-09 morning) - catch / success / teleport cancel / spoofed-idle StealHold re-verified by the round-15 auditor.
- [ ] Optional: one more 2-player run in a **published private server** on a real phone (real network lag is still untested).
- [x] Rendered game + phone layout (Test -> Device, 750x381 touch) checked by the round-15 auditor; coins/level moved to the top-left first.
- [ ] Optional: play once on a phone on weak Wi-Fi and check you don't get stuck with "Whoa, slow down!" or "No shortcuts!".
- [ ] Set Audience -> **Public** when happy.

## Polish the round-15 auditor suggested (not blocking)
- Big banners (e.g. "SECRET SPOTTED!") briefly cover the Settings button on phones; the Rebirth button is slightly clipped by its panel on phones; the Lucky pass text is tiny; closing Odds also closes the Shop.
- World name tags pile up over belts/stands.
- The Steal prompt says "Steal!" even when your own base is full (you only find out after holding).

## Known limitations (honest)
- Mobile layout checked in code (UIScale, text fit at the smallest scale), not yet on a device or the device emulator.
- 8-player load not tested (largest test: 3 clients in a Studio local server).
- Sound quality unheard by the builder (files load and play; synthesized originals).
- Studio cannot simulate real Robux purchases; receipts were tested with simulated receipts (idempotency verified).
- Anti-cheat lag tolerance is a deliberate trade-off (measured by the round-14 auditor): network stalls (frozen position with walking velocity) of up to ~3 s including the catch-up never cancel a theft; 4 s stalls cancel ~15-25%, 4.5 s ~50%, 5.5 s always; three long stalls inside ~6 s cancel 34-82%; a stall in which the server sees zero velocity can cancel too. In exchange, a cheater who fakes the stall pattern can appear at most ~120 studs (~5 s of walking) from their last confirmed spot, once per movement, never chained (a 22 s fake idle + 286-stud hop, and a wiggle-chain, are refused). Speed hacks of 1.2x+ are caught within ~5 s. Real-network lag behaviour is untested.

# Snag A Goober - release checklist (for Vance's approval)

The game stays **Private** until you approve this list. Nothing here costs money.

## Already done
- [x] Experience: name "Snag A Goober", description, server size 8 (games API confirms `maxPlayers: 8`).
- [x] Icon + 5 thumbnails uploaded (by Vance, 2026-10-08). The public thumbnails API listed only 1-2 of them overnight, so check that all 5 show (see below).
- [x] Genre Simulation / Tycoon (by Vance).
- [x] 6 gamepasses + 4 developer products live, prices match the in-game store (verifyMarketplace, re-checked every QA round).
- [x] Original audio uploaded and approved; all meshes in use are moderation-approved (10 rejected Eye meshes replaced by native parts).
- [x] Studio API access on (DataStores).
- [x] 10 independent QA rounds (reports in `QA/`). Rounds 9 and 10 found no critical defects and no category below 7; every round so far failed only on the overall score (best 7.68 of the 8.0 needed). See "Why it isn't at 8.0 yet".

## Before going public
- [ ] **Save + Publish in Studio**: File -> Save to Roblox, then File -> Publish to Roblox. Studio has many unsaved script changes from overnight (all also in git); players only get published code.
- [ ] Check the icon and **all 5** thumbnails show as approved on the Creator Hub (Places -> Icon / Thumbnails).
- [ ] Complete the **Maturity & Compliance questionnaire** (Creator Hub -> Experience -> Questionnaire). Expected answers: no violence beyond cartoon "tagging", no blood, no romance, no gambling for real value. The Lucky Goober pass is a *probability modifier* (paid random item rules): odds are shown in-game before purchase and it is hidden where PolicyService restricts paid random items.
- [ ] Optional: turn off **HTTP Requests** in Game Settings -> Security (the game doesn't use HttpService at runtime; only Studio tooling did).
- [ ] **2-player check** in a published private server (or Studio Test -> Clients and Servers with 2 players): one player steals from the other's base, the owner tags the thief, one steal reaches home, and one thief leaves mid-steal. None of the steal changes made overnight could be tested with two players.
- [ ] Watch the game **rendered once** (Studio was not drawing overnight, so the auditor couldn't score the visuals): belt Goobers moving, base, shop, and the phone layout via Test -> Device (e.g. iPhone 14 landscape).
- [ ] Optional: play once on a phone on weak Wi-Fi and check you don't get stuck with "Whoa, slow down!" or "No shortcuts!".
- [ ] Set Audience -> **Public** when happy.

## Why it isn't at 8.0 yet
The auditor scores what it can see. With Studio not rendering and only one test client, visuals, mobile layout, onboarding and every two-player path stay "UNVERIFIED" and hold those categories at 7-7.5. The two checks above (2-player and rendered/phone) are what's needed to raise them. Then run one more QA round.

## Known limitations (honest)
- Mobile layout checked in code (UIScale, text fit at the smallest scale), not yet on a device or the device emulator.
- 8-player load not tested (largest test: 3 clients in a Studio local server).
- Sound quality unheard by the builder (files load and play; synthesized originals).
- Studio cannot simulate real Robux purchases; receipts were tested with simulated receipts (idempotency verified).
- Anti-cheat tolerance is deliberate: a lag stall of up to ~3 s is forgiven, and a cheater faking that pattern can at best match walking speed (measured: hop chains take as long as walking, speed hacks of 1.2x+ are caught within ~5 s). Real-network lag behaviour is untested.

# Snag A Goober - release checklist (for Vance's approval)

The game stays **Private** until you approve this list. Nothing here costs money.

## Already done
- [x] Experience: name "Snag A Goober", description, server size 8 (games API confirms `maxPlayers: 8`).
- [x] Icon + 5 thumbnails uploaded (by Vance, 2026-10-08) - wait for Roblox moderation to clear.
- [x] Genre Simulation / Tycoon (by Vance).
- [x] 6 gamepasses + 4 developer products live, prices match the in-game store (verifyMarketplace).
- [x] Original audio uploaded and approved; all meshes in use are moderation-approved (10 rejected Eye meshes replaced by native parts).
- [x] Studio API access on (DataStores).

## Before going public
- [ ] **Save + Publish in Studio**: File -> Save to Roblox, then File -> Publish to Roblox. (Players only get code that has been published.)
- [ ] Check the icon and thumbnails show as approved on the Creator Hub (Places -> Icon / Thumbnails).
- [ ] Complete the **Maturity & Compliance questionnaire** (Creator Hub -> Experience -> Questionnaire). Expected answers: no violence beyond cartoon "tagging", no blood, no romance, no gambling for real value. The Lucky Goober pass is a *probability modifier* (paid random item rules): odds are shown in-game before purchase and it is hidden where PolicyService restricts paid random items.
- [ ] Optional: turn off **HTTP Requests** in Game Settings -> Security (the game doesn't use HttpService at runtime; it was only used by Studio tooling).
- [ ] Do a final 2-player check in a **published private server** (Studio can't fully emulate live DataStores/JobIds).
- [ ] Set Audience -> **Public** when happy.

## Known limitations (honest)
- Mobile layout verified by code/UIScale and Studio only, not on a physical phone.
- 8-player load not tested (largest test: 3 clients in a Studio local server).
- Sound quality is unheard by the builder (files load and play; synthesized originals).
- Studio cannot simulate real Robux purchases; receipts were tested with simulated receipts (idempotency verified).

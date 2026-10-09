# Independent Release Audit - Round 1 (build 9793680)

Auditor: separate subagent following `.claude/agents/independent-release-auditor.md`
(run as a general-purpose subagent because Claude Code loads new agent
definitions only at session start).

| Category | Weight | Score |
|---|---:|---:|
| Functional correctness and reliability | 20% | 6 |
| Simplicity and enjoyment of the core loop | 15% | 5 |
| Replayability, progression, motivation | 15% | 6 |
| Visual quality, Blender models, animation, audio | 10% | 2 |
| UI/UX and mobile | 10% | 6 |
| Multiplayer, networking, performance | 10% | 5 |
| Data persistence, economy security, exploit resistance | 10% | 6 |
| Monetization accuracy and compliance | 5% | 6 |
| New-player onboarding | 5% | 7 |
| **Weighted total** | | **5.40 - FAIL** |

## Findings and builder response

| ID | Finding | Builder fix (commit) |
|---|---|---|
| C1 | Blender assets not integrated (fallback spheres) | Owner imported FBX; process_import built 37 templates; map rebuilt (f269095) |
| C2 | Game silent (no sound ids) | Original SFX sprite + music uploaded by owner, wired via PlaybackRegions (f269095) |
| C3 | Client-authoritative movement: teleport-snag works, instant steal possible | MoveGuard plausibility checks, server-timed steal hold, min carry/travel time (23482f4) |
| C4 | Stealing never run with two players | 6 two-player theft tests in a Studio local server - see QA/test-log.md |
| M1 | Auto Collect removes collect XP and soft-locks tutorial | XP every 10 s from auto income + tutorial advance (23482f4) |
| M2 | Server size 60 vs 8 plots | Max visitors set to 8 on the Creator Hub |
| M3 | Final save had no retry | 4 attempts with backoff on release (23482f4) |
| M4 | Pass granted without re-check | Must match a server prompt, else UserOwnsGamePassAsync (23482f4) |
| m1 | "A The Golden Nugget" banner | Fixed |
| m2 | Audio toggles while silent | Toggles show N/A without audio; audio now present |
| m3 | Personal drops often unaffordable | Personal drops are 50% off for their owner |
| m4 | Level reward outgrows XP cost (snag-release farm) | XP on placement; reward 15*L^1.5 |
| m5 | Plot released before final save | Safety-net release removed |
| m6 | Small touch targets | Reference 900x500, bigger Skip/Settings |
| m7 | Lucky "+50%" wording | Reworded in Config and on the Creator Hub |
| m8 | Stud-scaled tags fill screen | Pixel-size BillboardGuis, shorter range |
| m9 | Character stuck at entrance lip | Entrance ramp |
| m10 | Alt collusion mints insurance coins | Insurance at most once per 10 min per victim |

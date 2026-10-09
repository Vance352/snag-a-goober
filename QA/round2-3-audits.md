# Independent Release Audits - Rounds 2 and 3

Each round was a fresh separate auditor subagent following
`.claude/agents/independent-release-auditor.md`, testing the live Studio place and
a Studio local-server session with two real clients.

## Round 2 (build 2bffcdb) - 6.60 / 10 - FAIL

| Category | Score |
|---|---:|
| Functional | 7 |
| Core loop | 7 |
| Replayability | 7 |
| Visual/Blender/audio | 7 |
| UI/mobile | 7 |
| Multiplayer/perf | 7 |
| Data/economy/exploits | 4 |
| Monetization | 5 |
| Onboarding | 7 |

Key findings → fixes (commit 85e5891): C1 teleport-home theft → per-tick
CarryStep; M1 hover/fly theft → hover check + horizontal catch; M2 speed → tighter
slack using slowed thief speed; M3 VIP "chat tag" missing → implemented; M4 server
size → verified 8 via games API; m1-m13 (prompts, XP floor, Lucky wording, pair
cooldown UX, tips timing, ejection height, close X, RawImport, belt facing, lock on
early leave, Auto Collect bank) → fixed.

## Round 3 (build 6f93088) - 7.00 / 10 - FAIL (no critical defects)

| Category | Score |
|---|---:|
| Functional | 7.5 |
| Core loop | 7 |
| Replayability | 7.5 |
| Visual/Blender/audio | 7 |
| UI/mobile | 6.5 |
| Multiplayer/perf | 7 |
| Data/economy/exploits | 5 |
| Monetization | 8 |
| Onboarding | 7.5 |

Key findings → fixes (this commit):
- M1 teleport-in then out-run (20 st/s), M2 teleport/wait/snag → MoveGuard rewritten
  with a trust-anchor "debt" model: after an implausible jump the player is treated
  as still walking from the last trusted spot; snag, StealHold and Steal refused
  until the walk would have been possible. Carry speed checked over 1.2 s against
  the server's own (slowed) WalkSpeed with 12% slack + ping slack.
- M3 reset-to-place → a belt Goober interrupted by death walks home on its own,
  arriving no sooner than the carry could have (stand reserved).
- M4 lag false positives → ping-based slack, 1.2 s averaging, 12-stud jump limit;
  ServerMove shifts history instead of granting a blanket grace.
- M5 chat window over the menu → chat moved to bottom-left on desktop.
- m1 steal prompts show "Steal in m:ss" during cooldowns; m3 sell refunds use the
  price actually paid (no Personal Drop flipping); m4 harness VIP revoke; m5 "No
  shortcuts" toast.

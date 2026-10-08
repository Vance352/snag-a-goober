# Snag A Goober - working rules for Claude

Solo project by **Vance**. No collaborators: this is not Locker Showdown, and
none of Locker Showdown's rules (git-sync agent, syncing with Brendan, the
shared Team Create place) apply here. Don't add collaborators or share
anything unless Vance asks.

## Roblox place

The game has its own Roblox place, separate from Locker Showdown. Before
writing a script into Studio, make sure the open place is the Snag A Goober
place, not Locker Showdown.

- After changing a script in Studio, export it to `src/` (same path as its
  Studio location) so git stays in step with the place.
- Before writing a script from git into Studio, compare with the Studio
  `Source`; if Studio has newer edits, export those first.

## Git

- Branch: `main`. Commit and push after each finished, verified change.
- Add a dated one-line entry to `CHANGELOG.md` (newest at top) per change.
- Never `git push --force` unless Vance asks.

## Publishing

Pushing to GitHub only backs up script text. Nothing reaches players until
Vance does Save -> Publish in Roblox Studio.

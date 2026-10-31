---
id: feature-how-to-play-tutorial
title: First-run "How to play" tutorial with skip
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-grid-puzzle-generation
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# Feature: First-run "How to play" tutorial

## Problem
New players get a one-line hint but no explanation of the goal, the input
methods, or how to undo a step. Players asked for a short explanation or a
tutorial that can be skipped.

## Scope
- On the first launch only, show a "How to play" overlay card over the game
  with 3 short steps (goal, tap/click/drag input and undo, difficulty and reset).
- Each step has an icon and one or two short lines; page dots; "Skip" and
  "Next" buttons ("Play" on the last step).
- Skip or Play closes the overlay and stores the bool `tutorial_seen_v1` in
  `shared_preferences`; later launches go straight into the game.
- A "?" icon button (tooltip "How to play") in the HUD header reopens it at
  step 1 at any time, in portrait and in the landscape side panel. Reopening
  does not reset the puzzle, path, or tries.
- Keyboard while open: Enter/Space = Next/Play, Escape = Skip, Left/Right =
  previous/next step. These keys do not reach the game.
- While open, taps and drags on the board and all HUD buttons are blocked.
- The solve timer (used for the leaderboard time) does not count the time the
  overlay is open.
- Storage failures never break play: a read failure shows the tutorial, a
  write failure just closes it.
- Implementation lives in `lib/how_to_play.dart` (overlay widget plus a
  `TutorialStore` that tests can fake).

## Acceptance Criteria
- First launch (flag unset) shows the overlay and blocks board input.
- Next walks the steps, the last step shows Play, and Play closes and stores the flag.
- Skip closes and stores the flag; Escape also skips.
- With the flag set the overlay does not appear on launch.
- "?" reopens at step 1 without resetting game state.
- The solve timer does not advance while the overlay is open.
- No layout overflow at 390x844, 844x390 and 1280x720.
- flutter analyze, flutter test, web build, and harness audit pass.

## Constraints
- English UI text, matching the existing game UI.
- No new dependency (`shared_preferences` is already used).
- Do not change puzzle generation or game rules.

## Evidence
- flutter analyze
- flutter test
- flutter build web --release --base-href /OneLineLabyrinth/
- `<harness-lab>` audit (`node <harness-lab>/dist/index.js audit . --format md`)

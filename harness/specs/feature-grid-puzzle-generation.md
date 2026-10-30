---
id: feature-grid-puzzle-generation
title: Readable grid puzzles, responsive layout, drag input, and best levels
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

# Feature: Grid puzzle generation and layout

## Problem
The solution path was built by shuffling every node index, so consecutive path
nodes could sit on opposite sides of the board. Lines crossed everywhere, the
board looked tangled, and with only a few decoy edges the path was nearly forced
on easy while hard was confusing rather than difficult.

## Scope
- Move puzzle generation into a widget-free Dart file (`lib/puzzle_generator.dart`)
  with an injectable `Random`.
- Place knots on a jittered grid: easy starts at 4x4, normal 5x5, hard 6x6; the
  grid grows by one column, then one row, every two levels up to a per-difficulty cap.
- Build the solution as a Hamiltonian path over orthogonal grid neighbours,
  starting from a serpentine path randomized with backbite moves.
- Add decoy edges only between orthogonal grid neighbours; hard may add at most
  one diagonal per grid cell so no two edges cross.
- Difficulty comes from branching: harder modes keep more decoy edges, weighted
  towards long path skips (dead-end traps) and decisions early in the path.
- Responsive layout for phone portrait and desktop landscape, content centred
  with a max width, board fully visible, click cursor over the board.
- Drag (pan) across knots to draw the path, in addition to tapping.
- Persist the best completed level per difficulty locally with `shared_preferences`.
- Web shell fix: Flutter's full-page mode reset the body padding, so the hub
  navigation bar covered the top 48px of the game. Flutter now renders into a
  `#game-host` element below the bar (`hostElement`), with a viewport meta tag
  because embedded mode does not inject one. This realises the intent of
  `adr-static-web-shell-hub-link` (offset and resize the Flutter host).

## Acceptance Criteria
- The generated solution visits every knot exactly once and only moves between
  grid neighbours; start and finish markers are the two ends of the solution.
- No two board edges cross; every decoy edge joins grid neighbours.
- Generation is deterministic for a seeded `Random` and terminates quickly for
  every difficulty and level.
- Tapping or dragging onto an adjacent unvisited knot extends the path; tapping or
  dragging back onto the previous knot undoes one step; reset and new puzzle work.
- Completing a level still offers optional leaderboard registration
  (`offerResultRegistration`, metric `time`) and the Next Level button.
- The best completed level per difficulty survives a reload and is shown in the HUD.
- At 390x844 and 1280x720 the board and HUD are fully visible without overflow.
- The games-hub navigation bar and `--base-href /OneLineLabyrinth/` build still work.
- `flutter analyze`, `flutter test`, web build, and harness audit pass.

## Constraints
- Only one new runtime dependency (`shared_preferences`); it must fail soft when
  storage is unavailable.
- Leaderboard submission rules from `feature-post-game-leaderboard` are unchanged.
- The hub navigation from `feature-game-hub-navigation` keeps working: same
  link, always visible, and it reserves its own space above the game.

## Evidence
- flutter analyze
- flutter test
- flutter build web --release --base-href /OneLineLabyrinth/
- harness audit

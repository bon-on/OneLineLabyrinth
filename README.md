# One Line Labyrinth

A one-line path puzzle built with Flutter for iOS, Android, and web.

Draw a single line from the filled start knot to the ring, visiting every knot
exactly once and only moving along the drawn links.

## Features

- Knots sit on a jittered grid (Easy 4x4, Normal 5x5, Hard 6x6); the grid grows
  every two levels up to 5x5 / 6x6 / 7x7.
- Every puzzle has a hidden Hamiltonian solution built from grid moves, so links
  never cross. Harder modes add more decoy links (and a few diagonals on Hard)
  that lead into dead ends.
- Tap knots one by one or drag across them. Tap or drag back onto the previous
  knot to undo a step; the undo button resets the line, the shuffle button deals
  a new puzzle.
- A first-run "How to play" card (skippable; reopen with the ? button) explains the rules and is remembered via `tutorial_seen_v1`.
- The best completed level per difficulty is saved locally.
- After finishing a level you can optionally register your time on the shared
  leaderboard.
- Layout adapts to phone portrait and desktop landscape screens.

Puzzle generation lives in `lib/puzzle_generator.dart` (widget-free, seedable
with `Random`) and is covered by `test/puzzle_generator_test.dart`.

## Run Locally

```sh
flutter pub get
flutter run -d chrome
flutter test
```

## Local Web Build

```sh
flutter build web --release --base-href /OneLineLabyrinth/
```

GitHub Pages deploys from `.github/workflows/deploy-pages.yml`.

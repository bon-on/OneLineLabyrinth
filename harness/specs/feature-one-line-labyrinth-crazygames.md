---
id: feature-one-line-labyrinth-crazygames
title: One Line Labyrinth CrazyGames web distribution
status: active
owner: games
related_adrs:
  - adr-one-line-labyrinth-crazygames-web
related_contracts:
  - contract-one-line-labyrinth-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - crazygames-web-build
  - harness-audit
---

# Feature: CrazyGames web distribution

## Problem
The web build is only served from GitHub Pages. To publish on the CrazyGames
portal the game needs the HTML5 SDK v3 gameplay events, a relative-path bundle,
and no outbound links or external result uploads.

## Scope
- A build flag `--dart-define=CRAZYGAMES=true` selects a CrazyGames platform
  adapter (`dart:js_interop`); without it the game uses a no-op platform and
  behaves exactly as before (GitHub Pages, iOS, Android).
- SDK events, sent only on transitions (never duplicated):
  - `gameplayStart` when the player is actually playing: after the stored
    tutorial flag has been read and the "How to play" overlay is not open and
    the puzzle is unsolved. On first launch this means after the overlay closes.
  - `gameplayStop` when the overlay opens (first run or via "?") and when a
    level is completed.
  - `gameplayStart` again when the overlay closes, and on Next Level / new
    puzzle / difficulty change after a completed level.
- `SDK.init()` failure, timeout, missing SDK, or environment other than
  `crazygames`/`local` silently disables the adapter; the game stays playable.
- The CrazyGames build skips the leaderboard offer
  (`feature-post-game-leaderboard`) via `GamePlatform.allowsResultRegistration`.
- `tool/build_crazygames.sh` builds `build/crazygames/` and
  `build/one-line-labyrinth-crazygames.zip`: relative `<base href="./">`, SDK
  script before the Flutter loader, hub navigation bar
  (`feature-game-hub-navigation`) removed and its height set to 0, `*.symbols`
  removed, file count <= 1500, size <= 50MB, with self-checks.
- No ad network is used in any build.

Out of scope: gameplay or puzzle changes, ads, portal upload. (CrazyGames Data/User
modules were introduced later only for progress saving, see `feature-crazygames-cloud-save`.)

## Acceptance Criteria
- `flutter analyze` and `flutter test` pass; `flutter test --platform chrome test/web` passes.
- Fake-platform widget tests verify call order including the tutorial overlay,
  level completion and next level, and that the leaderboard offer follows the platform.
- `tool/build_crazygames.sh` succeeds and the bundle `index.html` has the
  relative base href, the SDK script before the loader, no `bon-on.github.io`
  link and `--games-nav-height: 0px`.
- `flutter build web --release --base-href /OneLineLabyrinth/` has no SDK script and keeps the hub navigation bar.

## Constraints
- Do not change puzzle generation, game rules, or timing.
- No new pub dependency.
- SDK failures must never break play.

## Evidence
- flutter analyze, flutter test, flutter test --platform chrome test/web
- tool/build_crazygames.sh
- flutter build web --release --base-href /OneLineLabyrinth/
- `<harness-lab>` audit (`node <harness-lab>/dist/index.js audit . --format md`)
- reports/one-line-labyrinth-crazygames-verification.md

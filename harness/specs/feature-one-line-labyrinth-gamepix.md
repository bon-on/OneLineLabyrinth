---
id: feature-one-line-labyrinth-gamepix
title: One Line Labyrinth GamePix web distribution
status: active
owner: games
related_adrs:
  - adr-one-line-labyrinth-crazygames-web
  - adr-gamepix-sdk
related_contracts:
  - contract-one-line-labyrinth-gamepix
required_evidence:
  - flutter-tests
  - flutter-analyze
  - gamepix-web-build
  - harness-audit
---

# Feature: One Line Labyrinth GamePix web distribution

## Problem
GamePix requires an HTML5 bundle that loads only from relative paths, has no outbound links or external network use, and shows a loading screen while the engine starts.

## Scope
- A web bundle built with `--dart-define=GAMEPIX=true` uses `GamePixPlatform` (SDK v3, see `feature-gamepix-sdk` and `adr-gamepix-sdk`, which supersede the former SDK-free, no-ads rule), whose `allowsResultRegistration` is false. The CrazyGames adapter is selected only by `CRAZYGAMES=true` and is tree-shaken out of the GamePix bundle.
- No leaderboard prompt or result upload (external network) and no Bon-on hub link in this bundle: the build script removes the hub navigation bar and its reserved height.
- Resources load from relative paths only: `--no-web-resources-cdn`, `<base href="./">`. Roboto is bundled in `assets/fonts/` (all builds) so the app does not fetch it from fonts.gstatic.com.
- A CSS loader (spinner and game title, no external assets) in `web/index.html` shows until Flutter paints its first frame (`flutter-first-frame`), in Pages, CrazyGames and GamePix builds.
- `tool/build_gamepix.sh` produces `build/gamepix/` and `build/one-line-labyrinth-gamepix.zip` with `index.html` at the zip root and self-checks the result.

Out of scope: gameplay changes, the SDK behaviour (see `feature-gamepix-sdk`), portal upload, store artwork.

## Acceptance Criteria
- `flutter analyze` and `flutter test` pass; `flutter test --platform chrome test/web` passes (GAMEPIX selection: `GamePixPlatform` with `allowsResultRegistration == false`; CrazyGames adapter only for `CRAZYGAMES`).
- `tool/build_gamepix.sh` succeeds: `<base href="./">`, no `crazygames` / `bon-on.github.io` in `index.html`, no external script other than the GamePix SDK, `index.html` at the zip root, `FontManifest.json` lists Roboto.
- The GamePix `main.dart.js` contains no CrazyGames adapter strings (count reported).
- The bundle renders without overflow at 640x480 and 360x640 and makes no external requests other than the GamePix SDK.
- `tool/build_crazygames.sh` and the GitHub Pages build still pass; the loader is removed after the first frame.
- `web/index.html` keeps a `user-scalable=no` viewport meta and `touch-action: none` on `body`.

## Constraints
- Gameplay works offline. No new pub dependencies.
- Portal-specific code stays behind `GamePlatform`; game screens never import a portal adapter.
- Portal UI language is English.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_gamepix.sh`, `tool/build_crazygames.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
- `reports/one-line-labyrinth-gamepix-verification.md`

---
id: adr-one-line-labyrinth-crazygames-web
title: Use a build flag and platform adapter for the CrazyGames distribution
status: accepted
related_specs:
  - feature-one-line-labyrinth-crazygames
  - feature-one-line-labyrinth-gamepix
  - feature-sound-effects
---

# ADR: Build flag and platform adapter for CrazyGames

## Context
The same Flutter web code is deployed to GitHub Pages and must also be
uploadable to CrazyGames, which serves bundles from an unknown sub path, forbids
outbound links, and expects SDK gameplay events.

## Decision
- `bool.fromEnvironment('CRAZYGAMES')` picks the platform. The game screen only
  depends on the `GamePlatform` interface (`gameplayStart`, `gameplayStop`,
  `allowsResultRegistration`, `isAudioMuted`); a conditional import on `dart.library.js_interop`
  keeps the JS adapter out of mobile builds.
- The SDK script and relative base href are injected into the build output by
  `tool/build_crazygames.sh`, not into `web/index.html`. The script also removes the
  hub navigation bar and fails when its string replacements did not apply.
- The leaderboard prompt is gated by `allowsResultRegistration` (false on CrazyGames).

## Consequences
- Pages and mobile builds are unaffected.
- SDK failures degrade to no-op behaviour.
- The bundle depends on string replacements in the custom `web/index.html`;
  the script verifies them.

## GamePix addendum
GamePix builds (`--dart-define=GAMEPIX=true`, see `feature-one-line-labyrinth-gamepix`) reuse the no-op platform with `allowsResultRegistration == false` instead of an adapter: GamePix forbids third-party SDKs and external network use. The CrazyGames adapter is selected only by `CRAZYGAMES=true`.

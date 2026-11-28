---
id: adr-gamepix-sdk
title: Integrate the GamePix SDK v3 in the GamePix build
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-one-line-labyrinth-gamepix
---

# ADR: Integrate the GamePix SDK v3 in the GamePix build

## Context
The GamePix build was SDK-free by design (feature-one-line-labyrinth-gamepix). GamePix withholds exposure from games without SDK integration.

## Decision
- `GAMEPIX=true` web builds select `GamePixPlatform` (SDK v3, manual lifecycle). The SDK script is injected by `tool/build_gamepix.sh` before the Flutter bootstrap; it is the only external script allowed.
- Pause/resume mute audio and pause the solve clock and input; interstitials only when moving on from a solved maze with a 2 minute cooldown; preferences in one named localStorage item via `CloudPrefsStore`.
- This supersedes the "no SDK, no ads" part of feature-one-line-labyrinth-gamepix; its other rules (no outbound links, bundled fonts, relative paths) stay.

## Alternatives
- Stay SDK-free: no work, but no extra exposure.
- Legacy automatic lifecycle: less code, but GamePix load analytics are less accurate.
- Keep shared_preferences_web as is: GamePix sync would not restore progress, because the plugin enumerates keys.

## Consequences
- The GamePix bundle makes requests to integration.gamepix.com and shows GamePix ads.
- The solve clock and audio follow GamePix pause events as well as tab visibility.
- Existing players keep their progress: the first SDK session copies the enumerated local keys into the named item.

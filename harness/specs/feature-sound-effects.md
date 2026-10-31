---
id: feature-sound-effects
title: Sound effects with a persisted mute toggle
status: active
owner: games
related_adrs:
  - adr-one-line-labyrinth-crazygames-web
related_contracts:
  - contract-one-line-labyrinth-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# Feature: Sound effects with a persisted mute toggle

## Problem
The game is silent. Short sound effects make moves, mistakes and a solved
labyrinth feel responsive on web (GitHub Pages, CrazyGames, GamePix) and on
iOS and Android, and players need a way to turn them off.

## Scope
- Four short effects in `assets/audio/` (mono 44.1 kHz 16-bit WAV, each under
  40 KB): `step` (a knot joins the line), `undo` (stepping back onto the
  previous knot, or a reset that clears the line), `invalid` (a tap on a knot
  that is visited or not linked to the line end) and `solved` (the ring is
  reached with every knot filled; replaces `step` for that move).
- Sounds are synthesized by the committed, dependency-free generator
  `tool/generate_sounds.py` (Python 3 stdlib, fixed seed, deterministic).
  No third-party audio.
- `lib/src/audio/sound_fx.dart`: `SoundFx.play(Sfx)` is fire-and-forget, a
  no-op when muted and never throws. Web uses HTML `Audio` elements
  (`web_sound_web.dart`, with `web_sound_stub.dart` for other targets); native
  uses the MethodChannel `one_line_labyrinth/audio` (`play {asset, volume}`,
  `disposeAudio`). iOS plays with `AVAudioPlayer` in the `.ambient` session
  category (respects the silent switch, keeps the user's music); Android uses
  `MediaPlayer` with `USAGE_GAME`. Missing plugin or platform errors are
  swallowed.
- Hook points are in `lib/main.dart` (`_stepTo`, `_resetPath`), once per
  user action, never from `puzzle_generator.dart`, never per frame. While
  dragging, skimming over unlinked knots is silent; only taps play `invalid`.
- Mute: a sound icon button next to "?" in the HUD header
  (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`, tooltip "Sound on" /
  "Sound off"). The choice is stored as the bool `sound_muted_v1` in
  `shared_preferences` (default: sound on). Effective mute is the user choice
  OR `GamePlatform.isAudioMuted`, which the CrazyGames adapter reads from
  `CrazyGames.SDK.game.settings.muteAudio` on every sound; the no-op and
  GamePix platforms return false.
- The button lives inside the same `ExcludeFocus` / `AbsorbPointer` subtree as
  "?", so it is blocked while the tutorial card is open or loading. No new
  keyboard shortcut. The tutorial card itself makes no sound.

## Acceptance Criteria
- Each step, undo, invalid tap and solve plays exactly one matching effect.
- Nothing plays while muted (user toggle or platform mute); the toggle flips
  the icon and tooltip and persists across launches.
- Every `Sfx` value has a file in `assets/audio/` listed by `pubspec.yaml`.
- Running `python3 tool/generate_sounds.py` twice yields identical files.
- `tool/build_crazygames.sh` and `tool/build_gamepix.sh` self-checks pass; the
  GamePix bundle makes no external requests.
- A headless browser run observes `HTMLMediaElement.play` for the expected
  assets, and nothing when muted.
- No layout overflow at 390x844, 844x390 and 1280x720.

## Constraints
- English UI text; no new package dependency.
- Do not change puzzle generation or game rules.
- Audio must be bundled assets (GamePix: no external requests).

## Evidence
- flutter analyze, flutter test, `flutter test --platform chrome test/web`
- flutter build web --release --base-href /OneLineLabyrinth/
- tool/build_crazygames.sh, tool/build_gamepix.sh
- `<harness-lab>` audit (`node <harness-lab>/dist/index.js audit . --format md`)

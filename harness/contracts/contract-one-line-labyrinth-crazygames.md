---
id: contract-one-line-labyrinth-crazygames
title: One Line Labyrinth CrazyGames web distribution contract
status: active
related_specs:
  - feature-one-line-labyrinth-crazygames
evidence_files:
  - docs/crazygames.md
  - reports/one-line-labyrinth-crazygames-verification.md
---

# Contract: CrazyGames web distribution

## Goal
Produce an upload-ready CrazyGames bundle from the same Flutter codebase.

## Done Criteria
- `flutter analyze`, `flutter test` and the chrome SDK adapter tests pass.
- `tool/build_crazygames.sh` passes its checks.
- The Pages build contains no CrazyGames SDK script.
- Verification is recorded in `reports/one-line-labyrinth-crazygames-verification.md`.

## Verification
```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_crazygames.sh
flutter build web --release --base-href /OneLineLabyrinth/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References
- docs/crazygames.md
- reports/one-line-labyrinth-crazygames-verification.md

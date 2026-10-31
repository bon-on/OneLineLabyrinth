# Verification: One Line Labyrinth CrazyGames web distribution

- Spec: `harness/specs/feature-one-line-labyrinth-crazygames.md`
- ADR: `harness/adrs/adr-one-line-labyrinth-crazygames-web.md`
- Contract: `harness/contracts/contract-one-line-labyrinth-crazygames.md`

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 41 passed (33 before, +6 platform flow, +2 overlay/loading fixes) |
| `flutter test --platform chrome test/web` | 6 passed (missing SDK, disabled env, rejected init, init timeout, leaderboard off, events) |
| `tool/build_crazygames.sh` | passed: 32 files, about 28MB; relative base href, SDK before loader, no hub nav, nav height 0 |
| `flutter build web --release --base-href /OneLineLabyrinth/` | passed; no SDK script, hub nav kept |
| harness audit | Critical 0 |

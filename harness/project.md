# Project instructions

Project-owned. Add instructions specific to this repository here, such as operational cautions, domain rules or verification notes that do not fit a spec, ADR or rule file. harness-lab creates this file once and never replaces your edits; keep `AGENTS.md`, `CLAUDE.md` and `harness/workflow.md` identical to the template so `harness-lab update` can refresh them.

- Active specs: `harness/specs/feature-crazygames-starter-puzzles.md`,
  `feature-crazygames-cloud-save.md`, `feature-one-line-labyrinth-crazygames.md`
  (baselines: `feature-retention-polish.md`, `feature-how-to-play-tutorial.md`).
- Authored Easy 1-5 boards live in `lib/src/game/starter_puzzles.dart`; changing
  one changes saved-progress meaning for that level, so update the spec and tests.
- Release builds: `tool/build_crazygames.sh` (CrazyGames ZIP) and
  `flutter build web --release --base-href /OneLineLabyrinth/` (Pages).

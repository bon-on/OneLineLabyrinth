# Grid Puzzle Generation Evidence

Spec: harness/specs/feature-grid-puzzle-generation.md
Contract: harness/contracts/contract-grid-puzzle-generation.md

## Verification

- `flutter analyze`: No issues found.
- `flutter test`: 20 tests passed (generator properties over 216 seeded
  difficulty/level cases: Hamiltonian over orthogonal neighbours, start/finish
  at the ends, decoys only between grid neighbours, no crossing edges,
  determinism, growth cap, generation speed; widget tests for 390x844 and
  1280x720 layout, tap solve + undo + leaderboard prompt + best save, drag
  forward and drag-back undo, reset/new puzzle, stored best in HUD;
  BestLevelStore with mocked shared_preferences; web shell navigation).
- `flutter build web --release --base-href /OneLineLabyrinth/`: built.
- Headless Chrome (CDP device emulation) screenshots at 390x844 and 1280x720,
  easy and hard: hub bar visible above the game, HUD and full board visible,
  no overflow, no crossing links.
- Independent code review: no Critical/High findings. Medium findings fixed
  (body overflow with embedded host, spec/ADR note for the host change,
  missing tests); low findings fixed (reset no longer inflates tries, hint when
  all knots are filled but the line does not end on the ring).

## Harness Audit

# Harness Audit Report

- Repo: OneLineLabyrinth
- Manifest: <repo>/harness/manifest.json
- Policy mode: warn-block-critical
- Stack summary: No known stack profile detected
- Detected profiles: none
- Approved packs: none
- Blocked: no
- Specs: 4
- ADRs: 3
- Contracts: 4
- Critical findings: 0
- Warnings: 4

## Findings

- [warning] agent-workflow-unlinked: Agent instructions do not reference harness/workflow.md: AGENTS.md. Preserve existing policy and integrate the shared workflow. (<repo>/AGENTS.md)
- [warning] agent-entry-missing: Missing or empty agent workflow file: CLAUDE.md (<repo>/CLAUDE.md)
- [warning] agent-entry-missing: Missing or empty agent workflow file: harness/workflow.md (<repo>/harness/workflow.md)
- [warning] maintenance-review-required: Missing or invalid harness/maintenance.json. (<repo>/harness/maintenance.json)

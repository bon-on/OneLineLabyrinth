---
id: contract-grid-puzzle-generation
title: Deliver grid puzzle generation and responsive board
status: active
related_specs:
  - feature-crazygames-starter-puzzles
  - feature-grid-puzzle-generation
  - feature-how-to-play-tutorial
  - feature-retention-polish
evidence_files:
  - reports/grid-puzzle-generation-audit.md
---

# Contract: Grid puzzle generation

## Goal
Generate clean, non-crossing grid puzzles whose difficulty comes from branching,
and present them in a responsive layout with tap and drag input.

## Done Criteria
- Generator, unit tests, responsive layout, drag input, best-level persistence,
  README notes, and harness audit are complete.

## Verification
- flutter analyze
- flutter test
- flutter build web --release --base-href /OneLineLabyrinth/
- harness audit
- Headless Chrome screenshots at 390x844 and 1280x720

## Evidence References
- reports/grid-puzzle-generation-audit.md

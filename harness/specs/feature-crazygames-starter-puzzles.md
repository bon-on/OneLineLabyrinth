---
id: feature-crazygames-starter-puzzles
title: Playable onboarding and authored Easy puzzles for CrazyGames
status: active
owner: games
related_adrs:
  - adr-one-line-labyrinth-crazygames-web
  - adr-spec-driven-delivery
related_contracts:
  - contract-grid-puzzle-generation
  - contract-one-line-labyrinth-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-web-build
  - harness-audit
---

# Playable onboarding

## Problem

On a first visit a three-page modal blocks input, then the player faces a
16-star generated puzzle. The constellation reveal and collection arrive
after the player has already had to learn the full game.

## Scope

- Select this flow using the existing CrazyGames build flag. The first
  playable frame shows Easy level 1 without reading the tutorial preference.
  The help button still opens the existing tutorial on demand.
- Author Easy levels 1–5. The first has six stars and a single route. The
  remaining boards introduce branches, a recoverable dead end, and larger
  route-planning challenges. Easy level 6 onward uses the existing
  generator shifted by five levels (Easy 6 generates generator level 1), so
  the board size continues from the authored ramp (16 stars) instead of
  jumping to 25. Normal and Hard levels use the generator unshifted. The
  shift applies only while this flow is on; it changes which board a saved
  Easy level 6+ shows, not any saved progress.
- Easy level 1 highlights the first link and target until the line moves.
  In any authored level, show the prior star and an arrow back when stuck.
  Treat an early visit to the finish ring as a dead end in these levels,
  because a valid route cannot leave the ring and revisit it later.
  These cues do not use the hint action or modify score. A player's actual
  undo continues to count toward Clean line as before.
- Existing level numbers, unlocked levels, album shapes, best stars, and
  XP use their existing keys and merge rules. New clears use the same
  result flow. Replay, restart, and level map select the same authored board.
- The flow is also selected by `--dart-define=STARTER_PUZZLES=true`. The
  GitHub Pages build sets it (still no SDK, hub navigation kept); native and
  GamePix builds leave it unset and keep the tutorial modal and generated
  Easy 1.

## Acceptance Criteria

- A fresh CrazyGames session can tap or drag immediately, finish Easy 1,
  see the existing constellation reward, and continue to Easy 2. Starting
  play does not depend on stored tutorial state. SDK start/stop fires once
  per active transition including help, lifecycle, and clear/next.
- Each authored board has a fixed, valid noncrossing solution. A wrong turn
  in Easy 3 demonstrates backtracking and the player can recover and finish.
- The level map and restart preserve authored boards and existing progress.
  Easy 6+ use the shifted generator and Normal/Hard remain generated.
- First-board input and recovery cues work on a desktop iframe and a
  portrait mobile viewport. The 30-second first-clear target requires a
  first-time human playtest.

## Constraints

- Reuse the current game rules, SDK adapter, and progress schema.
- Add no dependencies and keep other distribution flows intact.

## Evidence

- Authored puzzle tests cover route validity, branches, and generation
  boundaries. Widget tests cover onboarding, tap/drag, recovery, rewards,
  and SDK transitions. Existing tests cover unaffected distributions.
- Run Flutter analyze, VM tests, Chrome SDK tests, CrazyGames and Pages
  release builds, and the harness audit.

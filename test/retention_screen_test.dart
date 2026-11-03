import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/platform/game_platform.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/art/sky_theme.dart';
import 'package:one_line_labyrinth/src/meta/constellations.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Seen extends TutorialStore {
  const _Seen();

  @override
  Future<bool> isSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _MemoryBest extends BestLevelStore {
  _MemoryBest([Map<String, int>? initial]) : saved = {...?initial};

  final Map<String, int> saved;

  @override
  Future<Map<String, int>> load(Iterable<String> names) async => {
    for (final n in names) n: saved[n] ?? 0,
  };

  @override
  Future<void> save(String difficultyName, int level) async {
    saved[difficultyName] = math.max(saved[difficultyName] ?? 0, level);
  }
}

/// A store whose load waits for [gate].
class _GatedStore extends MemorySkyProgressStore {
  _GatedStore(super.value, this.gate);

  final Future<void> gate;

  @override
  Future<SkyProgress> load() async {
    await gate;
    return value;
  }
}

const _seed = 3;

GridPuzzle _puzzle([
  PuzzleDifficulty difficulty = PuzzleDifficulty.easy,
  int level = 1,
]) => PuzzleGenerator(random: math.Random(_seed)).generate(difficulty, level);

Offset _at(WidgetTester tester, GridPuzzle puzzle, int index) {
  final board = find.byKey(const ValueKey('board'));
  final side = tester.getSize(board).shortestSide;
  final node = puzzle.nodes[index];
  return tester.getTopLeft(board) + Offset(node.x * side, node.y * side);
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  SkyProgressStore? progress,
  BestLevelStore? best,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: best ?? _MemoryBest(),
      tutorialStore: const _Seen(),
      progressStore: progress ?? MemorySkyProgressStore(),
      platform: const NoopGamePlatform(allowsResultRegistration: false),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _solve(WidgetTester tester, GridPuzzle puzzle) async {
  for (final index in puzzle.solution.skip(1)) {
    await tester.tapAt(_at(tester, puzzle, index));
    await tester.pump();
  }
}

Future<void> _frames(WidgetTester tester, [int count = 30]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a clean fast solve earns 3 stars, XP and an album entry', (
    tester,
  ) async {
    final store = MemorySkyProgressStore();
    await _pump(tester, progress: store);
    await _solve(tester, _puzzle());
    await _frames(tester);

    expect(find.text('Next Level'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('The Lantern'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    expect(find.text('New constellation!'), findsOneWidget);
    expect(find.text('+65 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('3 of 3 stars'), findsWidgets);
    expect(store.value.starsFor(PuzzleDifficulty.easy, 1), 3);
    expect(store.value.albumCount, 1);
    expect(store.value.totalXp, 65);
    expect(tester.takeException(), isNull);

    // Enter starts the next level.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Next Level'), findsNothing);
    final level2 = _puzzle(PuzzleDifficulty.easy, 2);
    expect(find.text('1/${level2.nodeCount}'), findsOneWidget);
  });

  testWidgets('undo costs the clean star and a hint rewinds the line', (
    tester,
  ) async {
    final store = MemorySkyProgressStore();
    await _pump(tester, progress: store);
    final puzzle = _puzzle();
    final solution = puzzle.solution;

    // Step off the solution if a decoy link exists, else just step forward.
    final decoy = puzzle
        .neighbors(solution[0])
        .where((n) => n != solution[1])
        .firstOrNull;
    if (decoy != null) {
      await tester.tapAt(_at(tester, puzzle, decoy));
      await tester.pump();
      expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);

    await _solve(tester, puzzle);
    await _frames(tester);
    expect(store.value.starsFor(PuzzleDifficulty.easy, 1), 2);
    expect(find.bySemanticsLabel('2 of 3 stars'), findsWidgets);
  });

  testWidgets('keyboard: H hints, Backspace undoes, R resets', (tester) async {
    await _pump(tester);
    final puzzle = _puzzle();
    await tester.tapAt(_at(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    await tester.tapAt(_at(tester, puzzle, puzzle.solution[2]));
    await tester.pump();
    expect(find.text('3/${puzzle.nodeCount}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(
      find.text('Follow the golden guide to the next star.'),
      findsOneWidget,
    );
  });

  testWidgets('level map opens unlocked levels only and starts the pick', (
    tester,
  ) async {
    final store = MemorySkyProgressStore(
      SkyProgress.fromJson({
        'bestLevels': {'easy': 2},
        'levelStars': {
          'easy': {'1': 3, '2': 1},
        },
      }),
    );
    await _pump(tester, progress: store);
    await tester.tap(find.byTooltip('Level map'));
    await tester.pump();
    expect(find.text('Level map'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 4, locked'), findsOneWidget);

    // Locked levels do nothing.
    await tester.tap(find.bySemanticsLabel('Level 4, locked'));
    await tester.pump();
    expect(find.text('Level map'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Level 3, ')));
    await tester.pump();
    expect(find.text('Level map'), findsNothing);
    final level3 = _puzzle(PuzzleDifficulty.easy, 3);
    expect(find.text('1/${level3.nodeCount}'), findsOneWidget);
  });

  testWidgets('menus block the board and close with Escape', (tester) async {
    final watch = Stopwatch();
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      OneLineLabyrinthApp(
        random: math.Random(_seed),
        bestLevelStore: _MemoryBest(),
        tutorialStore: const _Seen(),
        progressStore: MemorySkyProgressStore(),
        stopwatch: watch,
      ),
    );
    await tester.pump();
    final puzzle = _puzzle();
    await tester.tap(find.byTooltip('Constellation album'));
    await tester.pump();
    expect(find.text('Constellation album'), findsOneWidget);
    expect(find.text('???'), findsWidgets);
    expect(watch.isRunning, isFalse);

    await tester.tapAt(_at(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);
    // A tap on the scrim outside the card closes the album.
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('Constellation album'), findsNothing);
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);
    expect(watch.isRunning, isTrue);

    await tester.tap(find.byTooltip('Level map'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Level map'), findsNothing);
  });

  testWidgets('unlocked themes can be picked and persist', (tester) async {
    final store = MemorySkyProgressStore(
      SkyProgress.fromJson({'totalXp': 240}),
    );
    await _pump(tester, size: const Size(1280, 720), progress: store);
    await tester.tap(find.byTooltip('Nebula sky (Sky Lv 6)'));
    await tester.pump();
    expect(store.value.selectedTheme, SkyTheme.twilight);
    await tester.tap(find.byTooltip('Aurora sky'));
    await tester.pump();
    expect(store.value.selectedTheme, SkyTheme.aurora);
  });

  testWidgets('legacy best levels show and migrate into the new key', (
    tester,
  ) async {
    final store = MemorySkyProgressStore();
    await _pump(tester, progress: store, best: _MemoryBest({'easy': 7}));
    expect(find.text('7'), findsOneWidget);
    expect(store.value.bestLevel(PuzzleDifficulty.easy), 7);
  });

  testWidgets('a solve before the progress loads is merged, not lost', (
    tester,
  ) async {
    final gate = Completer<void>();
    final stored = SkyProgress.fromJson({
      'totalXp': 100,
      'album': {
        Constellations.slotKey(PuzzleDifficulty.hard, 1): [0, 0, 9, 9],
      },
    });
    final store = _GatedStore(stored, gate.future);
    await _pump(tester, progress: store);
    await _solve(tester, _puzzle());
    await tester.pump();
    expect(store.saveCount, 0, reason: 'never save before loading');

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(store.saveCount, 1);
    expect(store.value.totalXp, 165);
    expect(store.value.albumCount, 2);
  });

  testWidgets('corrupt saved progress falls back and the game plays', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SkyProgressStore.progressKey: '{oops',
      TutorialStore.key: true,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OneLineLabyrinthApp(random: math.Random(_seed)));
    await _frames(tester, 4);
    final puzzle = _puzzle();
    await tester.tapAt(_at(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(1366, 768),
    Size(320, 480),
  ]) {
    testWidgets('solved level and menus fit without overflow at $size', (
      tester,
    ) async {
      await _pump(
        tester,
        size: size,
        progress: MemorySkyProgressStore(
          SkyProgress.fromJson({'totalXp': 230}),
        ),
      );
      expect(tester.takeException(), isNull);
      await _solve(tester, _puzzle());
      await _frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Next Level'), findsOneWidget);
      expect(find.textContaining('Aurora unlocked'), findsOneWidget);
      // The result buttons stay on screen and hittable.
      final next = tester.getCenter(find.text('Next Level'));
      expect((Offset.zero & size).contains(next), isTrue);
      for (final menu in ['Level map', 'Constellation album']) {
        // Very short screens give the footer to the result card.
        if (find.byTooltip(menu).evaluate().isEmpty) continue;
        await tester.tap(find.byTooltip(menu));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Next Level'));
      await tester.pump();
      expect(find.text('Next Level'), findsNothing);
    });
  }

  testWidgets('keyboard picks a level in the map and hints expire', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(1280, 720),
      progress: MemorySkyProgressStore(
        SkyProgress.fromJson({
          'bestLevels': {'easy': 3},
        }),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(
      find.text('Follow the golden guide to the next star.'),
      findsOneWidget,
    );
    await _frames(tester, 60);
    expect(
      find.text('Follow the golden guide to the next star.'),
      findsNothing,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(find.text('Level map'), findsOneWidget);
    // Tab past the close button and the difficulty buttons to level 1, 2.
    final tile = find.bySemanticsLabel(RegExp(r'^Level 2, '));
    Focus.of(
      tester.element(
        find.descendant(of: tile, matching: find.byType(Text)).first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Level map'), findsNothing);
    final level2 = _puzzle(PuzzleDifficulty.easy, 2);
    expect(find.text('1/${level2.nodeCount}'), findsOneWidget);
  });
}

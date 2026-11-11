import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/platform/game_platform.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/art/sky_theme.dart';
import 'package:one_line_labyrinth/src/game/board_painter.dart';
import 'package:one_line_labyrinth/src/game/starter_puzzles.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress_store.dart';

class _FakePlatform extends GamePlatform {
  _FakePlatform({this.allowsResultRegistration = false});

  @override
  final bool allowsResultRegistration;

  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

class _MemoryBestLevelStore extends BestLevelStore {
  @override
  Future<Map<String, int>> load(Iterable<String> names) async => {
    for (final n in names) n: 0,
  };

  @override
  Future<void> save(String difficultyName, int level) async {}
}

class _Tutorial extends TutorialStore {
  _Tutorial({this.seen = false});

  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

const _seed = 3;

GridPuzzle get _puzzle => PuzzleGenerator(
  random: math.Random(_seed),
).generate(PuzzleDifficulty.easy, 1);

Offset _node(WidgetTester tester, GridPuzzle puzzle, int index) {
  final board = find.byKey(const ValueKey('board'));
  final side = tester.getSize(board).shortestSide;
  final node = puzzle.nodes[index];
  return tester.getTopLeft(board) + Offset(node.x * side, node.y * side);
}

Future<void> _pump(
  WidgetTester tester,
  _FakePlatform platform,
  TutorialStore tutorial, {
  Stopwatch? stopwatch,
  bool useStarterPuzzles = false,
  MemorySkyProgressStore? progressStore,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: _MemoryBestLevelStore(),
      tutorialStore: tutorial,
      platform: platform,
      stopwatch: stopwatch,
      useStarterPuzzles: useStarterPuzzles,
      progressStore: progressStore,
    ),
  );
  await tester.pump();
}

Future<void> _solve(WidgetTester tester) async {
  final puzzle = _puzzle;
  for (final index in puzzle.solution.skip(1)) {
    await tester.tapAt(_node(tester, puzzle, index));
    await tester.pump();
  }
  await tester.pump();
}

// Mirror the browser's inactive transition on both sides of hidden.
void _setLifecycle(WidgetTester tester, AppLifecycleState state) {
  if ((state == AppLifecycleState.hidden &&
          tester.binding.lifecycleState == AppLifecycleState.resumed) ||
      (state == AppLifecycleState.resumed &&
          tester.binding.lifecycleState == AppLifecycleState.hidden)) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(state);
}

class _UnusedTutorial extends TutorialStore {
  const _UnusedTutorial();

  @override
  Future<bool> isSeen() =>
      throw StateError('The playable intro reads no flag.');

  @override
  Future<void> markSeen() =>
      throw StateError('The playable intro writes no flag.');
}

BoardPainter _boardPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byKey(const ValueKey('board')),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((widget) => widget.painter)
    .whereType<BoardPainter>()
    .single;

Future<void> _tapNodes(
  WidgetTester tester,
  GridPuzzle puzzle,
  Iterable<int> nodes,
) async {
  for (final index in nodes) {
    await tester.tapAt(_node(tester, puzzle, index));
    await tester.pump();
  }
}

void main() {
  for (final size in [
    const Size(821, 462),
    const Size(800, 450),
    const Size(390, 844),
  ]) {
    testWidgets('CrazyGames first board is playable immediately at $size', (
      tester,
    ) async {
      final platform = _FakePlatform();
      final progress = MemorySkyProgressStore();
      await _pump(
        tester,
        platform,
        const _UnusedTutorial(),
        useStarterPuzzles: true,
        progressStore: progress,
        size: size,
      );
      final puzzle = starterPuzzleFor(1)!;
      expect(find.text('How to play'), findsNothing);
      expect(find.text('1/6'), findsOneWidget);
      expect(_boardPainter(tester).guideTarget, puzzle.solution[1]);
      expect(platform.events, ['start']);

      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      expect(platform.events, ['start', 'stop']);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(platform.events, ['start', 'stop', 'start']);
      _setLifecycle(tester, AppLifecycleState.hidden);
      _setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);

      if (size.width < size.height) {
        final gesture = await tester.startGesture(
          _node(tester, puzzle, puzzle.start),
        );
        for (final index in puzzle.solution.skip(1)) {
          await gesture.moveTo(_node(tester, puzzle, index));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
      } else {
        await _tapNodes(tester, puzzle, puzzle.solution.skip(1).take(1));
        expect(_boardPainter(tester).guideTarget, isNull);
        await _tapNodes(tester, puzzle, puzzle.solution.skip(2));
      }

      expect(platform.events, [
        'start',
        'stop',
        'start',
        'stop',
        'start',
        'stop',
      ]);
      expect(find.text('The Lantern'), findsWidgets);
      expect(progress.value.album['easy:1']?.length, 12);
      expect(progress.value.starsFor(PuzzleDifficulty.easy, 1), 3);
      await tester.tap(find.text('Next Level'));
      await tester.pump();
      expect(find.text('1/9'), findsOneWidget);
      expect(platform.events.last, 'start');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'CrazyGames starter run teaches undo and leads into generated play',
    (tester) async {
      final platform = _FakePlatform();
      final progress = MemorySkyProgressStore();
      await _pump(
        tester,
        platform,
        const _UnusedTutorial(),
        useStarterPuzzles: true,
        progressStore: progress,
      );

      for (var level = 1; level <= 5; level++) {
        final puzzle = starterPuzzleFor(level)!;
        expect(_boardPainter(tester).puzzle.solution, puzzle.solution);
        if (level == 3) {
          await _tapNodes(tester, puzzle, [1, 2, 3, 7, 11]);
          expect(_boardPainter(tester).deadEnd, isTrue);
          expect(_boardPainter(tester).guideTarget, 7);
          expect(find.text('Go back to the highlighted star.'), findsOneWidget);
          await _tapNodes(tester, puzzle, [10]);
          expect(_boardPainter(tester).path.last, 11);
          await _tapNodes(tester, puzzle, [7]);
          expect(_boardPainter(tester).guideTarget, isNull);
          await _tapNodes(tester, puzzle, puzzle.solution.skip(5));
          expect(progress.value.starsFor(PuzzleDifficulty.easy, level), 2);
        } else {
          await _tapNodes(tester, puzzle, puzzle.solution.skip(1));
        }
        await tester.tap(find.text('Next Level'));
        await tester.pump();
      }

      expect(
        _boardPainter(tester).puzzle.solution,
        PuzzleGenerator(
          random: math.Random(_seed),
        ).generate(PuzzleDifficulty.easy, 6).solution,
      );
      expect(progress.value.highestUnlocked(PuzzleDifficulty.easy), 6);
      await tester.tap(find.byTooltip('Level map'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Level 2, ')));
      await tester.pump();
      final levelTwo = starterPuzzleFor(2)!;
      await _tapNodes(tester, levelTwo, [levelTwo.solution[1]]);
      await tester.tap(find.byTooltip('Restart puzzle'));
      await tester.pump();
      expect(_boardPainter(tester).puzzle.solution, levelTwo.solution);
      expect(find.text('1/9'), findsOneWidget);
      expect(progress.value.highestUnlocked(PuzzleDifficulty.easy), 6);
      await tester.tap(find.text('Normal'));
      await tester.pump();
      expect(find.text('1/25'), findsOneWidget);
      expect(_boardPainter(tester).guideTarget, isNull);
    },
  );

  testWidgets('CrazyGames replay keeps saved album and best progress', (
    tester,
  ) async {
    const savedShape = [100, 200, 300, 400, 500, 600, 600, 600];
    final progress = MemorySkyProgressStore(
      const SkyProgress(
        totalXp: 420,
        selectedTheme: SkyTheme.aurora,
        bestLevels: {PuzzleDifficulty.easy: 8},
        levelStars: {
          PuzzleDifficulty.easy: {1: 3, 8: 2},
        },
        album: {'easy:1': savedShape},
      ),
    );
    await _pump(
      tester,
      _FakePlatform(),
      const _UnusedTutorial(),
      useStarterPuzzles: true,
      progressStore: progress,
    );
    final puzzle = starterPuzzleFor(1)!;
    await _tapNodes(tester, puzzle, puzzle.solution.skip(1));

    expect(progress.value.album['easy:1'], savedShape);
    expect(progress.value.bestLevel(PuzzleDifficulty.easy), 8);
    expect(progress.value.starsFor(PuzzleDifficulty.easy, 1), 3);
    expect(progress.value.starsFor(PuzzleDifficulty.easy, 8), 2);
    expect(progress.value.totalXp, 470);
    expect(progress.value.selectedTheme, SkyTheme.aurora);
  });

  testWidgets('background time never counts toward a solve', (tester) async {
    final watch = Stopwatch();
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true), stopwatch: watch);
    expect(watch.isRunning, isTrue);
    addTearDown(() => _setLifecycle(tester, AppLifecycleState.resumed));
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    expect(watch.isRunning, isFalse);
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(watch.isRunning, isTrue);
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(watch.isRunning, isFalse);
    _setLifecycle(tester, AppLifecycleState.hidden);
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(
      watch.isRunning,
      isFalse,
      reason: 'resume must not time the tutorial',
    );
  });

  testWidgets('background pauses once and resume respects overlays', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    expect(platform.events, ['start']);
    addTearDown(() => _setLifecycle(tester, AppLifecycleState.resumed));
    _setLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    expect(platform.events, ['start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start']);
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, [
      'start',
      'stop',
      'start',
      'stop',
    ], reason: 'an open tutorial stays stopped after resume');
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);
  });

  testWidgets('gameplay starts once the stored tutorial flag is read', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    expect(platform.events, <String>['start']);
  });

  testWidgets('first launch starts gameplay only after the tutorial closes', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial());
    expect(find.text('How to play'), findsOneWidget);
    expect(platform.events, isEmpty);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, <String>['start']);
  });

  testWidgets('reopening the tutorial stops and closing it restarts', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('new puzzle while playing is not a transition', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));

    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pump();
    expect(platform.events, <String>['start']);
  });

  testWidgets('level complete stops and next level starts', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));

    await _solve(tester);
    expect(find.text('Next Level'), findsOneWidget);
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Next Level'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('new puzzle after completion starts, tutorial toggle is quiet', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _solve(tester);
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('leaderboard offer follows the platform', (tester) async {
    for (final allowed in <bool>[true, false]) {
      final platform = _FakePlatform(allowsResultRegistration: allowed);
      await _pump(tester, platform, _Tutorial(seen: true));
      await _solve(tester);
      expect(find.text('기록을 등록할까요?'), allowed ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

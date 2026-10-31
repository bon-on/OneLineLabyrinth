import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryBestLevelStore extends BestLevelStore {
  final Map<String, int> saved = {};

  @override
  Future<Map<String, int>> load(Iterable<String> difficultyNames) async => {
    for (final name in difficultyNames) name: saved[name] ?? 0,
  };

  @override
  Future<void> save(String difficultyName, int level) async {
    saved[difficultyName] = math.max(saved[difficultyName] ?? 0, level);
  }
}

class _SeenTutorialStore extends TutorialStore {
  const _SeenTutorialStore();

  @override
  Future<bool> isSeen() async => true;
}

const _seed = 3;

GridPuzzle _expectedPuzzle() => PuzzleGenerator(
  random: math.Random(_seed),
).generate(PuzzleDifficulty.easy, 1);

Offset _nodePosition(WidgetTester tester, GridPuzzle puzzle, int index) {
  final board = find.byKey(const ValueKey('board'));
  final topLeft = tester.getTopLeft(board);
  final side = tester.getSize(board).shortestSide;
  final node = puzzle.nodes[index];
  return topLeft + Offset(node.x * side, node.y * side);
}

Future<void> _pumpGame(WidgetTester tester, Size size, BestLevelStore store) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: store,
      tutorialStore: const _SeenTutorialStore(),
    ),
  );
}

void main() {
  testWidgets('One Line Labyrinth renders the game board', (tester) async {
    await _pumpGame(tester, const Size(390, 844), _MemoryBestLevelStore());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('One Line Labyrinth'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 720)]) {
    testWidgets('layout fits without overflow at $size', (tester) async {
      await _pumpGame(tester, size, _MemoryBestLevelStore());
      await tester.pump();

      expect(tester.takeException(), isNull);
      final board = tester.getRect(find.byKey(const ValueKey('board')));
      expect(board.width, greaterThan(300));
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.top, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(size.width));
      expect(board.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('tapping the solution completes the level and saves best', (
    tester,
  ) async {
    final store = _MemoryBestLevelStore();
    await _pumpGame(tester, const Size(390, 844), store);
    await tester.pump();
    final puzzle = _expectedPuzzle();

    // Tapping the previous knot undoes one step.
    await tester.tapAt(_nodePosition(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
    await tester.tapAt(_nodePosition(tester, puzzle, puzzle.solution[0]));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);

    for (final index in puzzle.solution.skip(1)) {
      await tester.tapAt(_nodePosition(tester, puzzle, index));
      await tester.pump();
    }
    await tester.pump();

    expect(find.text('Next Level'), findsOneWidget);
    expect(find.text('기록을 등록할까요?'), findsOneWidget);
    expect(store.saved['easy'], 1);
  });

  testWidgets('dragging across knots draws the path', (tester) async {
    await _pumpGame(tester, const Size(1280, 720), _MemoryBestLevelStore());
    await tester.pump();
    final puzzle = _expectedPuzzle();

    final gesture = await tester.startGesture(
      _nodePosition(tester, puzzle, puzzle.solution[0]),
    );
    for (final index in puzzle.solution.skip(1).take(5)) {
      final from = _nodePosition(
        tester,
        puzzle,
        puzzle.solution[puzzle.solution.indexOf(index) - 1],
      );
      final to = _nodePosition(tester, puzzle, index);
      for (var step = 1; step <= 4; step++) {
        await gesture.moveTo(Offset.lerp(from, to, step / 4)!);
        await tester.pump();
      }
    }
    await gesture.up();
    await tester.pump();

    expect(find.text('6/${puzzle.nodeCount}'), findsOneWidget);
  });

  testWidgets('dragging back onto the previous knot undoes a step', (
    tester,
  ) async {
    await _pumpGame(tester, const Size(390, 844), _MemoryBestLevelStore());
    await tester.pump();
    final puzzle = _expectedPuzzle();
    Offset at(int i) => _nodePosition(tester, puzzle, puzzle.solution[i]);

    final gesture = await tester.startGesture(at(0));
    for (final (from, to) in [(0, 1), (1, 2), (2, 1)]) {
      for (var step = 1; step <= 4; step++) {
        await gesture.moveTo(Offset.lerp(at(from), at(to), step / 4)!);
        await tester.pump();
      }
    }
    await gesture.up();
    await tester.pump();

    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
  });

  testWidgets('reset clears the line and new puzzle deals a fresh board', (
    tester,
  ) async {
    await _pumpGame(tester, const Size(390, 844), _MemoryBestLevelStore());
    await tester.pump();
    final puzzle = _expectedPuzzle();

    // Reset with only the start knot does not count as a try.
    await tester.tap(find.byTooltip('Reset path'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    await tester.tapAt(_nodePosition(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    await tester.tap(find.byTooltip('Reset path'));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tapAt(_nodePosition(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('stored best level appears in the HUD', (tester) async {
    SharedPreferences.setMockInitialValues({
      'best_level_easy': 7,
      TutorialStore.key: true,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OneLineLabyrinthApp(random: math.Random(_seed)));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
  });
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTutorialStore extends TutorialStore {
  _FakeTutorialStore({this.seen = false});

  bool seen;
  int writes = 0;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
    writes++;
  }
}

class _MemoryBestLevelStore extends BestLevelStore {
  @override
  Future<Map<String, int>> load(Iterable<String> names) async => {
    for (final n in names) n: 0,
  };

  @override
  Future<void> save(String difficultyName, int level) async {}
}

const _seed = 3;

Future<void> _pump(
  WidgetTester tester,
  _FakeTutorialStore store, {
  Size size = const Size(390, 844),
  Stopwatch? stopwatch,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: _MemoryBestLevelStore(),
      tutorialStore: store,
      stopwatch: stopwatch,
    ),
  );
  await tester.pump();
}

Offset _node(WidgetTester tester, GridPuzzle puzzle, int index) {
  final board = find.byKey(const ValueKey('board'));
  final side = tester.getSize(board).shortestSide;
  final node = puzzle.nodes[index];
  return tester.getTopLeft(board) + Offset(node.x * side, node.y * side);
}

GridPuzzle get _puzzle => PuzzleGenerator(
  random: math.Random(_seed),
).generate(PuzzleDifficulty.easy, 1);

void main() {
  testWidgets('first launch shows the tutorial and blocks game input', (
    tester,
  ) async {
    await _pump(tester, _FakeTutorialStore());
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    final puzzle = _puzzle;
    await tester.tapAt(_node(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);

    await tester.tap(find.byTooltip('New puzzle'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('How to play'), findsOneWidget);
  });

  testWidgets('Next walks the steps and Play closes and stores the flag', (
    tester,
  ) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);

    for (var i = 0; i < howToPlaySteps.length - 1; i++) {
      expect(find.text(howToPlaySteps[i].text), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text(howToPlaySteps.last.text), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag', (tester) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Escape skips and keys do not reach the game', (tester) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('tutorial does not appear when already seen', (tester) async {
    await _pump(tester, _FakeTutorialStore(seen: true));
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('? reopens at step 1 without resetting the game', (tester) async {
    await _pump(tester, _FakeTutorialStore(seen: true));
    final puzzle = _puzzle;
    await tester.tapAt(_node(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
  });

  testWidgets('solve timer does not run while the tutorial is open', (
    tester,
  ) async {
    final watch = Stopwatch();
    await _pump(tester, _FakeTutorialStore(), stopwatch: watch);
    expect(watch.isRunning, isFalse);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(watch.isRunning, isTrue);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(watch.isRunning, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(watch.isRunning, isTrue);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(320, 480),
  ]) {
    testWidgets('tutorial and ? button fit without overflow at $size', (
      tester,
    ) async {
      await _pump(tester, _FakeTutorialStore(), size: size);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < howToPlaySteps.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Play'));
      await tester.pump();
      final help = find.byTooltip('How to play');
      expect(help, findsOneWidget);
      final rect = tester.getRect(help);
      expect(
        Offset.zero & size,
        predicate<Rect>(
          (r) => r.contains(rect.topLeft) && r.contains(rect.bottomRight),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('TutorialStore persists the flag and tolerates empty prefs', () async {
    SharedPreferences.setMockInitialValues({});
    const store = TutorialStore();
    expect(await store.isSeen(), isFalse);
    await store.markSeen();
    expect(await store.isSeen(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('tutorial_seen_v1'), isTrue);
  });

  testWidgets('Enter on the reopened tutorial does not press a HUD button', (
    tester,
  ) async {
    await _pump(tester, _FakeTutorialStore(seen: true));
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
  });

  testWidgets('Ctrl/Alt shortcuts and Tab are not consumed by the overlay', (
    tester,
  ) async {
    await _pump(tester, _FakeTutorialStore());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
  });

  testWidgets('Tab then Space cannot press HUD buttons behind the overlay', (
    tester,
  ) async {
    final watch = Stopwatch();
    await _pump(tester, _FakeTutorialStore(), stopwatch: watch);
    expect(watch.isRunning, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    // Space advanced the overlay (step 2) instead of pressing a HUD button.
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
    expect(watch.isRunning, isFalse);
  });

  testWidgets('board ignores taps while the seen flag is still loading', (
    tester,
  ) async {
    final gate = Completer<bool>();
    await _pump(tester, _PendingStore(gate.future));
    final puzzle = _puzzle;
    await tester.tapAt(_node(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('1/${puzzle.nodeCount}'), findsOneWidget);

    gate.complete(true);
    await tester.pump();
    await tester.pump();
    await tester.tapAt(_node(tester, puzzle, puzzle.solution[1]));
    await tester.pump();
    expect(find.text('2/${puzzle.nodeCount}'), findsOneWidget);
  });
}

class _PendingStore extends _FakeTutorialStore {
  _PendingStore(this.result);

  final Future<bool> result;

  @override
  Future<bool> isSeen() => result;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/platform/game_platform.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';

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
  TutorialStore tutorial,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: _MemoryBestLevelStore(),
      tutorialStore: tutorial,
      platform: platform,
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

void main() {
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

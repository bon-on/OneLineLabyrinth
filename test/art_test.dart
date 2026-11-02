import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/art/sky_scenery.dart';
import 'package:one_line_labyrinth/src/art/sky_theme.dart';
import 'package:one_line_labyrinth/src/art/star_art.dart';
import 'package:one_line_labyrinth/src/game/board_fx.dart';
import 'package:one_line_labyrinth/src/game/board_painter.dart';

class _KnotPainter extends CustomPainter {
  _KnotPainter(this.theme);

  final SkyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    for (final look in KnotLook.values) {
      paintKnot(
        canvas,
        Offset(20.0 + look.index * 40, 20),
        8,
        look,
        theme.palette,
        time: 1.5,
        pop: 0.5,
      );
    }
    paintRatingStar(canvas, const Offset(20, 60), 10, true, theme.palette);
    paintRatingStar(canvas, const Offset(50, 60), 10, false, theme.palette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  final puzzle = PuzzleGenerator(
    random: math.Random(3),
  ).generate(PuzzleDifficulty.hard, 1);

  test('themes unlock in order and parse safely', () {
    expect(SkyTheme.values.map((t) => t.requiredLevel), [1, 3, 6, 10]);
    expect(SkyTheme.fromName('nebula'), SkyTheme.nebula);
    expect(SkyTheme.fromName('bogus'), SkyTheme.twilight);
  });

  for (final theme in SkyTheme.values) {
    testWidgets('${theme.name}: sky, knots, board and effects paint', (
      tester,
    ) async {
      final time = ValueNotifier<double>(0);
      final drag = ValueNotifier<Offset?>(null);
      final fx = BoardFx();
      final path = puzzle.solution.take(6).toList();
      for (final n in path) {
        fx.visit(n, 0);
      }
      fx
        ..retract(puzzle.solution[6], path.last, 0)
        ..scatter(path, 0)
        ..invalid(puzzle.solution.last, 0)
        ..hint(puzzle.solution[6], 0);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SkyPainter(theme: theme, time: time),
                ),
              ),
              Center(
                child: SizedBox.square(
                  dimension: 400,
                  child: CustomPaint(
                    painter: BoardPainter(
                      puzzle: puzzle,
                      path: path,
                      candidates: puzzle.neighbors(path.last),
                      palette: theme.palette,
                      fx: fx,
                      time: time,
                      drag: drag,
                      deadEnd: true,
                      complete: false,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 260,
                height: 80,
                child: CustomPaint(painter: _KnotPainter(theme)),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: 60,
                height: 40,
                child: CustomPaint(painter: SkySwatchPainter(theme)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: ConstellationPainter(
                    points: puzzle.solution
                        .map((i) => puzzle.nodes[i])
                        .toList(),
                    palette: theme.palette,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: ConstellationPainter(
                    points: const [],
                    palette: theme.palette,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      for (final t in [0.1, 0.3, 1.0, 9.4]) {
        time.value = t;
        drag.value = const Offset(100, 100);
        await tester.pump();
      }
      // Completion: wave, burst and banner.
      fx.complete(puzzle.solution, 10);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(400, 400),
            painter: BoardPainter(
              puzzle: puzzle,
              path: puzzle.solution,
              candidates: const {},
              palette: theme.palette,
              fx: fx,
              time: time,
              drag: drag,
              deadEnd: false,
              complete: true,
              name: 'The Lantern',
            ),
          ),
        ),
      );
      for (final t in [10.5, 11.5, 12.5, 16.0]) {
        time.value = t;
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('BoardFx prunes expired effects but keeps completion', () {
    final fx = BoardFx()
      ..visit(1, 0)
      ..invalid(2, 0)
      ..hint(3, 0)
      ..complete(const [0, 1, 2], 0);
    expect(fx.hintNode(0.1), isNull, reason: 'completion ends hints');
    fx.hint(3, 0);
    expect(fx.hintNode(1), 3);
    fx.prune(10);
    expect(fx.events.map((e) => e.kind), [FxKind.complete]);
    expect(fx.hintNode(10), isNull);
    fx.clear();
    expect(fx.events, isEmpty);
    expect(fx.completedAt, isNull);
  });
}

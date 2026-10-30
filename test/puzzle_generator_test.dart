import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';

double _cross(
  math.Point<double> o,
  math.Point<double> a,
  math.Point<double> b,
) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Proper intersection test for segments that share no endpoint.
bool _segmentsCross(
  math.Point<double> p1,
  math.Point<double> p2,
  math.Point<double> q1,
  math.Point<double> q2,
) {
  final d1 = _cross(q1, q2, p1);
  final d2 = _cross(q1, q2, p2);
  final d3 = _cross(p1, p2, q1);
  final d4 = _cross(p1, p2, q2);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

Iterable<(PuzzleDifficulty, int, int)> _cases() sync* {
  for (final difficulty in PuzzleDifficulty.values) {
    for (final level in [1, 2, 3, 5, 8, 20]) {
      for (var seed = 0; seed < 12; seed++) {
        yield (difficulty, level, seed);
      }
    }
  }
}

void main() {
  test('solution visits every knot once over orthogonal neighbours', () {
    for (final (difficulty, level, seed) in _cases()) {
      final puzzle = PuzzleGenerator(
        random: math.Random(seed),
      ).generate(difficulty, level);
      final reason = '$difficulty level $level seed $seed';
      expect(puzzle.solution.length, puzzle.nodeCount, reason: reason);
      expect(puzzle.solution.toSet().length, puzzle.nodeCount, reason: reason);
      for (var i = 0; i + 1 < puzzle.solution.length; i++) {
        final a = puzzle.solution[i];
        final b = puzzle.solution[i + 1];
        expect(puzzle.areOrthogonalNeighbors(a, b), isTrue, reason: reason);
        expect(puzzle.edges, contains(PuzzleEdge(a, b)), reason: reason);
      }
    }
  });

  test('start and finish are the solution ends', () {
    final puzzle = PuzzleGenerator(
      random: math.Random(7),
    ).generate(PuzzleDifficulty.normal, 1);
    expect(puzzle.start, puzzle.solution.first);
    expect(puzzle.finish, puzzle.solution.last);
    expect(puzzle.start, isNot(puzzle.finish));
  });

  test('every edge joins grid neighbours and no two edges cross', () {
    for (final (difficulty, level, seed) in _cases()) {
      final puzzle = PuzzleGenerator(
        random: math.Random(seed),
      ).generate(difficulty, level);
      final reason = '$difficulty level $level seed $seed';
      final edges = puzzle.edges.toList();
      for (final edge in edges) {
        expect(puzzle.areGridNeighbors(edge.a, edge.b), isTrue, reason: reason);
      }
      for (var i = 0; i < edges.length; i++) {
        for (var j = i + 1; j < edges.length; j++) {
          final e = edges[i];
          final f = edges[j];
          if (e.touches(f.a) || e.touches(f.b)) continue;
          expect(
            _segmentsCross(
              puzzle.nodes[e.a],
              puzzle.nodes[e.b],
              puzzle.nodes[f.a],
              puzzle.nodes[f.b],
            ),
            isFalse,
            reason: '$reason crossing $e and $f',
          );
        }
      }
    }
  });

  test('harder difficulties add more branching', () {
    double branching(PuzzleDifficulty difficulty) {
      var decoys = 0;
      for (var seed = 0; seed < 20; seed++) {
        final puzzle = PuzzleGenerator(
          random: math.Random(seed),
        ).generate(difficulty, 1);
        decoys += puzzle.edges.length - (puzzle.nodeCount - 1);
      }
      return decoys / 20;
    }

    final easy = branching(PuzzleDifficulty.easy);
    final normal = branching(PuzzleDifficulty.normal);
    final hard = branching(PuzzleDifficulty.hard);
    expect(easy, greaterThan(2));
    expect(normal, greaterThan(easy));
    expect(hard, greaterThan(normal));
  });

  test('generation is deterministic for a seed', () {
    final first = PuzzleGenerator(
      random: math.Random(42),
    ).generate(PuzzleDifficulty.hard, 4);
    final second = PuzzleGenerator(
      random: math.Random(42),
    ).generate(PuzzleDifficulty.hard, 4);
    expect(first.solution, second.solution);
    expect(first.edges, second.edges);
    expect(first.nodes, second.nodes);
  });

  test('grid grows with level and respects the cap', () {
    expect(PuzzleDifficulty.easy.columnsFor(1), 4);
    expect(PuzzleDifficulty.easy.rowsFor(1), 4);
    expect(PuzzleDifficulty.easy.columnsFor(3), 5);
    expect(PuzzleDifficulty.easy.rowsFor(3), 4);
    expect(PuzzleDifficulty.easy.rowsFor(5), 5);
    expect(PuzzleDifficulty.hard.columnsFor(100), 7);
    expect(PuzzleDifficulty.hard.rowsFor(100), 7);
  });

  test('generation terminates quickly for all difficulties', () {
    final watch = Stopwatch()..start();
    for (final difficulty in PuzzleDifficulty.values) {
      for (var seed = 0; seed < 50; seed++) {
        PuzzleGenerator(random: math.Random(seed)).generate(difficulty, 99);
      }
    }
    watch.stop();
    // 150 max-size puzzles; each should take well under 20ms.
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });
}

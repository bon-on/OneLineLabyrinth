import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/game/starter_puzzles.dart';

void main() {
  test('the campaign has five boards with increasing branching', () {
    const starCounts = [6, 9, 12, 12, 16];
    const decoyCounts = [0, 1, 2, 4, 6];

    expect(starterPuzzleFor(0), isNull);
    expect(starterPuzzleFor(6), isNull);

    for (var i = 0; i < starCounts.length; i++) {
      final level = i + 1;
      final reason = 'level $level';
      final puzzle = starterPuzzleFor(level)!;
      final replay = starterPuzzleFor(level)!;
      final solution = puzzle.solution;

      expect(puzzle.nodeCount, starCounts[i], reason: reason);
      expect(puzzle.nodes.toSet().length, puzzle.nodeCount, reason: reason);
      expect(solution, hasLength(puzzle.nodeCount), reason: reason);
      expect(solution.toSet(), {
        for (var node = 0; node < puzzle.nodeCount; node++) node,
      }, reason: reason);
      expect(
        puzzle.edges.length,
        solution.length - 1 + decoyCounts[i],
        reason: reason,
      );
      expect(
        puzzle.edges.every(
          (edge) => puzzle.areOrthogonalNeighbors(edge.a, edge.b),
        ),
        isTrue,
        reason: reason,
      );
      expect(
        _countSolutions(puzzle, puzzle.start, {puzzle.start}),
        1,
        reason: reason,
      );

      for (var step = 1; step < solution.length; step++) {
        expect(
          puzzle.neighbors(solution[step - 1]),
          contains(solution[step]),
          reason: reason,
        );
      }
      expect(replay.nodes, puzzle.nodes, reason: reason);
      expect(replay.edges, puzzle.edges, reason: reason);
      expect(replay.solution, solution, reason: reason);
    }
  });

  test('the third board has a shortcut with a one-step recovery', () {
    final puzzle = starterPuzzleFor(3)!;
    final visited = puzzle.solution.take(5).toSet();
    final junction = visited.last;
    final ring = puzzle.finish;
    final correctNext = puzzle.solution[5];

    expect(
      puzzle.neighbors(junction).difference(visited),
      unorderedEquals([ring, correctNext]),
    );
    expect(_countSolutions(puzzle, ring, {...visited, ring}), 0);
    expect(puzzle.neighbors(ring), contains(junction));
  });
}

int _countSolutions(GridPuzzle puzzle, int current, Set<int> visited) {
  if (current == puzzle.finish) {
    return visited.length == puzzle.nodeCount ? 1 : 0;
  }
  var count = 0;
  for (final next in puzzle.neighbors(current).difference(visited)) {
    count += _countSolutions(puzzle, next, {...visited, next});
  }
  return count;
}

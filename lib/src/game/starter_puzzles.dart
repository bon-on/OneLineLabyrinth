import 'dart:math' as math;

import '../../puzzle_generator.dart';

/// The authored Easy levels used at the start of the CrazyGames campaign.
GridPuzzle? starterPuzzleFor(int level) {
  return switch (level) {
    // A single route teaches how to connect stars and finish on the ring.
    1 => _buildPuzzle(3, 2, const [0, 1, 2, 5, 4, 3]),
    // One extra link introduces the first route choice.
    2 => _buildPuzzle(
      3,
      3,
      const [0, 1, 2, 5, 4, 3, 6, 7, 8],
      const [PuzzleEdge(1, 4)],
    ),
    // The shortcut from 7 to the ring at 11 can be undone in one step.
    3 => _buildPuzzle(
      4,
      3,
      const [0, 1, 2, 3, 7, 6, 5, 4, 8, 9, 10, 11],
      const [PuzzleEdge(1, 5), PuzzleEdge(7, 11)],
    ),
    // More choices on the same grid teach planning without shrinking the stars.
    4 => _buildPuzzle(
      4,
      3,
      const [0, 4, 8, 9, 5, 1, 2, 3, 7, 6, 10, 11],
      const [
        PuzzleEdge(0, 1),
        PuzzleEdge(2, 6),
        PuzzleEdge(4, 5),
        PuzzleEdge(5, 6),
      ],
    ),
    5 => _buildPuzzle(
      4,
      4,
      const [0, 1, 2, 3, 7, 6, 5, 4, 8, 12, 13, 9, 10, 14, 15, 11],
      const [
        PuzzleEdge(0, 4),
        PuzzleEdge(1, 5),
        PuzzleEdge(2, 6),
        PuzzleEdge(5, 9),
        PuzzleEdge(8, 9),
        PuzzleEdge(10, 11),
      ],
    ),
    _ => null,
  };
}

GridPuzzle _buildPuzzle(
  int columns,
  int rows,
  List<int> solution, [
  List<PuzzleEdge> decoys = const [],
]) {
  final cell = 1 / math.max(columns, rows);
  final left = (1 - columns * cell) / 2;
  final top = (1 - rows * cell) / 2;
  return GridPuzzle(
    columns: columns,
    rows: rows,
    nodes: [
      for (var row = 0; row < rows; row++)
        for (var column = 0; column < columns; column++)
          math.Point(left + (column + 0.5) * cell, top + (row + 0.5) * cell),
    ],
    edges: {
      for (var i = 1; i < solution.length; i++)
        PuzzleEdge(solution[i - 1], solution[i]),
      ...decoys,
    },
    solution: solution,
  );
}

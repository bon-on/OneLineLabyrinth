/// Widget-free puzzle generation for One Line Labyrinth.
///
/// Knots sit on a jittered grid. The solution is a Hamiltonian path over
/// orthogonal grid neighbours (a serpentine path randomized with backbite
/// moves). Decoy edges only join grid neighbours, so edges never cross, and
/// harder difficulties keep more of them to create real branching decisions.
library;

import 'dart:math' as math;

/// Difficulty presets for puzzle generation.
enum PuzzleDifficulty {
  easy(
    label: 'Easy',
    baseSize: 4,
    maxSize: 5,
    decoyFraction: 0.45,
    diagonalFraction: 0,
  ),
  normal(
    label: 'Normal',
    baseSize: 5,
    maxSize: 6,
    decoyFraction: 0.7,
    diagonalFraction: 0,
  ),
  hard(
    label: 'Hard',
    baseSize: 6,
    maxSize: 7,
    decoyFraction: 0.9,
    diagonalFraction: 0.2,
  );

  const PuzzleDifficulty({
    required this.label,
    required this.baseSize,
    required this.maxSize,
    required this.decoyFraction,
    required this.diagonalFraction,
  });

  final String label;

  /// Grid size (columns and rows) at level 1.
  final int baseSize;

  /// Largest grid size reachable by levelling up.
  final int maxSize;

  /// Share of non-solution orthogonal neighbour pairs that become decoys.
  final double decoyFraction;

  /// Share of grid cells that receive one diagonal decoy.
  final double diagonalFraction;

  /// Grid columns for [level]: one more column, then one more row, every
  /// two levels, capped at [maxSize].
  int columnsFor(int level) {
    final steps = (math.max(1, level) - 1) ~/ 2;
    return math.min(maxSize, baseSize + (steps + 1) ~/ 2);
  }

  /// Grid rows for [level]. See [columnsFor].
  int rowsFor(int level) {
    final steps = (math.max(1, level) - 1) ~/ 2;
    return math.min(maxSize, baseSize + steps ~/ 2);
  }
}

/// An undirected edge between two knot indices, stored as `a < b`.
class PuzzleEdge {
  const PuzzleEdge(int first, int second)
    : a = first < second ? first : second,
      b = first < second ? second : first;

  final int a;
  final int b;

  bool touches(int index) => a == index || b == index;

  int other(int index) => index == a ? b : a;

  @override
  bool operator ==(Object other) =>
      other is PuzzleEdge && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'PuzzleEdge($a, $b)';
}

/// A generated puzzle. Knot `i` sits at grid cell
/// `(column: i % columns, row: i ~/ columns)`.
class GridPuzzle {
  GridPuzzle({
    required this.columns,
    required this.rows,
    required this.nodes,
    required this.edges,
    required this.solution,
  }) : _adjacency = _buildAdjacency(columns * rows, edges);

  final int columns;
  final int rows;

  /// Knot positions normalized to the unit square.
  final List<math.Point<double>> nodes;
  final Set<PuzzleEdge> edges;

  /// One valid Hamiltonian path; its ends are [start] and [finish].
  final List<int> solution;
  final List<Set<int>> _adjacency;

  int get start => solution.first;
  int get finish => solution.last;
  int get nodeCount => nodes.length;

  Set<int> neighbors(int index) => _adjacency[index];

  int columnOf(int index) => index % columns;
  int rowOf(int index) => index ~/ columns;

  /// Whether two knots are orthogonal or diagonal grid neighbours.
  bool areGridNeighbors(int first, int second) {
    if (first == second) return false;
    final dc = (columnOf(first) - columnOf(second)).abs();
    final dr = (rowOf(first) - rowOf(second)).abs();
    return dc <= 1 && dr <= 1;
  }

  /// Whether two knots share a grid side.
  bool areOrthogonalNeighbors(int first, int second) {
    final dc = (columnOf(first) - columnOf(second)).abs();
    final dr = (rowOf(first) - rowOf(second)).abs();
    return dc + dr == 1;
  }

  static List<Set<int>> _buildAdjacency(int count, Set<PuzzleEdge> edges) {
    final adjacency = List<Set<int>>.generate(count, (_) => <int>{});
    for (final edge in edges) {
      adjacency[edge.a].add(edge.b);
      adjacency[edge.b].add(edge.a);
    }
    return adjacency;
  }
}

/// Generates puzzles deterministically from the injected [random].
class PuzzleGenerator {
  PuzzleGenerator({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Maximum knot offset from its cell centre, as a fraction of a cell.
  /// Kept below 0.25 so every grid cell stays convex and edges cannot cross.
  static const double jitter = 0.12;

  GridPuzzle generate(PuzzleDifficulty difficulty, int level) {
    final columns = difficulty.columnsFor(level);
    final rows = difficulty.rowsFor(level);
    final nodes = _buildNodes(columns, rows);
    final solution = _hamiltonianPath(columns, rows);
    final edges = <PuzzleEdge>{
      for (var i = 0; i + 1 < solution.length; i++)
        PuzzleEdge(solution[i], solution[i + 1]),
    };
    _addDecoys(difficulty, columns, rows, solution, edges);
    return GridPuzzle(
      columns: columns,
      rows: rows,
      nodes: nodes,
      edges: edges,
      solution: solution,
    );
  }

  List<math.Point<double>> _buildNodes(int columns, int rows) {
    final cell = 1 / math.max(columns, rows);
    final originX = (1 - columns * cell) / 2;
    final originY = (1 - rows * cell) / 2;
    double offset() => (_random.nextDouble() * 2 - 1) * jitter * cell;
    return [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < columns; c++)
          math.Point<double>(
            originX + (c + 0.5) * cell + offset(),
            originY + (r + 0.5) * cell + offset(),
          ),
    ];
  }

  /// A random Hamiltonian path over orthogonal grid neighbours.
  ///
  /// Starts from a serpentine path and applies backbite moves, each of which
  /// keeps the path Hamiltonian. Runs in O(moves * nodes) and always
  /// terminates.
  List<int> _hamiltonianPath(int columns, int rows) {
    final count = columns * rows;
    var path = <int>[
      for (var r = 0; r < rows; r++)
        for (var i = 0; i < columns; i++)
          r * columns + (r.isEven ? i : columns - 1 - i),
    ];
    if (_random.nextBool()) path = _columnSerpentine(columns, rows);
    final moves = count * 30;
    for (var m = 0; m < moves; m++) {
      if (_random.nextBool()) path = path.reversed.toList();
      final end = path.last;
      final beforeEnd = path[path.length - 2];
      final options = _orthogonalNeighbors(
        end,
        columns,
        rows,
      ).where((n) => n != beforeEnd).toList();
      if (options.isEmpty) continue;
      final target = options[_random.nextInt(options.length)];
      final i = path.indexOf(target);
      path = [...path.sublist(0, i + 1), ...path.sublist(i + 1).reversed];
    }
    return path;
  }

  /// A column-by-column serpentine path, for more varied starting shapes.
  List<int> _columnSerpentine(int columns, int rows) {
    return [
      for (var c = 0; c < columns; c++)
        for (var i = 0; i < rows; i++)
          (c.isEven ? i : rows - 1 - i) * columns + c,
    ];
  }

  Iterable<int> _orthogonalNeighbors(int index, int columns, int rows) sync* {
    final c = index % columns;
    final r = index ~/ columns;
    if (c > 0) yield index - 1;
    if (c + 1 < columns) yield index + 1;
    if (r > 0) yield index - columns;
    if (r + 1 < rows) yield index + columns;
  }

  void _addDecoys(
    PuzzleDifficulty difficulty,
    int columns,
    int rows,
    List<int> solution,
    Set<PuzzleEdge> edges,
  ) {
    final count = columns * rows;
    final position = List<int>.filled(count, 0);
    for (var i = 0; i < solution.length; i++) {
      position[solution[i]] = i;
    }

    // Trap weight: a decoy that skips far along the solution leads into a
    // dead end, and decoys early in the path force decisions sooner.
    double weight(PuzzleEdge edge) {
      final pa = position[edge.a];
      final pb = position[edge.b];
      final skip = (pa - pb).abs() / count;
      final early = 1 - math.min(pa, pb) / count;
      return 1 + 4 * skip + 1.5 * early;
    }

    final orthogonal = <PuzzleEdge>[
      for (var i = 0; i < count; i++)
        for (final n in _orthogonalNeighbors(i, columns, rows))
          if (n > i && !edges.contains(PuzzleEdge(i, n))) PuzzleEdge(i, n),
    ];
    final orthogonalTarget = (orthogonal.length * difficulty.decoyFraction)
        .round();
    edges.addAll(_weightedSample(orthogonal, orthogonalTarget, weight));

    if (difficulty.diagonalFraction <= 0) return;
    // At most one diagonal per cell: the two diagonals of a cell are the only
    // pair of grid-neighbour edges that can cross.
    final diagonals = <PuzzleEdge>[
      for (var r = 0; r + 1 < rows; r++)
        for (var c = 0; c + 1 < columns; c++)
          _random.nextBool()
              ? PuzzleEdge(r * columns + c, (r + 1) * columns + c + 1)
              : PuzzleEdge(r * columns + c + 1, (r + 1) * columns + c),
    ];
    final diagonalTarget = (diagonals.length * difficulty.diagonalFraction)
        .round();
    edges.addAll(_weightedSample(diagonals, diagonalTarget, weight));
  }

  /// Weighted sampling without replacement (Efraimidis-Spirakis keys).
  List<PuzzleEdge> _weightedSample(
    List<PuzzleEdge> items,
    int count,
    double Function(PuzzleEdge) weight,
  ) {
    final keyed = [
      for (final item in items)
        (
          item: item,
          key: math.pow(_random.nextDouble(), 1 / weight(item)).toDouble(),
        ),
    ]..sort((x, y) => y.key.compareTo(x.key));
    return [for (final entry in keyed.take(count)) entry.item];
  }
}

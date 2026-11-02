/// Star rating of one solved level. Pure logic; level generation is untouched.
///
/// - Star 1, Solved: always earned when the ring is reached.
/// - Star 2, Clean line: no backtrack (undo step or reset) and no hint.
/// - Star 3, Swift: solved within [parSeconds].
class LevelStars {
  const LevelStars({required this.clean, required this.swift});

  /// Rates a solve.
  factory LevelStars.rate({
    required int backtracks,
    required int hints,
    required int seconds,
    required int nodeCount,
  }) {
    return LevelStars(
      clean: backtracks <= 0 && hints <= 0,
      swift: seconds <= parSeconds(nodeCount),
    );
  }

  final bool clean;
  final bool swift;

  /// Highest number of stars a level can give.
  static const int max = 3;

  int get count => 1 + (clean ? 1 : 0) + (swift ? 1 : 0);

  /// Target time for the Swift star: 1.6 seconds per knot plus 4 seconds.
  static int parSeconds(int nodeCount) => (nodeCount * 1.6).ceil() + 4;
}

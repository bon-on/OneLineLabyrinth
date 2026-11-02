import '../../puzzle_generator.dart';

/// Names of the constellations a solved line forms.
///
/// Levels 1 to [albumLevels] of every difficulty have a fixed album slot and
/// name; later levels get a deterministic generated name and no album slot.
class Constellations {
  const Constellations._();

  /// Album levels per difficulty.
  static const int albumLevels = 12;

  /// Album slots over all difficulties.
  static int get albumSize => albumLevels * PuzzleDifficulty.values.length;

  static const List<String> _names = <String>[
    // Easy
    'The Lantern', 'Little Kite', 'Fox Trail', 'Paper Boat',
    'Sleeping Cat', 'The Teacup', 'Willow Branch', 'Firefly',
    'The Acorn', 'Snail Shell', 'Hummingbird', 'The Bell',
    // Normal
    'The Weaver', 'Silver Heron', 'Old Lighthouse', 'Twin Rivers',
    'The Compass', 'Moth Queen', 'The Harp', 'Wandering Whale',
    'Crown of Reeds', 'The Archer', 'Glass Key', 'Night Garden',
    // Hard
    'The Labyrinth', 'Iron Dragon', 'Star Loom', 'The Leviathan',
    'Crystal Spire', 'The Phoenix', 'Hollow Moon', 'The Navigator',
    'Storm Serpent', 'The Oracle', 'Eternal Knot', 'The Great Thread',
  ];

  static const List<String> _adjectives = <String>[
    'Distant', 'Silent', 'Golden', 'Drifting', 'Ancient', 'Velvet',
    'Wandering', 'Hidden', 'Bright', 'Frozen', 'Restless', 'Gentle',
  ];

  static const List<String> _nouns = <String>[
    'Heron', 'Lantern', 'Serpent', 'Harp', 'Comet', 'Crown',
    'Mariner', 'Lynx', 'Spindle', 'Orchid', 'Anchor', 'Owl',
  ];

  /// Whether ([difficulty], [level]) has an album slot.
  static bool hasSlot(int level) => level >= 1 && level <= albumLevels;

  /// Album key of a slot, also used in the saved progress.
  static String slotKey(PuzzleDifficulty difficulty, int level) =>
      '${difficulty.name}:$level';

  /// The constellation name of a level.
  static String nameFor(PuzzleDifficulty difficulty, int level) {
    if (hasSlot(level)) {
      return _names[difficulty.index * albumLevels + level - 1];
    }
    // A small deterministic hash keeps names stable between sessions.
    final seed = (difficulty.index + 1) * 7919 + level * 104729;
    final adjective = _adjectives[seed % _adjectives.length];
    final noun = _nouns[(seed ~/ _adjectives.length) % _nouns.length];
    return '$adjective $noun';
  }
}

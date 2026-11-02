import 'dart:math' as math;

import '../../puzzle_generator.dart';
import '../art/sky_theme.dart';
import 'constellations.dart';
import 'level_stars.dart';

/// Facts about one solved level, fed to [SkyProgress.applyLevel].
class LevelResult {
  const LevelResult({
    required this.difficulty,
    required this.level,
    required this.stars,
    required this.seconds,
    this.shape = const <int>[],
  });

  final PuzzleDifficulty difficulty;
  final int level;
  final LevelStars stars;
  final int seconds;

  /// The solved line as flattened `x, y` pairs in path order, each scaled to
  /// 0..[AlbumShape.scale]. Saved into the album on a first clear.
  final List<int> shape;
}

/// Result of applying a solved level to the saved progress.
class LevelOutcome {
  const LevelOutcome({
    required this.progress,
    required this.result,
    required this.name,
    required this.xpGained,
    required this.isNewBest,
    required this.previousBest,
    required this.previousStars,
    required this.firstClear,
    required this.newConstellation,
    required this.levelBefore,
    required this.levelAfter,
    required this.newlyUnlockedThemes,
  });

  final SkyProgress progress;
  final LevelResult result;

  /// Constellation name of the level.
  final String name;
  final int xpGained;

  /// The level is beyond the best level reached before in this difficulty.
  final bool isNewBest;
  final int previousBest;

  /// Best stars of this level before the solve (0 when never solved).
  final int previousStars;
  final bool firstClear;

  /// The solve filled an album slot.
  final bool newConstellation;
  final int levelBefore;
  final int levelAfter;
  final List<SkyTheme> newlyUnlockedThemes;

  bool get leveledUp => levelAfter > levelBefore;
  bool get starsImproved => result.stars.count > previousStars;
}

/// Helpers for album shapes (normalized constellation lines).
class AlbumShape {
  const AlbumShape._();

  /// Coordinates are stored as integers in 0..scale.
  static const int scale = 1000;

  /// Largest number of points a shape may hold (7x7 board).
  static const int maxPoints = 64;

  /// Encodes normalized points (0..1) to the stored integer form.
  static List<int> encode(Iterable<math.Point<double>> points) => <int>[
    for (final p in points) ...<int>[
      (p.x.clamp(0.0, 1.0) * scale).round(),
      (p.y.clamp(0.0, 1.0) * scale).round(),
    ],
  ];

  /// Decodes a stored shape back to normalized points.
  static List<math.Point<double>> decode(List<int> flat) => <math.Point<double>>[
    for (var i = 0; i + 1 < flat.length; i += 2)
      math.Point<double>(flat[i] / scale, flat[i + 1] / scale),
  ];
}

/// Saved meta progress: XP, chosen sky, best level and stars per level, and
/// the constellation album.
///
/// XP per solve = [baseXp] + [xpPerStar] per star + a difficulty bonus
/// (Normal 5, Hard 10) + [firstClearXp] the first time a level is solved.
/// A typical early solve earns 50-65 XP, a replay 40-60. Level curve: reaching
/// level L+1 costs 100 + 40 * (L - 1) XP, so Aurora (Lv3), Nebula (Lv6) and
/// Eclipse (Lv10) take roughly 5, 18 and 45 solves.
class SkyProgress {
  const SkyProgress({
    required this.totalXp,
    required this.selectedTheme,
    required this.bestLevels,
    required this.levelStars,
    required this.album,
  });

  const SkyProgress.initial()
    : totalXp = 0,
      selectedTheme = SkyTheme.twilight,
      bestLevels = const <PuzzleDifficulty, int>{},
      levelStars = const <PuzzleDifficulty, Map<int, int>>{},
      album = const <String, List<int>>{};

  static const int baseXp = 20;
  static const int xpPerStar = 10;
  static const int firstClearXp = 15;

  /// Levels above this are not stored per level (keeps the save small).
  static const int maxStoredLevel = 999;

  final int totalXp;
  final SkyTheme selectedTheme;

  /// Highest solved level per difficulty (absent: 0).
  final Map<PuzzleDifficulty, int> bestLevels;

  /// Best stars per difficulty and level (absent: never solved).
  final Map<PuzzleDifficulty, Map<int, int>> levelStars;

  /// Album shapes by [Constellations.slotKey].
  final Map<String, List<int>> album;

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 100 + 40 * (level < 1 ? 0 : level - 1);

  static int difficultyBonus(PuzzleDifficulty difficulty) =>
      switch (difficulty) {
        PuzzleDifficulty.easy => 0,
        PuzzleDifficulty.normal => 5,
        PuzzleDifficulty.hard => 10,
      };

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  int bestLevel(PuzzleDifficulty difficulty) => bestLevels[difficulty] ?? 0;

  /// Highest level the player may pick in the level map.
  int highestUnlocked(PuzzleDifficulty difficulty) => bestLevel(difficulty) + 1;

  int starsFor(PuzzleDifficulty difficulty, int level) =>
      levelStars[difficulty]?[level] ?? 0;

  int get totalStars => levelStars.values.fold(
    0,
    (sum, levels) => sum + levels.values.fold(0, (a, b) => a + b),
  );

  int get albumCount => album.length;

  bool isThemeUnlocked(SkyTheme theme) => level >= theme.requiredLevel;

  /// Returns this progress unchanged when [theme] is still locked.
  SkyProgress withTheme(SkyTheme theme) {
    if (!isThemeUnlocked(theme) || theme == selectedTheme) return this;
    return _copy(selectedTheme: theme);
  }

  /// Raises best levels to at least the [legacy] values (the pre-v1
  /// `best_level_<difficulty>` keys), so no old record is lost.
  SkyProgress withLegacyBestLevels(Map<String, int> legacy) {
    var changed = false;
    final next = Map<PuzzleDifficulty, int>.of(bestLevels);
    for (final difficulty in PuzzleDifficulty.values) {
      final old = legacy[difficulty.name] ?? 0;
      final clamped = math.min(old, maxStoredLevel);
      if (clamped > (next[difficulty] ?? 0)) {
        next[difficulty] = clamped;
        changed = true;
      }
    }
    return changed ? _copy(bestLevels: next) : this;
  }

  LevelOutcome applyLevel(LevelResult result) {
    final levelBefore = level;
    final difficulty = result.difficulty;
    final lvl = result.level.clamp(1, maxStoredLevel);
    final previousBest = bestLevel(difficulty);
    final previousStars = starsFor(difficulty, lvl);
    final firstClear = previousStars == 0;
    final stars = result.stars.count;
    final xp =
        baseXp +
        xpPerStar * stars +
        difficultyBonus(difficulty) +
        (firstClear ? firstClearXp : 0);

    final nextBest = Map<PuzzleDifficulty, int>.of(bestLevels);
    if (lvl > previousBest) nextBest[difficulty] = lvl;
    final nextStars = <PuzzleDifficulty, Map<int, int>>{
      for (final entry in levelStars.entries)
        entry.key: Map<int, int>.of(entry.value),
    };
    if (stars > previousStars) {
      (nextStars[difficulty] ??= <int, int>{})[lvl] = stars;
    }
    final key = Constellations.slotKey(difficulty, lvl);
    final newConstellation =
        Constellations.hasSlot(lvl) &&
        !album.containsKey(key) &&
        result.shape.length >= 4;
    final nextAlbum = Map<String, List<int>>.of(album);
    if (newConstellation) {
      nextAlbum[key] = List<int>.unmodifiable(
        result.shape.take(AlbumShape.maxPoints * 2),
      );
    }
    final next = _copy(
      totalXp: totalXp + xp,
      bestLevels: nextBest,
      levelStars: nextStars,
      album: nextAlbum,
    );
    final levelAfter = next.level;
    return LevelOutcome(
      progress: next,
      result: result,
      name: Constellations.nameFor(difficulty, lvl),
      xpGained: xp,
      isNewBest: lvl > previousBest,
      previousBest: previousBest,
      previousStars: previousStars,
      firstClear: firstClear,
      newConstellation: newConstellation,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newlyUnlockedThemes: <SkyTheme>[
        for (final theme in SkyTheme.values)
          if (levelBefore < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'totalXp': totalXp,
    'selectedTheme': selectedTheme.name,
    'bestLevels': <String, int>{
      for (final entry in bestLevels.entries) entry.key.name: entry.value,
    },
    'levelStars': <String, Map<String, int>>{
      for (final entry in levelStars.entries)
        entry.key.name: <String, int>{
          for (final level in entry.value.entries)
            '${level.key}': level.value,
        },
    },
    'album': album,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory SkyProgress.fromJson(Object? json) {
    if (json is! Map) return const SkyProgress.initial();
    int readInt(Object? value, {int max = 1 << 30}) =>
        value is num && value.isFinite && value >= 0
        ? math.min(value.toInt(), max)
        : 0;
    PuzzleDifficulty? difficultyOf(Object? name) {
      for (final d in PuzzleDifficulty.values) {
        if (d.name == name) return d;
      }
      return null;
    }

    final bestLevels = <PuzzleDifficulty, int>{};
    final rawBest = json['bestLevels'];
    if (rawBest is Map) {
      rawBest.forEach((key, value) {
        final d = difficultyOf(key);
        final level = readInt(value, max: maxStoredLevel);
        if (d != null && level > 0) bestLevels[d] = level;
      });
    }

    final levelStars = <PuzzleDifficulty, Map<int, int>>{};
    final rawStars = json['levelStars'];
    if (rawStars is Map) {
      rawStars.forEach((key, value) {
        final d = difficultyOf(key);
        if (d == null || value is! Map) return;
        final levels = <int, int>{};
        value.forEach((levelKey, stars) {
          final level = int.tryParse('$levelKey');
          final count = readInt(stars, max: LevelStars.max);
          if (level != null &&
              level >= 1 &&
              level <= maxStoredLevel &&
              count > 0) {
            levels[level] = count;
          }
        });
        if (levels.isNotEmpty) levelStars[d] = levels;
      });
    }

    final album = <String, List<int>>{};
    final rawAlbum = json['album'];
    if (rawAlbum is Map) {
      rawAlbum.forEach((key, value) {
        if (key is! String || value is! List) return;
        final parts = key.split(':');
        final level = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (difficultyOf(parts.first) == null ||
            level == null ||
            !Constellations.hasSlot(level)) {
          return;
        }
        final points = <int>[
          for (final v in value.take(AlbumShape.maxPoints * 2))
            readInt(v, max: AlbumShape.scale),
        ];
        if (points.length >= 4 && points.length.isEven) {
          album[key] = List<int>.unmodifiable(points);
        }
      });
    }

    final progress = SkyProgress(
      totalXp: readInt(json['totalXp']),
      selectedTheme: SkyTheme.twilight,
      bestLevels: Map.unmodifiable(bestLevels),
      levelStars: Map.unmodifiable(levelStars),
      album: Map.unmodifiable(album),
    );
    final theme = SkyTheme.fromName(
      json['selectedTheme'] is String ? json['selectedTheme'] as String : null,
    );
    return progress.withTheme(theme);
  }

  SkyProgress _copy({
    int? totalXp,
    SkyTheme? selectedTheme,
    Map<PuzzleDifficulty, int>? bestLevels,
    Map<PuzzleDifficulty, Map<int, int>>? levelStars,
    Map<String, List<int>>? album,
  }) {
    return SkyProgress(
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      bestLevels: Map.unmodifiable(bestLevels ?? this.bestLevels),
      levelStars: Map.unmodifiable(levelStars ?? this.levelStars),
      album: Map.unmodifiable(album ?? this.album),
    );
  }
}

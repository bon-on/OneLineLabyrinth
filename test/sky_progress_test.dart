import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/art/sky_theme.dart';
import 'package:one_line_labyrinth/src/meta/constellations.dart';
import 'package:one_line_labyrinth/src/meta/level_stars.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress.dart';
import 'package:one_line_labyrinth/src/meta/sky_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shape = <int>[0, 0, 500, 0, 500, 500, 1000, 1000];

LevelResult _result({
  PuzzleDifficulty difficulty = PuzzleDifficulty.easy,
  int level = 1,
  bool clean = true,
  bool swift = true,
  List<int> shape = _shape,
}) => LevelResult(
  difficulty: difficulty,
  level: level,
  stars: LevelStars(clean: clean, swift: swift),
  seconds: 10,
  shape: shape,
);

void main() {
  group('LevelStars', () {
    test('par time is 1.6 s per knot plus 4 s', () {
      expect(LevelStars.parSeconds(16), 30);
      expect(LevelStars.parSeconds(49), 83);
    });

    test('rates clean and swift solves', () {
      final perfect = LevelStars.rate(
        backtracks: 0,
        hints: 0,
        seconds: 30,
        nodeCount: 16,
      );
      expect(perfect.count, 3);
      expect(
        LevelStars.rate(
          backtracks: 1,
          hints: 0,
          seconds: 30,
          nodeCount: 16,
        ).count,
        2,
      );
      final hinted = LevelStars.rate(
        backtracks: 0,
        hints: 1,
        seconds: 31,
        nodeCount: 16,
      );
      expect(hinted.clean, isFalse);
      expect(hinted.swift, isFalse);
      expect(hinted.count, 1);
    });
  });

  group('Constellations', () {
    test('every album slot has a unique ASCII name', () {
      final names = <String>{
        for (final d in PuzzleDifficulty.values)
          for (var l = 1; l <= Constellations.albumLevels; l++)
            Constellations.nameFor(d, l),
      };
      expect(names, hasLength(Constellations.albumSize));
      for (final name in names) {
        expect(name.codeUnits.every((c) => c >= 32 && c < 127), isTrue);
      }
    });

    test('later levels get a stable generated name and no slot', () {
      expect(Constellations.hasSlot(13), isFalse);
      expect(
        Constellations.nameFor(PuzzleDifficulty.hard, 40),
        Constellations.nameFor(PuzzleDifficulty.hard, 40),
      );
      expect(Constellations.nameFor(PuzzleDifficulty.hard, 40), isNotEmpty);
    });
  });

  group('SkyProgress', () {
    test('level curve and theme unlocks', () {
      expect(SkyProgress.xpToAdvance(1), 100);
      expect(SkyProgress.xpToAdvance(3), 180);
      const p = SkyProgress.initial();
      expect(p.level, 1);
      expect(p.isThemeUnlocked(SkyTheme.twilight), isTrue);
      expect(p.isThemeUnlocked(SkyTheme.aurora), isFalse);
      final lv3 = SkyProgress.fromJson({'totalXp': 240});
      expect(lv3.level, 3);
      expect(lv3.xpIntoLevel, 0);
      expect(lv3.isThemeUnlocked(SkyTheme.aurora), isTrue);
      expect(lv3.isThemeUnlocked(SkyTheme.nebula), isFalse);
    });

    test('a first perfect clear gives XP, stars, best and an album entry', () {
      final outcome = const SkyProgress.initial().applyLevel(_result());
      expect(outcome.xpGained, 20 + 30 + 15);
      expect(outcome.isNewBest, isTrue);
      expect(outcome.firstClear, isTrue);
      expect(outcome.newConstellation, isTrue);
      expect(outcome.name, 'The Lantern');
      final p = outcome.progress;
      expect(p.bestLevel(PuzzleDifficulty.easy), 1);
      expect(p.highestUnlocked(PuzzleDifficulty.easy), 2);
      expect(p.starsFor(PuzzleDifficulty.easy, 1), 3);
      expect(p.album[Constellations.slotKey(PuzzleDifficulty.easy, 1)], _shape);
      expect(p.totalStars, 3);
    });

    test('replays keep the best stars and the first album shape', () {
      final first = const SkyProgress.initial()
          .applyLevel(_result(clean: false, swift: false))
          .progress;
      expect(first.starsFor(PuzzleDifficulty.easy, 1), 1);
      final second = first.applyLevel(
        _result(shape: const <int>[1, 1, 2, 2, 3, 3]),
      );
      expect(second.firstClear, isFalse);
      expect(second.newConstellation, isFalse);
      expect(second.isNewBest, isFalse);
      expect(second.starsImproved, isTrue);
      expect(second.xpGained, 20 + 30);
      expect(second.progress.starsFor(PuzzleDifficulty.easy, 1), 3);
      expect(second.progress.album.values.single, _shape);
      final third = second.progress.applyLevel(_result(clean: false));
      expect(third.progress.starsFor(PuzzleDifficulty.easy, 1), 3);
    });

    test('difficulty bonus and level 13+ has no album slot', () {
      final outcome = const SkyProgress.initial().applyLevel(
        _result(difficulty: PuzzleDifficulty.hard, level: 13),
      );
      expect(outcome.xpGained, 20 + 30 + 10 + 15);
      expect(outcome.newConstellation, isFalse);
      expect(outcome.progress.album, isEmpty);
      expect(outcome.progress.bestLevel(PuzzleDifficulty.hard), 13);
    });

    test('level ups report newly unlocked themes', () {
      final p = SkyProgress.fromJson({'totalXp': 230});
      final outcome = p.applyLevel(_result());
      expect(outcome.leveledUp, isTrue);
      expect(outcome.levelAfter, 3);
      expect(outcome.newlyUnlockedThemes, [SkyTheme.aurora]);
    });

    test('locked themes cannot be selected', () {
      const p = SkyProgress.initial();
      expect(p.withTheme(SkyTheme.eclipse).selectedTheme, SkyTheme.twilight);
      final rich = SkyProgress.fromJson({'totalXp': 100000});
      expect(rich.withTheme(SkyTheme.eclipse).selectedTheme, SkyTheme.eclipse);
    });

    test('legacy best levels are merged without loss', () {
      final p = SkyProgress.fromJson({
        'bestLevels': {'easy': 4, 'normal': 9},
      });
      final merged = p.withLegacyBestLevels({'easy': 7, 'normal': 2});
      expect(merged.bestLevel(PuzzleDifficulty.easy), 7);
      expect(merged.bestLevel(PuzzleDifficulty.normal), 9);
      expect(merged.bestLevel(PuzzleDifficulty.hard), 0);
      expect(identical(merged.withLegacyBestLevels({'easy': 3}), merged), isTrue);
    });

    test('JSON round trip', () {
      var p = SkyProgress.fromJson({'totalXp': 5000});
      p = p.applyLevel(_result(level: 2)).progress;
      p = p.applyLevel(_result(difficulty: PuzzleDifficulty.normal)).progress;
      p = p.withTheme(SkyTheme.nebula);
      final back = SkyProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(jsonEncode(back.toJson()), jsonEncode(p.toJson()));
      expect(back.selectedTheme, SkyTheme.nebula);
      expect(back.starsFor(PuzzleDifficulty.normal, 1), 3);
      expect(back.albumCount, 2);
    });

    test('corrupt fields fall back one by one', () {
      final p = SkyProgress.fromJson({
        'totalXp': 'lots',
        'selectedTheme': 'eclipse',
        'bestLevels': {'easy': -3, 'normal': 5, 'nope': 9},
        'levelStars': {
          'easy': {'1': 9, 'x': 2, '0': 1},
          'hard': 'bad',
        },
        'album': {
          'easy:1': [1, 2, 3],
          'easy:2': [0, 0, 2000, 10],
          'easy:40': [0, 0, 1, 1],
          'moon:1': [0, 0, 1, 1],
        },
      });
      expect(p.totalXp, 0);
      // Eclipse is locked at level 1.
      expect(p.selectedTheme, SkyTheme.twilight);
      expect(p.bestLevel(PuzzleDifficulty.easy), 0);
      expect(p.bestLevel(PuzzleDifficulty.normal), 5);
      expect(p.starsFor(PuzzleDifficulty.easy, 1), 3);
      expect(p.levelStars[PuzzleDifficulty.easy]!.length, 1);
      expect(p.album.keys, ['easy:2']);
      expect(p.album['easy:2'], [0, 0, 1000, 10]);
      expect(SkyProgress.fromJson('garbage').totalXp, 0);
      expect(SkyProgress.fromJson(null).level, 1);
    });

    test('AlbumShape encodes and decodes points', () {
      final flat = AlbumShape.encode([
        const math.Point(0.25, 0.5),
        const math.Point(1.2, -1),
      ]);
      expect(flat, [250, 500, 1000, 0]);
      expect(AlbumShape.decode(flat).first, const math.Point(0.25, 0.5));
    });
  });

  group('SkyProgressStore', () {
    test('saves and loads under labyrinth_progress_v1', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SkyProgressStore();
      final p = const SkyProgress.initial().applyLevel(_result()).progress;
      await store.save(p);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SkyProgressStore.progressKey), isNotNull);
      final loaded = await store.load();
      expect(loaded.starsFor(PuzzleDifficulty.easy, 1), 3);
    });

    test('missing or corrupt values load the initial progress', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await const SkyProgressStore().load()).totalXp, 0);
      SharedPreferences.setMockInitialValues({
        SkyProgressStore.progressKey: '{not json',
      });
      expect((await const SkyProgressStore().load()).totalXp, 0);
      SharedPreferences.setMockInitialValues({
        SkyProgressStore.progressKey: '[1,2]',
      });
      expect((await const SkyProgressStore().load()).level, 1);
    });
  });
}

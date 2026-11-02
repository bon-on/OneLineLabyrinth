import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sky_progress.dart';

/// Persists [SkyProgress] as a JSON string under [progressKey].
///
/// Storage failures never break play: a read failure or corrupt value loads
/// the initial progress and a write failure is ignored. The legacy
/// `best_level_<difficulty>` keys stay with `BestLevelStore` and are merged in
/// by the game screen.
class SkyProgressStore {
  const SkyProgressStore();

  static const String progressKey = 'labyrinth_progress_v1';

  Future<SkyProgress> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw == null) return const SkyProgress.initial();
      return SkyProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      return const SkyProgress.initial();
    }
  }

  Future<void> save(SkyProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {
      // Progress is a convenience; ignore storage errors.
    }
  }
}

/// In-memory store for tests.
class MemorySkyProgressStore extends SkyProgressStore {
  MemorySkyProgressStore([this.value = const SkyProgress.initial()]);

  SkyProgress value;
  int saveCount = 0;

  @override
  Future<SkyProgress> load() async => value;

  @override
  Future<void> save(SkyProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}

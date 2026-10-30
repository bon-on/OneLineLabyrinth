import 'package:shared_preferences/shared_preferences.dart';

/// Persists the highest completed level per difficulty.
///
/// Storage failures (for example when the platform plugin is unavailable)
/// are swallowed so gameplay never depends on local storage.
class BestLevelStore {
  static const String _prefix = 'best_level_';

  static String keyFor(String difficultyName) => '$_prefix$difficultyName';

  Future<Map<String, int>> load(Iterable<String> difficultyNames) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final name in difficultyNames)
          name: prefs.getInt(keyFor(name)) ?? 0,
      };
    } catch (_) {
      return {for (final name in difficultyNames) name: 0};
    }
  }

  Future<void> save(String difficultyName, int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(keyFor(difficultyName)) ?? 0;
      if (level > current) {
        await prefs.setInt(keyFor(difficultyName), level);
      }
    } catch (_) {
      // Best levels are a convenience; ignore storage errors.
    }
  }
}

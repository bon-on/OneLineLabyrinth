import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves only higher levels and loads them back', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BestLevelStore();

    await store.save('easy', 3);
    await store.save('easy', 2);
    await store.save('hard', 1);

    expect(await store.load(['easy', 'normal', 'hard']), {
      'easy': 3,
      'normal': 0,
      'hard': 1,
    });
  });
}

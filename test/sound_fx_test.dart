import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_line_labyrinth/best_level_store.dart';
import 'package:one_line_labyrinth/how_to_play.dart';
import 'package:one_line_labyrinth/main.dart';
import 'package:one_line_labyrinth/platform/game_platform.dart';
import 'package:one_line_labyrinth/puzzle_generator.dart';
import 'package:one_line_labyrinth/src/audio/sound_fx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingPlayer implements SoundPlayer {
  final List<String> played = <String>[];
  bool disposed = false;

  @override
  void play(String asset, double volume) => played.add(asset);

  @override
  void dispose() => disposed = true;
}

class _RecordingMusic implements MusicPlayer {
  final List<String> calls = <String>[];
  bool accept = true;

  @override
  Future<bool> start(String asset, double volume) async {
    calls.add('start');
    return accept;
  }

  @override
  void pause() => calls.add('pause');

  @override
  Future<bool> resume() async {
    calls.add('resume');
    return accept;
  }

  @override
  void stop() => calls.add('stop');
}

class _MutedPlatform extends NoopGamePlatform {
  _MutedPlatform();

  bool muted = true;

  @override
  bool get isAudioMuted => muted;
}

class _ThrowingPlatform extends NoopGamePlatform {
  @override
  bool get isAudioMuted => throw StateError('sdk gone');
}

class _SeenTutorialStore extends TutorialStore {
  const _SeenTutorialStore();

  @override
  Future<bool> isSeen() async => true;
}

class _NoBestStore extends BestLevelStore {
  @override
  Future<Map<String, int>> load(Iterable<String> names) async => {
    for (final n in names) n: 0,
  };

  @override
  Future<void> save(String difficultyName, int level) async {}
}

const _seed = 3;

GridPuzzle _puzzle() => PuzzleGenerator(
  random: math.Random(_seed),
).generate(PuzzleDifficulty.easy, 1);

Offset _at(WidgetTester tester, GridPuzzle puzzle, int index) {
  final board = find.byKey(const ValueKey('board'));
  final side = tester.getSize(board).shortestSide;
  final node = puzzle.nodes[index];
  return tester.getTopLeft(board) + Offset(node.x * side, node.y * side);
}

Future<void> _pump(WidgetTester tester, SoundFx fx) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OneLineLabyrinthApp(
      random: math.Random(_seed),
      bestLevelStore: _NoBestStore(),
      tutorialStore: const _SeenTutorialStore(),
      soundFx: fx,
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SoundFx', () {
    test('plays the asset of each effect at a volume', () {
      final player = _RecordingPlayer();
      SoundFx(player: player).play(Sfx.step);
      expect(player.played, ['assets/audio/step.wav']);
    });

    test('user mute silences effects and platform mute does too', () async {
      final player = _RecordingPlayer();
      final platform = _MutedPlatform()..muted = false;
      final fx = SoundFx(platform: platform, player: player);

      await fx.setUserMuted(true);
      fx.play(Sfx.step);
      expect(player.played, isEmpty);

      await fx.setUserMuted(false);
      fx.play(Sfx.step);
      expect(player.played, hasLength(1));

      platform.muted = true;
      expect(fx.muted, isTrue);
      expect(fx.userMuted, isFalse);
      fx.play(Sfx.solved);
      expect(player.played, hasLength(1));
    });

    test('a failing platform getter counts as not muted', () {
      final player = _RecordingPlayer();
      SoundFx(platform: _ThrowingPlatform(), player: player).play(Sfx.undo);
      expect(player.played, hasLength(1));
    });

    test('mute choice persists under sound_muted_v1', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.setUserMuted(true);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      final reloaded = SoundFx(player: _RecordingPlayer());
      expect(reloaded.userMuted, isFalse);
      await reloaded.load();
      expect(reloaded.userMuted, isTrue);
    });

    test('defaults to sound on when nothing is stored', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.load();
      expect(fx.userMuted, isFalse);
    });

    test('a toggle made before load finishes is not overwritten', () async {
      SharedPreferences.setMockInitialValues({'sound_muted_v1': true});
      final fx = SoundFx(player: _RecordingPlayer());
      final loading = fx.load();
      await fx.setUserMuted(false);
      await loading;
      expect(fx.userMuted, isFalse);
    });

    test('player and storage failures never throw', () async {
      final fx = SoundFx(
        player: _ThrowingPlayer(),
        preferences: () async => throw StateError('no storage'),
      );
      await fx.load();
      await fx.setUserMuted(true);
      await fx.setUserMuted(false);
      fx.play(Sfx.step);
    });

    test('the platform player tolerates a missing native channel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final player = PlatformSoundPlayer();
      player.play(Sfx.step.asset, 0.5);
      player.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    test('dispose releases the player and later calls are harmless', () async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player)..dispose();
      expect(player.disposed, isTrue);
      fx.play(Sfx.step);
      await fx.setUserMuted(true);
      expect(player.played, isEmpty);
    });
  });

  group('music', () {
    test(
      'native music starts at once and follows mute and visibility',
      () async {
        final music = _RecordingMusic();
        final platform = _MutedPlatform()..muted = false;
        final fx = SoundFx(
          player: _RecordingPlayer(),
          music: music,
          platform: platform,
          isWeb: false,
        );
        fx.startMusic();
        await Future<void>.delayed(Duration.zero);
        expect(music.calls, ['start']);
        expect(fx.isMusicPlaying, isTrue);

        await fx.setUserMuted(true);
        expect(music.calls.last, 'pause');
        expect(fx.isMusicPlaying, isFalse);
        await fx.setUserMuted(false);
        await Future<void>.delayed(Duration.zero);
        expect(music.calls.last, 'start');

        platform.muted = true;
        fx.refreshMute();
        expect(music.calls.last, 'pause');
        platform.muted = false;
        fx.refreshMute();
        await Future<void>.delayed(Duration.zero);
        expect(fx.isMusicPlaying, isTrue);

        fx.setAppVisible(false);
        expect(fx.isMusicPlaying, isFalse);
        fx.setAppVisible(true);
        await Future<void>.delayed(Duration.zero);
        expect(fx.isMusicPlaying, isTrue);

        fx.stopMusic();
        expect(music.calls.last, 'stop');
        fx.dispose();
      },
    );

    test('web music waits for the first user input and resumes', () async {
      final music = _RecordingMusic();
      final fx = SoundFx(player: _RecordingPlayer(), music: music, isWeb: true);
      fx.startMusic();
      await Future<void>.delayed(Duration.zero);
      expect(music.calls, isEmpty);

      fx.onUserInput();
      await Future<void>.delayed(Duration.zero);
      expect(music.calls, ['start']);
      fx.setAppVisible(false);
      fx.setAppVisible(true);
      await Future<void>.delayed(Duration.zero);
      expect(music.calls, ['start', 'pause', 'resume']);
      fx.dispose();
      expect(music.calls.last, 'stop');
    });

    test('a refused start is retried on the next input', () async {
      final music = _RecordingMusic()..accept = false;
      final fx = SoundFx(player: _RecordingPlayer(), music: music, isWeb: true);
      fx.startMusic();
      fx.onUserInput();
      await Future<void>.delayed(Duration.zero);
      expect(fx.isMusicPlaying, isFalse);
      music.accept = true;
      fx.onUserInput();
      await Future<void>.delayed(Duration.zero);
      expect(fx.isMusicPlaying, isTrue);
      expect(music.calls, ['start', 'start']);
      fx.dispose();
    });

    test('a stored mute keeps the music silent', () async {
      SharedPreferences.setMockInitialValues({SoundFx.mutedKey: true});
      final music = _RecordingMusic();
      final fx = SoundFx(
        player: _RecordingPlayer(),
        music: music,
        isWeb: false,
      );
      await fx.load();
      fx.startMusic();
      await Future<void>.delayed(Duration.zero);
      expect(music.calls, isEmpty);
      fx.dispose();
    });

    test('the loop is a small 16 kHz mono file bundled by pubspec', () {
      final file = File(SoundFx.musicAsset);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), lessThanOrEqualTo(1024 * 1024));
      final bytes = file.readAsBytesSync();
      final header = ByteData.sublistView(bytes, 0, 44);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(34, Endian.little), 16);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/music/'),
      );
    });
  });

  group('assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('pubspec bundles the audio directory', () {
      expect(pubspec, contains('- assets/audio/'));
    });

    for (final sfx in Sfx.values) {
      test('${sfx.name} exists on disk and is small', () {
        final file = File(sfx.asset);
        expect(file.existsSync(), isTrue, reason: sfx.asset);
        expect(file.lengthSync(), lessThan(40 * 1024));
      });
    }

    test('every asset used in lib/ is covered by Sfx', () {
      final used = <String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        used.addAll(
          RegExp(
            r'assets/audio/[a-z_]+\.wav',
          ).allMatches(entity.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
      // Only the Sfx.asset template exists in code; the list comes from the enum.
      expect(used, isEmpty);
      final onDisk = Directory(
        'assets/audio',
      ).listSync().map((e) => e.path).where((p) => p.endsWith('.wav')).toSet();
      expect(onDisk, Sfx.values.map((s) => s.asset).toSet());
    });
  });

  group('game hooks', () {
    testWidgets('steps, undo, invalid taps and solving play sounds', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player);
      await _pump(tester, fx);
      final puzzle = _puzzle();
      final solution = puzzle.solution;

      await tester.tapAt(_at(tester, puzzle, solution[1]));
      await tester.pump();
      expect(player.played, ['assets/audio/step.wav']);

      // Back onto the previous knot.
      await tester.tapAt(_at(tester, puzzle, solution[0]));
      await tester.pump();
      expect(player.played.last, 'assets/audio/undo.wav');

      // A knot that is not linked to the start.
      final unlinked = List<int>.generate(puzzle.nodeCount, (i) => i)
          .firstWhere(
            (i) =>
                i != solution[0] && !puzzle.neighbors(solution[0]).contains(i),
          );
      player.played.clear();
      await tester.tapAt(_at(tester, puzzle, unlinked));
      await tester.pump();
      expect(player.played, ['assets/audio/invalid.wav']);

      player.played.clear();
      for (final index in solution.skip(1)) {
        await tester.tapAt(_at(tester, puzzle, index));
        await tester.pump();
      }
      expect(
        player.played.where((a) => a.endsWith('step.wav')),
        hasLength(solution.length - 2),
      );
      expect(player.played.last, 'assets/audio/solved.wav');
      expect(
        player.played.where((a) => a.endsWith('solved.wav')),
        hasLength(1),
      );
    });

    testWidgets('dragging plays steps and stays silent over unlinked knots', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final puzzle = _puzzle();
      final solution = puzzle.solution;
      Offset at(int i) => _at(tester, puzzle, i);
      final unlinked = List<int>.generate(puzzle.nodeCount, (i) => i)
          .firstWhere(
            (i) =>
                i != solution[0] && !puzzle.neighbors(solution[0]).contains(i),
          );

      final gesture = await tester.startGesture(at(solution[0]));
      // Skim over an unlinked knot first: silent.
      for (var s = 1; s <= 8; s++) {
        await gesture.moveTo(
          Offset.lerp(at(solution[0]), at(unlinked), s / 8)!,
        );
        await tester.pump();
      }
      expect(player.played, isNot(contains('assets/audio/invalid.wav')));
      for (var k = 1; k < solution.length; k++) {
        for (var s = 1; s <= 4; s++) {
          await gesture.moveTo(
            Offset.lerp(
              k == 1 ? at(unlinked) : at(solution[k - 1]),
              at(solution[k]),
              s / 4,
            )!,
          );
          await tester.pump();
        }
      }
      await gesture.up();
      await tester.pump();
      expect(player.played, isNot(contains('assets/audio/invalid.wav')));
      expect(player.played.where((a) => a.endsWith('step.wav')), isNotEmpty);
    });

    testWidgets('reset path plays undo only when it changes something', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final puzzle = _puzzle();

      await tester.tap(find.byTooltip('Reset path'));
      await tester.pump();
      expect(player.played, isEmpty);

      await tester.tapAt(_at(tester, puzzle, puzzle.solution[1]));
      await tester.pump();
      player.played.clear();
      await tester.tap(find.byTooltip('Reset path'));
      await tester.pump();
      expect(player.played, ['assets/audio/undo.wav']);
    });

    testWidgets('muted game stays silent', (tester) async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player);
      await fx.setUserMuted(true);
      await _pump(tester, fx);
      final puzzle = _puzzle();

      await tester.tapAt(_at(tester, puzzle, puzzle.solution[1]));
      await tester.pump();
      expect(player.played, isEmpty);
    });

    testWidgets('the toggle flips icon, tooltip and stored state', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player);
      await _pump(tester, fx);

      expect(find.byTooltip('Sound on'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Sound on'));
      await tester.pump();
      expect(fx.userMuted, isTrue);
      expect(find.byTooltip('Sound off'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      await tester.tap(find.byTooltip('Sound off'));
      await tester.pump();
      expect(fx.userMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('a stored mute choice is applied on launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_muted_v1': true,
        TutorialStore.key: true,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(OneLineLabyrinthApp(random: math.Random(_seed)));
      // The sky animates forever, so pump a few frames instead of settling.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byTooltip('Sound off'), findsOneWidget);
    });

    testWidgets('the toggle is blocked while the tutorial card is open', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      await tester.tap(find.byTooltip('Sound on'), warnIfMissed: false);
      await tester.pump();
      expect(fx.userMuted, isFalse);
    });
  });
}

class _ThrowingPlayer implements SoundPlayer {
  @override
  void play(String asset, double volume) => throw StateError('boom');

  @override
  void dispose() => throw StateError('boom');
}

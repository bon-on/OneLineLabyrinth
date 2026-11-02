import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/game_platform.dart';
import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// Sound effects of the game. Each value maps to `assets/audio/<name>.wav`,
/// produced by `tool/generate_sounds.py`.
enum Sfx {
  step('step'),
  undo('undo'),
  invalid('invalid'),
  solved('solved'),
  hint('hint'),
  deadEnd('dead_end'),
  star('star'),
  levelUp('level_up');

  const Sfx(this.file);

  /// File name without extension.
  final String file;

  String get asset => 'assets/audio/$file.wav';
}

/// Backend of the looping background music; tests substitute a recorder.
abstract class MusicPlayer {
  /// Starts [asset] on repeat from the beginning. Completes with false when
  /// playback could not start (for example the browser autoplay policy).
  Future<bool> start(String asset, double volume);

  /// Pauses the loop, keeping its position where the backend can.
  void pause();

  /// Continues a paused loop. Completes with false when it could not.
  Future<bool> resume();

  /// Stops the loop.
  void stop();
}

/// Web: a dedicated HTML audio element. Native: `startLoop` / `stopLoop` on
/// the `one_line_labyrinth/audio` channel. Failures are swallowed.
class PlatformMusicPlayer implements MusicPlayer {
  PlatformMusicPlayer({WebSound? web}) : _web = web ?? WebSound();

  final WebSound _web;
  String? _asset;
  double _volume = 1;

  @override
  Future<bool> start(String asset, double volume) async {
    _asset = asset;
    _volume = volume;
    if (kIsWeb) return _web.loop(asset, volume);
    return _invoke('startLoop', <String, Object>{
      'asset': asset,
      'volume': volume,
    });
  }

  @override
  void pause() {
    if (kIsWeb) {
      _web.pauseLoop();
    } else {
      _invoke('stopLoop');
    }
  }

  @override
  Future<bool> resume() async {
    if (kIsWeb) return _web.resumeLoop();
    final asset = _asset;
    if (asset == null) return false;
    return start(asset, _volume);
  }

  @override
  void stop() {
    if (kIsWeb) {
      _web.stopLoop();
    } else {
      _invoke('stopLoop');
    }
  }

  Future<bool> _invoke(String method, [Object? arguments]) async {
    try {
      await PlatformSoundPlayer._channel.invokeMethod<void>(method, arguments);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Backend that actually makes noise; tests substitute a recorder.
abstract class SoundPlayer {
  void play(String asset, double volume);

  void dispose();
}

/// Web: HTML audio elements. Native: the `one_line_labyrinth/audio` channel.
/// Every failure is swallowed so audio can never block input.
class PlatformSoundPlayer implements SoundPlayer {
  static const MethodChannel _channel = MethodChannel(
    'one_line_labyrinth/audio',
  );

  PlatformSoundPlayer({WebSound? web}) : _web = web ?? WebSound();

  final WebSound _web;

  @override
  void play(String asset, double volume) {
    if (kIsWeb) {
      _web.play(asset, volume);
      return;
    }
    _invoke('play', <String, Object>{'asset': asset, 'volume': volume});
  }

  @override
  void dispose() {
    if (!kIsWeb) _invoke('disposeAudio');
  }

  void _invoke(String method, [Object? arguments]) {
    try {
      unawaited(
        _channel
            .invokeMethod<void>(method, arguments)
            .then<void>(
              (_) {},
              onError: (Object _) {
                // MissingPluginException / PlatformException: audio is optional.
              },
            ),
      );
    } catch (_) {}
  }
}

/// Plays short sound effects and the music loop, and owns the persisted mute
/// switch (one switch for both).
///
/// Effective mute = the player's own toggle OR the portal asking for silence
/// (`GamePlatform.isAudioMuted`). Music has a wanted state ([startMusic] /
/// [stopMusic]) separate from whether it plays: mute, a hidden app or tab and
/// (on web) a missing first user input all hold it back until they clear.
class SoundFx extends ChangeNotifier {
  SoundFx({
    this.platform = const NoopGamePlatform(),
    SoundPlayer? player,
    MusicPlayer? music,
    bool? isWeb,
    Future<SharedPreferences> Function()? preferences,
  }) : _player = player ?? PlatformSoundPlayer(),
       _music = music ?? PlatformMusicPlayer(),
       _isWeb = isWeb ?? kIsWeb,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const String musicAsset = 'assets/music/ambient_loop.wav';
  static const double musicVolume = 0.4;

  /// `shared_preferences` key of the user's mute choice (default: sound on).
  static const String mutedKey = 'sound_muted_v1';

  static const double _volume = 0.7;

  final GamePlatform platform;
  final SoundPlayer _player;
  final MusicPlayer _music;
  final bool _isWeb;
  final Future<SharedPreferences> Function() _preferences;

  bool _musicWanted = false;
  bool _musicPlaying = false;
  bool _musicStarting = false;
  // The loop was started once (web keeps it paused instead of restarting).
  bool _musicStarted = false;
  bool _appVisible = true;
  bool _userInteracted = false;

  bool _userMuted = false;
  bool _touched = false;
  bool _disposed = false;

  /// The player's own choice, shown by the toggle button.
  bool get userMuted => _userMuted;

  /// Whether nothing is audible right now.
  bool get muted => _userMuted || _platformMuted;

  bool get _platformMuted {
    try {
      return platform.isAudioMuted;
    } catch (_) {
      return false;
    }
  }

  /// Reads the stored choice; a storage failure keeps sound on.
  Future<void> load() async {
    try {
      final stored = (await _preferences()).getBool(mutedKey);
      // A toggle made while the read was pending wins.
      if (_touched || _disposed || stored == null || stored == _userMuted) {
        return;
      }
      _userMuted = stored;
      _applyMusic();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setUserMuted(bool value) async {
    _touched = true;
    if (value != _userMuted) {
      _userMuted = value;
      _applyMusic();
      if (!_disposed) notifyListeners();
    }
    try {
      await (await _preferences()).setBool(mutedKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => setUserMuted(!_userMuted);

  /// Fire-and-forget; silent when muted, never throws.
  void play(Sfx sfx) {
    if (_disposed || muted) return;
    try {
      _player.play(sfx.asset, _volume);
    } catch (_) {}
  }

  /// True while the music loop is (believed to be) audible.
  bool get isMusicPlaying => _musicPlaying;

  /// Requests background music. It plays once nothing holds it back.
  void startMusic() {
    _musicWanted = true;
    _applyMusic();
  }

  /// Stops the music and forgets the request.
  void stopMusic() {
    _musicWanted = false;
    _applyMusic();
  }

  /// Call when the app or browser tab is hidden or shown again.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _applyMusic();
  }

  /// Call on pointer or key input: browsers only allow audio after one, and
  /// the platform mute may have changed meanwhile.
  void onUserInput() {
    _userInteracted = true;
    _applyMusic();
  }

  /// Call after the platform mute may have changed.
  void refreshMute() => _applyMusic();

  bool get _musicAllowed =>
      !_disposed &&
      _musicWanted &&
      !muted &&
      _appVisible &&
      (!_isWeb || _userInteracted);

  void _applyMusic() {
    try {
      if (!_musicAllowed) {
        _holdMusicBack();
        return;
      }
      if (_musicPlaying || _musicStarting) return;
      _musicStarting = true;
      final Future<bool> started = _isWeb && _musicStarted
          ? _music.resume()
          : _music.start(musicAsset, musicVolume);
      started.then<bool>((ok) => ok, onError: (Object _) => false).then((ok) {
        _musicStarting = false;
        if (_disposed) return;
        if (ok) {
          _musicStarted = true;
          _musicPlaying = true;
        }
        // State may have changed while playback was starting. A refused
        // start is retried on the next user input.
        if (ok || !_musicAllowed) _applyMusic();
      });
    } catch (_) {
      _musicStarting = false;
    }
  }

  void _holdMusicBack() {
    try {
      if (!_musicWanted || _disposed) {
        if (_musicStarted || _musicPlaying) _music.stop();
        _musicStarted = false;
      } else if (_musicPlaying) {
        _music.pause();
      }
    } catch (_) {}
    _musicPlaying = false;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _musicWanted = false;
    _holdMusicBack();
    try {
      _player.dispose();
    } catch (_) {}
    super.dispose();
  }
}

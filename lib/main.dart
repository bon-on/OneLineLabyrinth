import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'best_level_store.dart';
import 'how_to_play.dart';
import 'platform/game_platform.dart';
import 'puzzle_generator.dart';
import 'result_registration.dart';
import 'src/art/sky_scenery.dart';
import 'src/art/sky_theme.dart';
import 'src/audio/sound_fx.dart';
import 'src/game/board_fx.dart';
import 'src/game/board_painter.dart';
import 'src/meta/constellations.dart';
import 'src/meta/level_stars.dart';
import 'src/meta/sky_progress.dart';
import 'src/meta/sky_progress_store.dart';
import 'src/ui/album_overlay.dart';
import 'src/ui/level_map_overlay.dart';
import 'src/ui/sky_ui.dart';
import 'src/ui/summary_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = createGamePlatform();
  await platform.initialize();
  runApp(OneLineLabyrinthApp(platform: platform));
}

class OneLineLabyrinthApp extends StatelessWidget {
  const OneLineLabyrinthApp({
    super.key,
    this.random,
    this.bestLevelStore,
    this.tutorialStore,
    this.progressStore,
    this.stopwatch,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  /// Injectable randomness for deterministic tests.
  final math.Random? random;

  /// Legacy per-difficulty best level keys (`best_level_<difficulty>`).
  final BestLevelStore? bestLevelStore;
  final TutorialStore? tutorialStore;

  /// Stars, XP, album and theme (`labyrinth_progress_v1`).
  final SkyProgressStore? progressStore;

  /// Injectable solve timer so tests can observe pausing.
  final Stopwatch? stopwatch;

  /// Portal hooks (CrazyGames SDK events, leaderboard gate).
  final GamePlatform platform;

  /// Injectable sound effects; tests pass a recording one.
  final SoundFx? soundFx;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Line Labyrinth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B1F),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9F8CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: OneLineLabyrinthScreen(
        random: random,
        bestLevelStore: bestLevelStore,
        tutorialStore: tutorialStore,
        progressStore: progressStore,
        stopwatch: stopwatch,
        platform: platform,
        soundFx: soundFx,
      ),
    );
  }
}

class OneLineLabyrinthScreen extends StatefulWidget {
  const OneLineLabyrinthScreen({
    super.key,
    this.random,
    this.bestLevelStore,
    this.tutorialStore,
    this.progressStore,
    this.stopwatch,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  final math.Random? random;
  final BestLevelStore? bestLevelStore;
  final TutorialStore? tutorialStore;
  final SkyProgressStore? progressStore;
  final Stopwatch? stopwatch;

  /// Portal hooks (CrazyGames SDK events, leaderboard gate).
  final GamePlatform platform;

  /// Sound effects and mute switch; defaults to the real player.
  final SoundFx? soundFx;

  @override
  State<OneLineLabyrinthScreen> createState() => _OneLineLabyrinthScreenState();
}

enum _Menu { none, map, album, themes }

class _OneLineLabyrinthScreenState extends State<OneLineLabyrinthScreen>
    with SingleTickerProviderStateMixin {
  late final PuzzleGenerator _generator = PuzzleGenerator(
    random: widget.random,
  );
  late final BestLevelStore _store = widget.bestLevelStore ?? BestLevelStore();
  late final SkyProgressStore _progressStore =
      widget.progressStore ?? const SkyProgressStore();
  PuzzleDifficulty _difficulty = PuzzleDifficulty.easy;
  late GridPuzzle _puzzle;
  late List<int> _path;
  int _level = 1;
  int _attempts = 0;
  // Undo steps and resets in this attempt (Clean line star).
  int _backtracks = 0;
  int _hints = 0;
  int? _dragNode;
  // True while a pan gesture is feeding _stepTo (no error sound then).
  bool _dragging = false;
  late final TutorialStore _tutorialStore =
      widget.tutorialStore ?? const TutorialStore();
  late final Stopwatch _stopwatch = widget.stopwatch ?? Stopwatch();
  bool _tutorialOpen = false;
  // True until the stored tutorial flag has been read, so gameplayStart is
  // not reported before we know whether the tutorial is about to open.
  bool _tutorialLoading = true;
  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;
  _Menu _menu = _Menu.none;
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);

  // Meta progress. Changes made before the stored value has loaded are kept
  // as operations and replayed on the loaded value, so nothing is lost and
  // nothing is saved over the stored progress before it was read.
  SkyProgress _progress = const SkyProgress.initial();
  bool _progressLoaded = false;
  final List<SkyProgress Function(SkyProgress)> _pendingOps =
      <SkyProgress Function(SkyProgress)>[];
  LevelOutcome? _outcome;
  int _streak = 0;

  // One clock for every effect; painters repaint from it, widgets do not.
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);
  final ValueNotifier<Offset?> _drag = ValueNotifier<Offset?>(null);
  final ValueNotifier<double> _starReveal = ValueNotifier<double>(0);
  final BoardFx _fx = BoardFx();
  double? _revealStart;
  int _starsChimed = 0;
  bool _levelUpPlayed = false;
  bool _hintShown = false;

  final FocusNode _gameFocus = FocusNode(debugLabel: 'game');
  late final AppLifecycleListener _lifecycle;

  bool get _complete =>
      _path.length == _puzzle.nodeCount && _path.last == _puzzle.finish;

  bool get _deadEnd => !_complete && _candidateNodes().isEmpty;

  SkyPalette get _palette => _progress.selectedTheme.palette;

  bool get _inputBlocked =>
      _tutorialLoading || _tutorialOpen || _menu != _Menu.none;

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) {
      // Music waits for the stored mute so a muted player hears no blip.
      _sound.load().then((_) {
        if (mounted) _sound.startMusic();
      });
    } else {
      _sound.startMusic();
    }
    widget.platform.setAudioMuteListener(_sound.refreshMute);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sound.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _ticker = createTicker(_onTick)..start();
    _newPuzzle();
    _loadProgress();
    _maybeShowTutorial();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(null);
    _lifecycle.dispose();
    _ticker.dispose();
    _sound.removeListener(_onSoundChanged);
    if (widget.soundFx == null) {
      _sound.dispose();
    } else {
      _sound.stopMusic();
    }
    _gameFocus.dispose();
    _time.dispose();
    _seconds.dispose();
    _drag.dispose();
    _starReveal.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    _time.value = t;
    _fx.prune(t);
    // The hint status and button glow are widgets: rebuild once on expiry.
    final hintShown = _fx.hintNode(t) != null;
    if (_hintShown && !hintShown && mounted) setState(() {});
    _hintShown = hintShown;
    if (!_complete) {
      _seconds.value = _stopwatch.elapsedMilliseconds ~/ 1000;
    }
    final start = _revealStart;
    final outcome = _outcome;
    if (start != null && outcome != null) {
      final reveal = ((t - start) / 0.38).clamp(0.0, 3.0);
      _starReveal.value = reveal;
      final earned = outcome.result.stars.count;
      while (_starsChimed < earned && reveal >= _starsChimed + 0.3) {
        _starsChimed++;
        _sound.play(Sfx.star);
      }
      if (outcome.leveledUp && !_levelUpPlayed && reveal >= 3) {
        _levelUpPlayed = true;
        _sound.play(Sfx.levelUp);
      }
    }
  }

  /// Any pointer or key input: browsers only allow music after one, and the
  /// platform mute may have changed meanwhile.
  void _onAnyInput() {
    _sound.onUserInput();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) _onAnyInput();
    return false;
  }

  Future<void> _maybeShowTutorial() async {
    final seen = await _tutorialStore.isSeen();
    if (!mounted) return;
    setState(() => _tutorialLoading = false);
    if (seen) {
      _syncGameplay();
    } else {
      _openTutorial();
    }
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// playing means no tutorial or menu and an unsolved puzzle.
  void _syncGameplay() {
    final wantActive =
        !_tutorialLoading &&
        !_tutorialOpen &&
        _menu == _Menu.none &&
        !_complete;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  void _openTutorial() {
    if (_tutorialOpen) return;
    // Time spent reading the tutorial must not count towards the solve time.
    _stopwatch.stop();
    setState(() => _tutorialOpen = true);
    _syncGameplay();
  }

  void _closeTutorial() {
    if (!_tutorialOpen) return;
    _tutorialStore.markSeen();
    if (!_complete && _menu == _Menu.none) _stopwatch.start();
    setState(() => _tutorialOpen = false);
    _syncGameplay();
    _gameFocus.requestFocus();
  }

  void _openMenu(_Menu menu) {
    if (_inputBlocked) return;
    _stopwatch.stop();
    setState(() => _menu = menu);
    _syncGameplay();
  }

  void _closeMenu() {
    if (_menu == _Menu.none) return;
    if (!_complete && !_tutorialOpen) _stopwatch.start();
    setState(() => _menu = _Menu.none);
    _syncGameplay();
    _gameFocus.requestFocus();
  }

  Future<void> _loadProgress() async {
    SkyProgress loaded;
    try {
      loaded = await _progressStore.load();
    } catch (_) {
      loaded = const SkyProgress.initial();
    }
    Map<String, int> legacy;
    try {
      legacy = await _store.load(PuzzleDifficulty.values.map((d) => d.name));
    } catch (_) {
      legacy = const <String, int>{};
    }
    if (!mounted) return;
    var merged = loaded.withLegacyBestLevels(legacy);
    for (final op in _pendingOps) {
      merged = op(merged);
    }
    final changed = !identical(merged, loaded);
    _pendingOps.clear();
    setState(() {
      _progressLoaded = true;
      _progress = merged;
    });
    if (changed) _saveProgress();
  }

  void _updateProgress(SkyProgress Function(SkyProgress) op) {
    _progress = op(_progress);
    if (_progressLoaded) {
      _saveProgress();
    } else {
      _pendingOps.add(op);
    }
  }

  Future<void> _saveProgress() async {
    try {
      await _progressStore.save(_progress);
    } catch (_) {}
  }

  void _selectTheme(SkyTheme theme) {
    if (!_progress.isThemeUnlocked(theme)) return;
    setState(() => _updateProgress((p) => p.withTheme(theme)));
  }

  void _newPuzzle() {
    _puzzle = _generator.generate(_difficulty, _level);
    _path = [_puzzle.start];
    _attempts = 0;
    _backtracks = 0;
    _hints = 0;
    _dragNode = null;
    _drag.value = null;
    _outcome = null;
    _revealStart = null;
    _starReveal.value = 0;
    _seconds.value = 0;
    _fx
      ..clear()
      ..visit(_puzzle.start, _time.value);
    _stopwatch
      ..reset()
      ..start();
    if (_tutorialOpen || _menu != _Menu.none) _stopwatch.stop();
    setState(() {});
    _syncGameplay();
  }

  void _resetPath() {
    if (_complete || _path.length == 1) return;
    _sound.play(Sfx.undo);
    _attempts++;
    _backtracks++;
    _fx.scatter(_path, _time.value);
    _path = [_puzzle.start];
    setState(() {});
  }

  void _undoStep() {
    if (_complete || _path.length < 2) return;
    _stepTo(_path[_path.length - 2]);
  }

  void _stepTo(int index) {
    if (_complete || index == _path.last) return;

    if (_path.length >= 2 && index == _path[_path.length - 2]) {
      _sound.play(Sfx.undo);
      _backtracks++;
      _fx.retract(_path.last, index, _time.value);
      setState(() => _path = [..._path]..removeLast());
      return;
    }

    if (_path.contains(index) ||
        !_puzzle.neighbors(_path.last).contains(index)) {
      // Drags skim past other knots on purpose; only a tap is an error.
      if (!_dragging) {
        _sound.play(Sfx.invalid);
        _fx.invalid(index, _time.value);
      }
      return;
    }
    setState(() => _path = [..._path, index]);
    _fx
      ..endHints()
      ..visit(index, _time.value);
    if (_complete) {
      _sound.play(Sfx.solved);
      _onComplete();
    } else {
      _sound.play(_deadEnd ? Sfx.deadEnd : Sfx.step);
    }
  }

  /// Rewinds the line to where it still follows the hidden solution and
  /// lights the next knot. Costs the Clean line star.
  void _useHint() {
    if (_complete || _inputBlocked) return;
    final solution = _puzzle.solution;
    var keep = 0;
    while (keep < _path.length && _path[keep] == solution[keep]) {
      keep++;
    }
    final now = _time.value;
    if (keep < _path.length) {
      _fx.scatter(_path.sublist(keep - 1), now);
      _path = solution.sublist(0, keep);
    }
    _hints++;
    _fx.hint(solution[_path.length], now);
    _sound.play(Sfx.hint);
    setState(() {});
  }

  void _onComplete() {
    _stopwatch.stop();
    _dragNode = null;
    _drag.value = null;
    final now = _time.value;
    final seconds = math.max(1, (_stopwatch.elapsedMilliseconds / 1000).ceil());
    _seconds.value = seconds;
    final result = LevelResult(
      difficulty: _difficulty,
      level: _level,
      stars: LevelStars.rate(
        backtracks: _backtracks,
        hints: _hints,
        seconds: seconds,
        nodeCount: _puzzle.nodeCount,
      ),
      seconds: seconds,
      shape: AlbumShape.encode(_path.map((i) => _puzzle.nodes[i])),
    );
    final outcome = _progress.applyLevel(result);
    if (outcome.isNewBest) _store.save(_difficulty.name, _level);
    _updateProgress((p) => p.applyLevel(result).progress);
    _streak = result.stars.clean ? _streak + 1 : 0;
    _outcome = outcome;
    _fx.complete(_path, now);
    _revealStart = now + completionWaveSeconds * 0.6;
    _starsChimed = 0;
    _levelUpPlayed = false;
    _syncGameplay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.platform.allowsResultRegistration) {
        offerResultRegistration(
          context,
          gameId: 'one-line-labyrinth',
          metric: 'time',
          value: seconds,
          displayValue: '${seconds}s',
        );
      }
    });
  }

  void _nextLevel() {
    _level++;
    _newPuzzle();
    _gameFocus.requestFocus();
  }

  void _replayLevel() {
    _newPuzzle();
    _gameFocus.requestFocus();
  }

  void _selectDifficulty(PuzzleDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    _level = 1;
    _newPuzzle();
  }

  void _pickLevel(PuzzleDifficulty difficulty, int level) {
    if (level > _progress.highestUnlocked(difficulty)) return;
    _difficulty = difficulty;
    _level = level;
    _menu = _Menu.none;
    _newPuzzle();
    _gameFocus.requestFocus();
  }

  Set<int> _candidateNodes() {
    if (_complete) return const {};
    final visited = _path.toSet();
    return _puzzle
        .neighbors(_path.last)
        .where((index) => !visited.contains(index))
        .toSet();
  }

  /// Nearest knot within [radiusCells] grid cells of [position], if any.
  int? _hitNode(Offset position, double boardSize, double radiusCells) {
    final cell = boardSize / math.max(_puzzle.columns, _puzzle.rows);
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _puzzle.nodeCount; i++) {
      final node = _puzzle.nodes[i];
      final point = Offset(node.x * boardSize, node.y * boardSize);
      final distance = (point - position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex < 0 || bestDistance > cell * radiusCells) return null;
    return bestIndex;
  }

  void _handleTap(Offset position, double boardSize) {
    _gameFocus.requestFocus();
    final index = _hitNode(position, boardSize, 0.45);
    if (index != null) _stepTo(index);
  }

  void _handleDrag(Offset position, double boardSize) {
    if (!_complete) _drag.value = position;
    // A tighter radius while dragging avoids grabbing knots the line passes near.
    final index = _hitNode(position, boardSize, 0.32);
    if (index == null || index == _dragNode) return;
    _dragNode = index;
    _dragging = true;
    try {
      _stepTo(index);
    } finally {
      _dragging = false;
    }
  }

  void _endDrag() {
    _dragNode = null;
    _drag.value = null;
  }

  KeyEventResult _onGameKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _inputBlocked) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // A Tab-focused button keeps Enter/Space for itself.
    if (_complete &&
        _gameFocus.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      _nextLevel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.keyZ) {
      _undoStep();
    } else if (key == LogicalKeyboardKey.keyR) {
      _resetPath();
    } else if (key == LogicalKeyboardKey.keyN) {
      _newPuzzle();
    } else if (key == LogicalKeyboardKey.keyH) {
      _useHint();
    } else if (key == LogicalKeyboardKey.keyM) {
      _openMenu(_Menu.map);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String get _status {
    if (_complete) {
      return 'The constellation is complete! Next level grows the sky.';
    }
    if (_path.length == _puzzle.nodeCount) {
      return 'Every star is lit, but the line must end on the ring.';
    }
    if (_deadEnd) {
      return 'Dead end - step back or reset the line.';
    }
    if (_fx.hintNode(_time.value) != null) {
      return 'Follow the golden guide to the next star.';
    }
    return 'Draw through linked stars. Light every star once and end on the ring.';
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Listener(
        onPointerDown: (_) => _onAnyInput(),
        // Mobile browsers grant audio on touch end, not touch start.
        onPointerUp: (_) => _onAnyInput(),
        child: Focus(
          focusNode: _gameFocus,
          autofocus: true,
          onKeyEvent: _onGameKey,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: SkyPainter(
                      theme: _progress.selectedTheme,
                      time: _time,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                // Ignore touches until the stored tutorial flag has been read.
                child: AbsorbPointer(
                  absorbing: _tutorialLoading,
                  // Keep Tab from moving focus to HUD buttons behind overlays.
                  child: ExcludeFocus(
                    excluding: _inputBlocked,
                    child: _buildGame(p),
                  ),
                ),
              ),
              if (_tutorialOpen)
                Positioned.fill(
                  child: HowToPlayOverlay(onClose: _closeTutorial, palette: p),
                ),
              if (_menu == _Menu.map)
                Positioned.fill(
                  child: LevelMapOverlay(
                    palette: p,
                    progress: _progress,
                    difficulty: _difficulty,
                    currentLevel: _level,
                    onPick: _pickLevel,
                    onClose: _closeMenu,
                  ),
                ),
              if (_menu == _Menu.album)
                Positioned.fill(
                  child: AlbumOverlay(
                    palette: p,
                    progress: _progress,
                    onClose: _closeMenu,
                  ),
                ),
              if (_menu == _Menu.themes)
                Positioned.fill(
                  child: SkyOverlay(
                    palette: p,
                    title: 'Sky themes',
                    subtitle: 'Raise your sky level to unlock new skies.',
                    maxWidth: 420,
                    onClose: _closeMenu,
                    child: ThemePicker(
                      palette: p,
                      selected: _progress.selectedTheme,
                      skyLevel: _progress.level,
                      onSelected: _selectTheme,
                      swatch: 70,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Building blocks

  Widget _title(SkyPalette p, {double size = 26}) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      'One Line Labyrinth',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        color: p.text,
        shadows: <Shadow>[
          Shadow(color: p.thread.withValues(alpha: 0.7), blurRadius: 16),
        ],
      ),
    ),
  );

  Widget _helpButton(SkyPalette p) => SkyIconButton(
    palette: p,
    icon: Icons.help_outline_rounded,
    tooltip: 'How to play',
    onPressed: _openTutorial,
  );

  Widget _soundButton(SkyPalette p) => SkyIconButton(
    palette: p,
    icon: _sound.userMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
    tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
    onPressed: _sound.toggle,
  );

  Widget _metrics(SkyPalette p) {
    final best = _progress.bestLevel(_difficulty);
    return Row(
      children: [
        Expanded(
          child: MetricTile(palette: p, label: 'Level', value: '$_level'),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: MetricTile(
            palette: p,
            label: 'Best',
            value: best == 0 ? '-' : '$best',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: MetricTile(
            palette: p,
            label: 'Path',
            value: '${_path.length}/${_puzzle.nodeCount}',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: MetricTile(palette: p, label: 'Tries', value: '$_attempts'),
        ),
      ],
    );
  }

  Widget _difficultyPicker(SkyPalette p) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PuzzleDifficulty>(
        segments: [
          for (final option in PuzzleDifficulty.values)
            ButtonSegment<PuzzleDifficulty>(
              value: option,
              label: Text(option.label),
            ),
        ],
        selected: {_difficulty},
        showSelectedIcon: false,
        onSelectionChanged: (selected) => _selectDifficulty(selected.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(BorderSide(color: p.panelBorder)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return p.thread.withValues(alpha: 0.85);
            }
            return p.panel.withValues(alpha: 0.8);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1A1230);
            }
            return p.text;
          }),
        ),
      ),
    );
  }

  Widget _tools(SkyPalette p, {bool withSystem = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SkyIconButton(
          palette: p,
          icon: Icons.undo_rounded,
          tooltip: 'Reset path',
          onPressed: _resetPath,
        ),
        SkyIconButton(
          palette: p,
          icon: Icons.lightbulb_outline_rounded,
          tooltip: 'Hint',
          active: _fx.hintNode(_time.value) != null,
          onPressed: _complete ? null : _useHint,
        ),
        SkyIconButton(
          palette: p,
          icon: Icons.shuffle_rounded,
          tooltip: 'New puzzle',
          onPressed: _newPuzzle,
        ),
        SkyIconButton(
          palette: p,
          icon: Icons.map_outlined,
          tooltip: 'Level map',
          onPressed: () => _openMenu(_Menu.map),
        ),
        SkyIconButton(
          palette: p,
          icon: Icons.auto_awesome_outlined,
          tooltip: 'Constellation album',
          onPressed: () => _openMenu(_Menu.album),
        ),
        if (withSystem) ...[_helpButton(p), _soundButton(p)],
      ],
    );
  }

  Widget _goals(SkyPalette p, {bool compact = false}) => StarGoals(
    palette: p,
    clean: _backtracks == 0 && _hints == 0,
    seconds: _seconds,
    parSeconds: LevelStars.parSeconds(_puzzle.nodeCount),
    bestStars: _progress.starsFor(_difficulty, _level),
    compact: compact,
  );

  Widget _statusText(SkyPalette p, {int maxLines = 2}) => Text(
    _status,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: _deadEnd ? p.danger : p.text,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
  );

  Widget _xp(SkyPalette p, {bool compact = false}) => XpBar(
    palette: p,
    level: _progress.level,
    into: _progress.xpIntoLevel,
    needed: _progress.xpForNextLevel,
    compact: compact,
  );

  Widget? _summary(SkyPalette p, {bool compact = false}) {
    final outcome = _outcome;
    if (outcome == null || !_complete) return null;
    return SummaryCard(
      palette: p,
      outcome: outcome,
      progress: _progress,
      difficultyLabel: _difficulty.label,
      streak: _streak,
      starReveal: _starReveal,
      onNext: _nextLevel,
      onReplay: _replayLevel,
      compact: compact,
    );
  }

  Widget _skyCard(SkyPalette p) => GlassPanel(
    palette: p,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Your sky', palette: p),
        const SizedBox(height: 8),
        _xp(p),
        const SizedBox(height: 10),
        ThemePicker(
          palette: p,
          selected: _progress.selectedTheme,
          skyLevel: _progress.level,
          onSelected: _selectTheme,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statPill(
                p,
                Icons.star_rounded,
                '${_progress.totalStars}'
                ' stars',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _statPill(
                p,
                Icons.auto_awesome,
                '${_progress.albumCount}/${Constellations.albumSize} found',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statPill(SkyPalette p, IconData icon, String text) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: p.skyTop.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: p.gold),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: p.text),
          ),
        ),
      ],
    ),
  );

  Widget _levelCard(SkyPalette p) {
    final found = _progress.album.containsKey(
      Constellations.slotKey(_difficulty, _level),
    );
    final named =
        found ||
        !Constellations.hasSlot(_level) ||
        _progress.starsFor(_difficulty, _level) > 0;
    return GlassPanel(
      palette: p,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('Tonight\'s constellation', palette: p),
          const SizedBox(height: 4),
          Text(
            named ? Constellations.nameFor(_difficulty, _level) : '???',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: p.threadCore,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_difficulty.label} - ${_puzzle.columns}x${_puzzle.rows} stars'
            '${Constellations.hasSlot(_level) ? (found ? ' - in album' : ' - album slot') : ''}',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _board(SkyPalette p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: boardSize,
            child: MouseRegion(
              cursor: _complete
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                key: const ValueKey('board'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _handleTap(details.localPosition, boardSize),
                onPanStart: (details) {
                  _dragNode = _path.last;
                  _handleDrag(details.localPosition, boardSize);
                },
                onPanUpdate: (details) =>
                    _handleDrag(details.localPosition, boardSize),
                onPanEnd: (_) => _endDrag(),
                onPanCancel: _endDrag,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: BoardPainter(
                      puzzle: _puzzle,
                      path: _path,
                      candidates: _candidateNodes(),
                      palette: p,
                      fx: _fx,
                      time: _time,
                      drag: _drag,
                      deadEnd: _deadEnd,
                      complete: _complete,
                      name: _outcome?.name,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Layouts

  Widget _buildGame(SkyPalette p) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              constraints.maxWidth >= 760 &&
              constraints.maxWidth > constraints.maxHeight * 1.15;
          if (!landscape) return _narrow(p, constraints);
          if (constraints.maxWidth >= 1100 && constraints.maxHeight >= 560) {
            return _wide(p);
          }
          return _twoColumn(p);
        },
      ),
    );
  }

  Widget _wide(SkyPalette p) {
    final summary = _summary(p);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassPanel(
                        palette: p,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _title(p),
                            const SizedBox(height: 2),
                            Text(
                              'One line. Every star. End on the ring.',
                              style: TextStyle(fontSize: 12.5, color: p.muted),
                            ),
                            const SizedBox(height: 12),
                            _metrics(p),
                            const SizedBox(height: 10),
                            _difficultyPicker(p),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassPanel(palette: p, child: _goals(p)),
                      const SizedBox(height: 12),
                      GlassPanel(
                        palette: p,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            _tools(p),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Keys: Backspace undo, R reset, H hint, N new',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: p.muted,
                                    ),
                                  ),
                                ),
                                _helpButton(p),
                                const SizedBox(width: 6),
                                _soundButton(p),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statusText(p, maxLines: 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(child: _board(p)),
              const SizedBox(width: 24),
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _skyCard(p),
                      const SizedBox(height: 12),
                      summary ?? _levelCard(p),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoColumn(SkyPalette p) {
    final summary = _summary(p, compact: true);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _title(p, size: 22)),
                      _helpButton(p),
                      const SizedBox(width: 6),
                      _soundButton(p),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (summary != null) ...[summary, const SizedBox(height: 10)],
                  _metrics(p),
                  const SizedBox(height: 8),
                  _difficultyPicker(p),
                  const SizedBox(height: 8),
                  _tools(p),
                  const SizedBox(height: 8),
                  GlassPanel(palette: p, child: _goals(p, compact: true)),
                  const SizedBox(height: 8),
                  _statusText(p),
                  const SizedBox(height: 8),
                  _skyCard(p),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _board(p)),
        ],
      ),
    );
  }

  Widget _narrow(SkyPalette p, BoxConstraints constraints) {
    const header = 196.0;
    final width = math.min(560.0, constraints.maxWidth) - 28;
    final footer = (constraints.maxHeight - 16 - header - width).clamp(
      118.0,
      292.0,
    );
    final summary = _summary(p, compact: true);
    final roomy = footer >= 210;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _title(p, size: 24)),
                  const SizedBox(width: 6),
                  _helpButton(p),
                  const SizedBox(width: 6),
                  _soundButton(p),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _xp(p, compact: true)),
                  const SizedBox(width: 8),
                  SkyIconButton(
                    palette: p,
                    icon: Icons.palette_outlined,
                    tooltip: 'Sky themes',
                    size: 34,
                    onPressed: () => _openMenu(_Menu.themes),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _metrics(p),
              const SizedBox(height: 8),
              _difficultyPicker(p),
              const SizedBox(height: 10),
              Expanded(child: _board(p)),
              const SizedBox(height: 8),
              SizedBox(
                height: footer - 8,
                child: summary != null
                    ? Column(
                        children: [
                          Expanded(child: summary),
                          // Short screens give the whole footer to the card.
                          if (roomy) ...[const SizedBox(height: 8), _tools(p)],
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (roomy) ...[
                            GlassPanel(
                              palette: p,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: _goals(p, compact: true),
                            ),
                            const Spacer(),
                          ],
                          _statusText(p, maxLines: roomy ? 2 : 1),
                          const SizedBox(height: 8),
                          _tools(p),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

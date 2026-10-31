import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'best_level_store.dart';
import 'how_to_play.dart';
import 'platform/game_platform.dart';
import 'puzzle_generator.dart';
import 'result_registration.dart';
import 'src/audio/sound_fx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = createGamePlatform();
  await platform.initialize();
  runApp(OneLineLabyrinthApp(platform: platform));
}

const _textColor = Color(0xFFE7DEC3);
const _mutedColor = Color(0xFFC1B48C);

class OneLineLabyrinthApp extends StatelessWidget {
  const OneLineLabyrinthApp({
    super.key,
    this.random,
    this.bestLevelStore,
    this.tutorialStore,
    this.stopwatch,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  /// Injectable randomness for deterministic tests.
  final math.Random? random;
  final BestLevelStore? bestLevelStore;
  final TutorialStore? tutorialStore;

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
        scaffoldBackgroundColor: const Color(0xFF141411),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEAB308),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: OneLineLabyrinthScreen(
        random: random,
        bestLevelStore: bestLevelStore,
        tutorialStore: tutorialStore,
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
    this.stopwatch,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  final math.Random? random;
  final BestLevelStore? bestLevelStore;
  final TutorialStore? tutorialStore;
  final Stopwatch? stopwatch;

  /// Portal hooks (CrazyGames SDK events, leaderboard gate).
  final GamePlatform platform;

  /// Sound effects and mute switch; defaults to the real player.
  final SoundFx? soundFx;

  @override
  State<OneLineLabyrinthScreen> createState() => _OneLineLabyrinthScreenState();
}

class _OneLineLabyrinthScreenState extends State<OneLineLabyrinthScreen> {
  late final PuzzleGenerator _generator = PuzzleGenerator(
    random: widget.random,
  );
  late final BestLevelStore _store = widget.bestLevelStore ?? BestLevelStore();
  final Map<PuzzleDifficulty, int> _bestLevels = {
    for (final d in PuzzleDifficulty.values) d: 0,
  };
  PuzzleDifficulty _difficulty = PuzzleDifficulty.easy;
  late GridPuzzle _puzzle;
  late List<int> _path;
  int _level = 1;
  int _attempts = 0;
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
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);

  bool get _complete =>
      _path.length == _puzzle.nodeCount && _path.last == _puzzle.finish;

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.load();
    _newPuzzle();
    _loadBestLevels();
    _maybeShowTutorial();
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sound.removeListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.dispose();
    super.dispose();
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
  /// playing means no tutorial and an unsolved puzzle.
  void _syncGameplay() {
    final wantActive = !_tutorialLoading && !_tutorialOpen && !_complete;
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
    if (!_complete) _stopwatch.start();
    setState(() => _tutorialOpen = false);
    _syncGameplay();
  }

  Future<void> _loadBestLevels() async {
    final stored = await _store.load(
      PuzzleDifficulty.values.map((d) => d.name),
    );
    if (!mounted) return;
    setState(() {
      for (final d in PuzzleDifficulty.values) {
        _bestLevels[d] = math.max(_bestLevels[d]!, stored[d.name] ?? 0);
      }
    });
  }

  void _newPuzzle() {
    _puzzle = _generator.generate(_difficulty, _level);
    _path = [_puzzle.start];
    _attempts = 0;
    _dragNode = null;
    _stopwatch
      ..reset()
      ..start();
    setState(() {});
    _syncGameplay();
  }

  void _resetPath() {
    if (_complete || _path.length == 1) return;
    _sound.play(Sfx.undo);
    _attempts++;
    _path = [_puzzle.start];
    setState(() {});
  }

  void _stepTo(int index) {
    if (_complete || index == _path.last) return;

    if (_path.length >= 2 && index == _path[_path.length - 2]) {
      _sound.play(Sfx.undo);
      setState(() => _path = [..._path]..removeLast());
      return;
    }

    if (_path.contains(index) ||
        !_puzzle.neighbors(_path.last).contains(index)) {
      // Drags skim past other knots on purpose; only a tap is an error.
      if (!_dragging) _sound.play(Sfx.invalid);
      return;
    }
    setState(() => _path = [..._path, index]);
    _sound.play(_complete ? Sfx.solved : Sfx.step);
    if (_complete) _onComplete();
  }

  void _onComplete() {
    _stopwatch.stop();
    _dragNode = null;
    _syncGameplay();
    if (_level > _bestLevels[_difficulty]!) {
      _bestLevels[_difficulty] = _level;
      _store.save(_difficulty.name, _level);
    }
    final seconds = math.max(1, (_stopwatch.elapsedMilliseconds / 1000).ceil());
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
  }

  void _selectDifficulty(PuzzleDifficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    _level = 1;
    _newPuzzle();
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
    final index = _hitNode(position, boardSize, 0.45);
    if (index != null) _stepTo(index);
  }

  void _handleDrag(Offset position, double boardSize) {
    // A tighter radius while dragging avoids grabbing knots the line passes near.
    final index = _hitNode(position, boardSize, 0.32);
    if (index == null || index == _dragNode) return;
    _dragNode = index;
    _dragging = true;
    _stepTo(index);
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _complete
        ? 'Exit reached! Next level grows the maze.'
        : _path.length == _puzzle.nodeCount
        ? 'Every knot is filled, but the line must end on the ring.'
        : 'Tap or drag through linked knots. Visit every knot once and end on the ring.';
    final header = _Header(
      level: _level,
      best: _bestLevels[_difficulty]!,
      attempts: _attempts,
      filled: _path.length,
      total: _puzzle.nodeCount,
      difficulty: _difficulty,
      onDifficultyChanged: _selectDifficulty,
      onRestart: _resetPath,
      onNewPuzzle: _newPuzzle,
      onHelp: _openTutorial,
      soundMuted: _sound.userMuted,
      onToggleSound: _sound.toggle,
    );
    final footer = SizedBox(
      height: 104,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_complete) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _nextLevel,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Level'),
            ),
          ],
        ],
      ),
    );
    final board = LayoutBuilder(
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
                onPanEnd: (_) => _dragNode = null,
                onPanCancel: () => _dragNode = null,
                child: CustomPaint(
                  painter: _GraphPainter(
                    puzzle: _puzzle,
                    path: _path,
                    candidates: _candidateNodes(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            // Ignore touches until the stored tutorial flag has been read.
            child: AbsorbPointer(
              absorbing: _tutorialLoading,
              // Keep Tab from moving focus to HUD buttons behind the overlay.
              child: ExcludeFocus(
                excluding: _tutorialLoading || _tutorialOpen,
                child: _buildGame(header, board, footer),
              ),
            ),
          ),
          if (_tutorialOpen)
            Positioned.fill(child: HowToPlayOverlay(onClose: _closeTutorial)),
        ],
      ),
    );
  }

  Widget _buildGame(Widget header, Widget board, Widget footer) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              constraints.maxWidth >= 760 &&
              constraints.maxWidth > constraints.maxHeight * 1.15;
          if (landscape) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            header,
                            const SizedBox(height: 16),
                            footer,
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(child: board),
                    ],
                  ),
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 12),
                    Expanded(child: board),
                    footer,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.level,
    required this.best,
    required this.attempts,
    required this.filled,
    required this.total,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onRestart,
    required this.onNewPuzzle,
    required this.onHelp,
    required this.soundMuted,
    required this.onToggleSound,
  });

  final int level;
  final int best;
  final int attempts;
  final int filled;
  final int total;
  final PuzzleDifficulty difficulty;
  final ValueChanged<PuzzleDifficulty> onDifficultyChanged;
  final VoidCallback onRestart;
  final VoidCallback onNewPuzzle;
  final VoidCallback onHelp;
  final bool soundMuted;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              // Four icon buttons leave little room; shrink instead of wrapping.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'One Line Labyrinth',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            IconButton(
              onPressed: onRestart,
              tooltip: 'Reset path',
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              onPressed: onNewPuzzle,
              tooltip: 'New puzzle',
              icon: const Icon(Icons.shuffle),
            ),
            IconButton(
              onPressed: onHelp,
              tooltip: 'How to play',
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              onPressed: onToggleSound,
              tooltip: soundMuted ? 'Sound off' : 'Sound on',
              icon: Icon(
                soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _Metric(label: 'Level', value: '$level'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Best', value: best == 0 ? '-' : '$best'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Path', value: '$filled/$total'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Tries', value: '$attempts'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _DifficultyPicker(
            difficulty: difficulty,
            onChanged: onDifficultyChanged,
          ),
        ),
      ],
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.difficulty, required this.onChanged});

  final PuzzleDifficulty difficulty;
  final ValueChanged<PuzzleDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PuzzleDifficulty>(
      segments: [
        for (final option in PuzzleDifficulty.values)
          ButtonSegment<PuzzleDifficulty>(
            value: option,
            label: Text(option.label),
          ),
      ],
      selected: {difficulty},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onChanged(selected.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF443B25);
          }
          return const Color(0xFF1F1D18);
        }),
        foregroundColor: WidgetStateProperty.all(const Color(0xFFEDE2C0)),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF24221C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _mutedColor)),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.puzzle,
    required this.path,
    required this.candidates,
  });

  final GridPuzzle puzzle;
  final List<int> path;
  final Set<int> candidates;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final cell = side / math.max(puzzle.columns, puzzle.rows);
    Offset point(int index) {
      final node = puzzle.nodes[index];
      return Offset(node.x * side, node.y * side);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFF1D1B16),
    );

    final edgePaint = Paint()
      ..color = const Color(0xFF5A5139)
      ..strokeWidth = cell * 0.07
      ..strokeCap = StrokeCap.round;
    for (final edge in puzzle.edges) {
      canvas.drawLine(point(edge.a), point(edge.b), edgePaint);
    }

    final pathPaint = Paint()
      ..color = const Color(0xFFD6A936)
      ..strokeWidth = cell * 0.13
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < path.length; i++) {
      canvas.drawLine(point(path[i]), point(path[i + 1]), pathPaint);
    }

    final order = <int, int>{for (var i = 0; i < path.length; i++) path[i]: i};
    for (var i = 0; i < puzzle.nodeCount; i++) {
      final visitedOrder = order[i];
      final isVisited = visitedOrder != null;
      final isCandidate = candidates.contains(i);
      final isFinish = i == puzzle.finish;
      final center = point(i);
      final radius = cell * (isCandidate ? 0.25 : 0.21);
      final fill = Paint()
        ..color = isVisited
            ? const Color(0xFFD6A936)
            : isCandidate
            ? const Color(0xFF6B5D35)
            : const Color(0xFF39342A);
      final outline = Paint()
        ..color = isFinish
            ? Colors.white
            : isCandidate
            ? const Color(0xFFEDE2C0)
            : const Color(0xFF746746)
        ..strokeWidth = cell * 0.045
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, outline);

      if (i == puzzle.start) {
        canvas.drawCircle(
          center,
          radius * 0.42,
          Paint()..color = const Color(0xFF141411),
        );
      } else if (isFinish) {
        canvas.drawCircle(
          center,
          radius * 0.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.04,
        );
      } else if (isVisited) {
        final painter = TextPainter(
          text: TextSpan(
            text: '${visitedOrder + 1}',
            style: TextStyle(
              color: const Color(0xFF141411),
              fontSize: cell * 0.19,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          center - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.puzzle != puzzle ||
        oldDelegate.path != path ||
        oldDelegate.candidates.length != candidates.length ||
        !oldDelegate.candidates.containsAll(candidates);
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(const OneLineLabyrinthApp());

class OneLineLabyrinthApp extends StatelessWidget {
  const OneLineLabyrinthApp({super.key});

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
      home: const OneLineLabyrinthScreen(),
    );
  }
}

class OneLineLabyrinthScreen extends StatefulWidget {
  const OneLineLabyrinthScreen({super.key});

  @override
  State<OneLineLabyrinthScreen> createState() => _OneLineLabyrinthScreenState();
}

class _OneLineLabyrinthScreenState extends State<OneLineLabyrinthScreen> {
  final math.Random _random = math.Random();
  _Difficulty _difficulty = _Difficulty.easy;
  late List<Offset> _nodes;
  late Set<_Edge> _edges;
  late int _start;
  late int _finish;
  late List<int> _path;
  int _level = 1;
  int _attempts = 0;

  bool get _complete => _path.length == _nodes.length && _path.last == _finish;

  @override
  void initState() {
    super.initState();
    _newPuzzle();
  }

  Iterable<int> _neighbors(int index) sync* {
    for (final edge in _edges) {
      if (edge.a == index) yield edge.b;
      if (edge.b == index) yield edge.a;
    }
  }

  void _newPuzzle() {
    final nodeCount = math.min(
      _difficulty.baseNodes + _level * _difficulty.levelStep,
      _difficulty.maxNodes,
    );
    _nodes = _buildNodes(nodeCount);
    final solution = List<int>.generate(nodeCount, (index) => index)
      ..shuffle(_random);
    _edges = {
      for (var i = 0; i + 1 < solution.length; i++)
        _Edge(solution[i], solution[i + 1]),
    };
    _addDecoyEdges(solution);
    _start = solution.first;
    _finish = solution.last;
    _path = [_start];
    _attempts = 0;
    setState(() {});
  }

  List<Offset> _buildNodes(int count) {
    const goldenAngle = 2.399963229728653;
    final center = Offset(
      0.5 + (_random.nextDouble() - 0.5) * 0.07,
      0.5 + (_random.nextDouble() - 0.5) * 0.07,
    );
    final nodes = <Offset>[];
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      final radius = 0.10 + math.sqrt(t) * _difficulty.radius;
      final angle = i * goldenAngle + _random.nextDouble() * 0.7;
      final jitter = Offset(
        (_random.nextDouble() - 0.5) * _difficulty.jitter,
        (_random.nextDouble() - 0.5) * _difficulty.jitter,
      );
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius) +
          jitter;
      nodes.add(Offset(point.dx.clamp(0.08, 0.92), point.dy.clamp(0.08, 0.92)));
    }
    return nodes;
  }

  void _addDecoyEdges(List<int> solution) {
    final solutionEdges = Set<_Edge>.from(_edges);
    var added = 0;
    var guard = 0;
    final target = _difficulty.extraEdges + _level ~/ 2;
    while (added < target && guard < 1000) {
      guard++;
      final a = _random.nextInt(solution.length);
      final b = _random.nextInt(solution.length);
      if (a == b) continue;
      final edge = _Edge(a, b);
      if (_edges.contains(edge) || solutionEdges.contains(edge)) continue;
      if ((_nodes[a] - _nodes[b]).distance > _difficulty.maxDecoyDistance) {
        continue;
      }
      _edges.add(edge);
      added++;
    }
  }

  void _resetPath() {
    _attempts++;
    _path = [_start];
    setState(() {});
  }

  void _tapNode(int index) {
    if (_complete || index == _path.last) return;

    if (_path.length >= 2 && index == _path[_path.length - 2]) {
      _path.removeLast();
      setState(() {});
      return;
    }

    if (_path.contains(index)) return;
    if (!_neighbors(_path.last).contains(index)) return;
    _path.add(index);
    setState(() {});
  }

  void _nextLevel() {
    _level++;
    _newPuzzle();
  }

  void _selectDifficulty(_Difficulty difficulty) {
    if (_difficulty == difficulty) return;
    _difficulty = difficulty;
    _level = 1;
    _newPuzzle();
  }

  Set<int> _candidateNodes() {
    if (_complete) return {};
    final visited = _path.toSet();
    return _neighbors(
      _path.last,
    ).where((index) => !visited.contains(index)).toSet();
  }

  void _handleBoardTap(Offset localPosition, double boardSize) {
    final hitRadius = boardSize * 0.075;
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _nodes.length; i++) {
      final point = Offset(_nodes[i].dx * boardSize, _nodes[i].dy * boardSize);
      final distance = (point - localPosition).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestDistance <= hitRadius) {
      _tapNode(bestIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _complete
        ? 'Exit reached. The next level adds knots and branches.'
        : 'Tap connected knots. Visit every knot once, then finish on the ring.';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              _Header(
                level: _level,
                attempts: _attempts,
                filled: _path.length,
                total: _nodes.length,
                difficulty: _difficulty,
                onDifficultyChanged: _selectDifficulty,
                onRestart: _resetPath,
                onNewPuzzle: _newPuzzle,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Center(
                      child: SizedBox.square(
                        dimension: boardSize,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) =>
                              _handleBoardTap(details.localPosition, boardSize),
                          child: CustomPaint(
                            painter: _GraphPainter(
                              nodes: _nodes,
                              edges: _edges,
                              path: _path,
                              start: _start,
                              finish: _finish,
                              candidates: _candidateNodes(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE7DEC3),
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
        ),
      ),
    );
  }
}

class _Edge {
  const _Edge(int first, int second)
    : a = first < second ? first : second,
      b = first < second ? second : first;

  final int a;
  final int b;

  @override
  bool operator ==(Object other) {
    return other is _Edge && other.a == a && other.b == b;
  }

  @override
  int get hashCode => Object.hash(a, b);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.level,
    required this.attempts,
    required this.filled,
    required this.total,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onRestart,
    required this.onNewPuzzle,
  });

  final int level;
  final int attempts;
  final int filled;
  final int total;
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onRestart;
  final VoidCallback onNewPuzzle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'One Line Labyrinth',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
              child: _Metric(label: 'Path', value: '$filled/$total'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Metric(label: 'Tries', value: '$attempts'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _DifficultyPicker(
          difficulty: difficulty,
          onChanged: onDifficultyChanged,
        ),
      ],
    );
  }
}

enum _Difficulty {
  easy('Easy', 7, 12, 1, 2, 0.32, 0.07, 0.42),
  normal('Normal', 12, 22, 2, 5, 0.38, 0.09, 0.36),
  hard('Hard', 18, 34, 3, 10, 0.43, 0.11, 0.32);

  const _Difficulty(
    this.label,
    this.baseNodes,
    this.maxNodes,
    this.levelStep,
    this.extraEdges,
    this.radius,
    this.jitter,
    this.maxDecoyDistance,
  );

  final String label;
  final int baseNodes;
  final int maxNodes;
  final int levelStep;
  final int extraEdges;
  final double radius;
  final double jitter;
  final double maxDecoyDistance;
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.difficulty, required this.onChanged});

  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Difficulty>(
      segments: [
        for (final option in _Difficulty.values)
          ButtonSegment<_Difficulty>(value: option, label: Text(option.label)),
      ],
      selected: {difficulty},
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
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF24221C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFFC1B48C)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.path,
    required this.start,
    required this.finish,
    required this.candidates,
  });

  final List<Offset> nodes;
  final Set<_Edge> edges;
  final List<int> path;
  final int start;
  final int finish;
  final Set<int> candidates;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide;
    Offset point(int index) =>
        Offset(nodes[index].dx * size.width, nodes[index].dy * size.height);

    final background = Paint()
      ..color = const Color(0xFF1D1B16)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      background,
    );

    final edgePaint = Paint()
      ..color = const Color(0xFF5A5139)
      ..strokeWidth = scale * 0.012
      ..strokeCap = StrokeCap.round;
    for (final edge in edges) {
      canvas.drawLine(point(edge.a), point(edge.b), edgePaint);
    }

    final pathPaint = Paint()
      ..color = const Color(0xFFD6A936)
      ..strokeWidth = scale * 0.022
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < path.length; i++) {
      canvas.drawLine(point(path[i]), point(path[i + 1]), pathPaint);
    }

    for (var i = 0; i < nodes.length; i++) {
      final visitedOrder = path.indexOf(i);
      final isVisited = visitedOrder >= 0;
      final isCandidate = candidates.contains(i);
      final center = point(i);
      final radius = scale * (isCandidate ? 0.045 : 0.038);
      final fill = Paint()
        ..color = isVisited
            ? const Color(0xFFD6A936)
            : isCandidate
            ? const Color(0xFF6B5D35)
            : const Color(0xFF39342A);
      final outline = Paint()
        ..color = i == finish
            ? Colors.white
            : isCandidate
            ? const Color(0xFFEDE2C0)
            : const Color(0xFF746746)
        ..strokeWidth = scale * 0.009
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, outline);

      if (i == start) {
        canvas.drawCircle(
          center,
          radius * 0.42,
          Paint()..color = const Color(0xFF141411),
        );
      } else if (i == finish) {
        canvas.drawCircle(
          center,
          radius * 0.48,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = scale * 0.008,
        );
      } else if (isVisited) {
        final painter = TextPainter(
          text: TextSpan(
            text: '${visitedOrder + 1}',
            style: TextStyle(
              color: const Color(0xFF141411),
              fontSize: scale * 0.034,
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
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.path != path ||
        oldDelegate.candidates != candidates;
  }
}

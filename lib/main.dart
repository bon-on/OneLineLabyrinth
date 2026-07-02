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
  late Set<int> _open;
  late int _start;
  late int _finish;
  late List<int> _path;
  int _level = 1;
  int _attempts = 0;

  int get _size => _difficulty.size;
  bool get _complete => _path.length == _open.length && _path.last == _finish;

  @override
  void initState() {
    super.initState();
    _newPuzzle();
  }

  int _index(int row, int col) => row * _size + col;

  Iterable<int> _neighbors(int index) sync* {
    final row = index ~/ _size;
    final col = index % _size;
    if (row > 0) yield _index(row - 1, col);
    if (row + 1 < _size) yield _index(row + 1, col);
    if (col > 0) yield _index(row, col - 1);
    if (col + 1 < _size) yield _index(row, col + 1);
  }

  void _newPuzzle() {
    final targetLength = math.min(
      _difficulty.baseLength + _level * _difficulty.levelStep,
      _size * _size,
    );

    List<int> bestPath = [];
    for (var attempt = 0; attempt < 90; attempt++) {
      final start = _random.nextInt(_size * _size);
      final path = [start];
      final seen = {start};
      if (_growPath(path, seen, targetLength)) {
        bestPath = path;
        break;
      }
      if (path.length > bestPath.length) {
        bestPath = List<int>.from(path);
      }
    }

    var orderedOpen = bestPath;
    if (orderedOpen.length < 2) {
      orderedOpen = [_index(0, 0), _index(0, 1)];
    }
    if (_random.nextBool()) {
      orderedOpen = orderedOpen.reversed.toList();
    }
    _open = orderedOpen.toSet();
    _start = orderedOpen.first;
    _finish = orderedOpen.last;
    _path = [_start];
    _attempts = 0;
    setState(() {});
  }

  bool _growPath(List<int> path, Set<int> seen, int targetLength) {
    if (path.length >= targetLength) return true;
    final current = path.last;
    final candidates = _neighbors(
      current,
    ).where((index) => !seen.contains(index)).toList()..shuffle(_random);
    candidates.sort(
      (a, b) => _onwardCount(a, seen).compareTo(_onwardCount(b, seen)),
    );

    for (final next in candidates) {
      seen.add(next);
      path.add(next);
      if (_growPath(path, seen, targetLength)) return true;
      if (path.length > targetLength * 0.82 && _random.nextDouble() < 0.18) {
        return false;
      }
      path.removeLast();
      seen.remove(next);
    }
    return false;
  }

  int _onwardCount(int index, Set<int> seen) {
    return _neighbors(index).where((next) => !seen.contains(next)).length;
  }

  void _resetPath() {
    _attempts++;
    _path = [_start];
    setState(() {});
  }

  void _tapCell(int index) {
    if (_complete || !_open.contains(index)) return;
    if (index == _path.last) return;

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

  @override
  Widget build(BuildContext context) {
    final status = _complete
        ? 'Exit reached. The next level opens a longer path.'
        : 'Tap highlighted neighbors. Cover every open tile once, then end on the ring.';
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
                total: _open.length,
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
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _size * _size,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _size,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemBuilder: (context, index) {
                            return _LabyrinthTile(
                              index: index,
                              isOpen: _open.contains(index),
                              isStart: index == _start,
                              isFinish: index == _finish,
                              order: _path.indexOf(index),
                              isCandidate:
                                  !_complete &&
                                  _open.contains(index) &&
                                  !_path.contains(index) &&
                                  _neighbors(_path.last).contains(index),
                              onTap: () => _tapCell(index),
                            );
                          },
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
  easy('Easy', 5, 10, 2),
  normal('Normal', 6, 18, 3),
  hard('Hard', 7, 30, 4);

  const _Difficulty(this.label, this.size, this.baseLength, this.levelStep);

  final String label;
  final int size;
  final int baseLength;
  final int levelStep;
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
          ButtonSegment<_Difficulty>(
            value: option,
            label: Text('${option.label} ${option.size}x${option.size}'),
          ),
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
      width: 62,
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

class _LabyrinthTile extends StatelessWidget {
  const _LabyrinthTile({
    required this.index,
    required this.isOpen,
    required this.isStart,
    required this.isFinish,
    required this.order,
    required this.isCandidate,
    required this.onTap,
  });

  final int index;
  final bool isOpen;
  final bool isStart;
  final bool isFinish;
  final int order;
  final bool isCandidate;
  final VoidCallback onTap;

  bool get _visited => order >= 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: !isOpen
          ? const Color(0xFF252525)
          : _visited
          ? const Color(0xFFD6A936)
          : isCandidate
          ? const Color(0xFF6B5D35)
          : const Color(0xFF3D3930),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isCandidate
            ? const BorderSide(color: Color(0xFFEDE2C0), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isOpen ? onTap : null,
        child: Center(child: _marker()),
      ),
    );
  }

  Widget _marker() {
    if (!isOpen) return const SizedBox.shrink();
    if (isStart) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 14, color: Color(0xFF141411)),
          SizedBox(height: 2),
          Text(
            'START',
            style: TextStyle(
              color: Color(0xFF141411),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }
    if (isFinish) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radio_button_unchecked, size: 22, color: Colors.white),
          SizedBox(height: 2),
          Text(
            'EXIT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }
    if (_visited) {
      return Text(
        '${order + 1}',
        style: const TextStyle(
          color: Color(0xFF151515),
          fontWeight: FontWeight.w900,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

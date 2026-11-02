import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../puzzle_generator.dart';
import '../art/sky_theme.dart';
import '../art/star_art.dart';
import '../meta/level_stars.dart';
import '../meta/sky_progress.dart';
import 'sky_ui.dart';

/// Level map: per difficulty, levels 1 to best + 1 are open and show their
/// best stars; later levels are locked. Picking an open level starts it.
class LevelMapOverlay extends StatefulWidget {
  const LevelMapOverlay({
    super.key,
    required this.palette,
    required this.progress,
    required this.difficulty,
    required this.currentLevel,
    required this.onPick,
    required this.onClose,
  });

  final SkyPalette palette;
  final SkyProgress progress;
  final PuzzleDifficulty difficulty;
  final int currentLevel;
  final void Function(PuzzleDifficulty difficulty, int level) onPick;
  final VoidCallback onClose;

  @override
  State<LevelMapOverlay> createState() => _LevelMapOverlayState();
}

class _LevelMapOverlayState extends State<LevelMapOverlay> {
  late PuzzleDifficulty _difficulty = widget.difficulty;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final progress = widget.progress;
    final unlocked = progress.highestUnlocked(_difficulty);
    final earned =
        progress.levelStars[_difficulty]?.values.fold(0, (a, b) => a + b) ?? 0;
    return SkyOverlay(
      palette: p,
      title: 'Level map',
      subtitle:
          '${_difficulty.label}: $earned stars - levels up to $unlocked open',
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                for (final d in PuzzleDifficulty.values) ...[
                  Expanded(
                    child: SkyButton(
                      palette: p,
                      label: d.label,
                      height: 36,
                      primary: d == _difficulty,
                      onPressed: () => setState(() => _difficulty = d),
                    ),
                  ),
                  if (d != PuzzleDifficulty.values.last)
                    const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = math.max(
                  3,
                  math.min(6, (constraints.maxWidth / 96).floor()),
                );
                var count = math.max(12, unlocked + columns);
                count = (count / columns).ceil() * columns;
                return GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: count,
                  itemBuilder: (context, i) {
                    final level = i + 1;
                    final open = level <= unlocked;
                    return _LevelNode(
                      palette: p,
                      level: level,
                      open: open,
                      current:
                          _difficulty == widget.difficulty &&
                          level == widget.currentLevel,
                      stars: progress.starsFor(_difficulty, level),
                      size: _difficulty.columnsFor(level),
                      rows: _difficulty.rowsFor(level),
                      onTap: open
                          ? () => widget.onPick(_difficulty, level)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.palette,
    required this.level,
    required this.open,
    required this.current,
    required this.stars,
    required this.size,
    required this.rows,
    required this.onTap,
  });

  final SkyPalette palette;
  final int level;
  final bool open;
  final bool current;
  final int stars;
  final int size;
  final int rows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final solved = stars > 0;
    return Semantics(
      button: open,
      enabled: open,
      label: open
          ? 'Level $level, $stars of ${LevelStars.max} stars'
          : 'Level $level, locked',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: open
                  ? p.panel.withValues(alpha: 0.9)
                  : p.skyTop.withValues(alpha: 0.5),
              border: Border.all(
                color: current
                    ? p.gold
                    : solved
                    ? p.thread.withValues(alpha: 0.8)
                    : p.panelBorder.withValues(alpha: open ? 1 : 0.4),
                width: current ? 2 : 1,
              ),
              boxShadow: solved
                  ? <BoxShadow>[
                      BoxShadow(
                        color: p.thread.withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (open)
                      Text(
                        '$level',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: solved ? p.threadCore : p.text,
                        ),
                      )
                    else
                      Icon(Icons.lock_rounded, color: p.muted, size: 22),
                    Text(
                      '${size}x$rows',
                      style: TextStyle(fontSize: 10, color: p.muted),
                    ),
                    const SizedBox(height: 3),
                    RatingStars(earned: stars, palette: p, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

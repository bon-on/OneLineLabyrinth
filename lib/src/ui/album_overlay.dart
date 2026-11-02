import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../puzzle_generator.dart';
import '../art/sky_theme.dart';
import '../art/star_art.dart';
import '../meta/constellations.dart';
import '../meta/sky_progress.dart';
import 'sky_ui.dart';

/// Constellation album: one slot per difficulty and level 1-12. A slot shows
/// the line the player drew on the first clear; unknown slots are "???".
class AlbumOverlay extends StatelessWidget {
  const AlbumOverlay({
    super.key,
    required this.palette,
    required this.progress,
    required this.onClose,
  });

  final SkyPalette palette;
  final SkyProgress progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SkyOverlay(
      palette: p,
      title: 'Constellation album',
      subtitle:
          '${progress.albumCount} / ${Constellations.albumSize} found - '
          'first clears of levels 1-${Constellations.albumLevels}',
      onClose: onClose,
      maxWidth: 900,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = math.max(
            3,
            math.min(6, (constraints.maxWidth / 130).floor()),
          );
          return CustomScrollView(
            shrinkWrap: true,
            slivers: [
              for (final d in PuzzleDifficulty.values) ...[
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  sliver: SliverToBoxAdapter(
                    child: SectionLabel(d.label, palette: p),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _AlbumSlot(
                        palette: p,
                        difficulty: d,
                        level: i + 1,
                        shape: progress.album[Constellations.slotKey(d, i + 1)],
                        stars: progress.starsFor(d, i + 1),
                      ),
                      childCount: Constellations.albumLevels,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AlbumSlot extends StatelessWidget {
  const _AlbumSlot({
    required this.palette,
    required this.difficulty,
    required this.level,
    required this.shape,
    required this.stars,
  });

  final SkyPalette palette;
  final PuzzleDifficulty difficulty;
  final int level;
  final List<int>? shape;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final found = shape != null;
    final name = found ? Constellations.nameFor(difficulty, level) : '???';
    return Semantics(
      label: found ? '$name, level $level' : 'Unknown constellation',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: p.skyTop.withValues(alpha: found ? 0.75 : 0.45),
            border: Border.all(
              color: found
                  ? p.thread.withValues(alpha: 0.6)
                  : p.panelBorder.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: ConstellationPainter(
                    points: found
                        ? AlbumShape.decode(shape!)
                        : const <math.Point<double>>[],
                    palette: p,
                    seed: difficulty.index * 50 + level,
                  ),
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: found ? p.text : p.muted,
                ),
              ),
              Text(
                'Level $level',
                style: TextStyle(fontSize: 10, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

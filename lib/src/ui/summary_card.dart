import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../art/sky_theme.dart';
import '../art/star_art.dart';
import '../meta/sky_progress.dart';
import 'sky_ui.dart';

/// Level result card: constellation name, stars, time, best, XP and unlocks.
/// Sits beside or below the board so the finished constellation stays
/// visible. Scrolls instead of overflowing on short screens.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.palette,
    required this.outcome,
    required this.progress,
    required this.difficultyLabel,
    required this.streak,
    required this.starReveal,
    required this.onNext,
    required this.onReplay,
    this.compact = false,
  });

  final SkyPalette palette;
  final LevelOutcome outcome;

  /// Current progress (for the XP bar after the solve).
  final SkyProgress progress;
  final String difficultyLabel;

  /// Consecutive clean solves in this session.
  final int streak;

  /// 0..3, raised by the screen clock so stars pop in one by one.
  final ValueListenable<double> starReveal;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final result = outcome.result;
    final chips = <Widget>[
      if (outcome.isNewBest) _Chip('New best!', p.gold, p),
      if (outcome.newConstellation) _Chip('New constellation!', p.accent, p),
      if (!outcome.firstClear && outcome.starsImproved)
        _Chip('More stars!', p.thread, p),
      if (streak >= 2) _Chip('Clean streak x$streak', p.thread, p),
    ];
    return GlassPanel(
      palette: p,
      highlight: true,
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 12, 12, compact ? 8 : 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              SectionLabel(
                'Level ${result.level} $difficultyLabel - constellation',
                palette: p,
              ),
              const SizedBox(height: 2),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    outcome.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: p.threadCore,
                      shadows: <Shadow>[
                        Shadow(color: p.thread, blurRadius: 14),
                      ],
                    ),
                  ),
                ),
                RatingStars(
                  earned: result.stars.count,
                  palette: p,
                  size: compact ? 22 : 26,
                  reveal: starReveal,
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${compact ? 'Lv ${result.level} $difficultyLabel - ${result.seconds}s' : 'Solved in ${result.seconds}s'}'
                  '${result.stars.clean ? ' - clean' : ''}'
                  '${result.stars.swift ? ' - swift' : ''}',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
                ...chips,
              ],
            ),
            SizedBox(height: compact ? 4 : 10),
            Row(
              children: [
                Text(
                  '+${outcome.xpGained} XP',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: p.thread,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: XpBar(
                    palette: p,
                    level: progress.level,
                    into: progress.xpIntoLevel,
                    needed: progress.xpForNextLevel,
                    compact: compact,
                  ),
                ),
              ],
            ),
            if (outcome.leveledUp) ...[
              SizedBox(height: compact ? 3 : 6),
              Text(
                'Sky Lv ${outcome.levelAfter}!'
                '${outcome.newlyUnlockedThemes.isEmpty ? '' : ' ${outcome.newlyUnlockedThemes.map((t) => t.label).join(', ')} unlocked'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.gold,
                ),
              ),
            ],
            SizedBox(height: compact ? 5 : 12),
            Row(
              children: [
                Expanded(
                  child: SkyButton(
                    palette: p,
                    label: 'Replay',
                    icon: Icons.replay_rounded,
                    height: compact ? 38 : 42,
                    onPressed: onReplay,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SkyButton(
                    palette: p,
                    label: 'Next Level',
                    icon: Icons.arrow_forward_rounded,
                    height: compact ? 38 : 42,
                    primary: true,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color, this.palette);

  final String text;
  final Color color;
  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

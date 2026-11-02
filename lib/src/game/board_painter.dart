import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../puzzle_generator.dart';
import '../art/sky_theme.dart';
import '../art/star_art.dart';
import 'board_fx.dart';

/// Seconds the completion wave takes to run from start to ring.
const double completionWaveSeconds = 1.1;

/// Paints the glass board: links as faint threads, knots as stars, the drawn
/// line as a glowing thread, and every trailing effect in [fx]. Repaints from
/// [time] and [drag] only; rules never wait for it.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.puzzle,
    required this.path,
    required this.candidates,
    required this.palette,
    required this.fx,
    required this.time,
    required this.drag,
    required this.deadEnd,
    required this.complete,
    this.name,
  }) : super(repaint: Listenable.merge(<Listenable>[time, drag]));

  final GridPuzzle puzzle;
  final List<int> path;
  final Set<int> candidates;
  final SkyPalette palette;
  final BoardFx fx;
  final ValueListenable<double> time;

  /// Pointer position (board-local) while dragging, else null.
  final ValueListenable<Offset?> drag;
  final bool deadEnd;
  final bool complete;

  /// Constellation name shown in the completion banner.
  final String? name;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final p = palette;
    final side = size.shortestSide;
    final cell = side / math.max(puzzle.columns, puzzle.rows);
    final r = cell * 0.145;
    Offset at(int index) {
      final node = puzzle.nodes[index];
      return Offset(node.x * side, node.y * side);
    }

    _paintPanel(canvas, size, p);

    // Links: faint threads; the ones leaving the line end are brighter.
    final link = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.03
      ..color = p.star.withValues(alpha: 0.17);
    final hot = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.045
      ..color = p.accent.withValues(alpha: 0.5);
    final end = path.last;
    for (final edge in puzzle.edges) {
      final isHot =
          !complete &&
          ((edge.a == end && candidates.contains(edge.b)) ||
              (edge.b == end && candidates.contains(edge.a)));
      canvas.drawLine(at(edge.a), at(edge.b), isHot ? hot : link);
    }

    final completeAt = fx.completedAt;
    final wave = completeAt == null
        ? -1.0
        : ((t - completeAt) / completionWaveSeconds).clamp(0.0, 1.0);

    // Trailing effects drawn under the line.
    for (final e in fx.events) {
      final k = e.progress(t);
      switch (e.kind) {
        case FxKind.scatter:
          final pts = <Offset>[for (final n in e.nodes) at(n)];
          paintThread(
            canvas,
            pts,
            p,
            width: cell * 0.075 * (1 - k),
            shimmer: false,
            color: Color.lerp(p.thread, p.danger, 0.5),
            glow: 1 - k,
          );
          for (var i = 0; i < pts.length; i++) {
            final drift = Offset(
              math.sin(i * 2.3) * cell * 0.3,
              cell * 0.5 * k + math.cos(i * 1.7) * cell * 0.1,
            );
            paintSparkle(
              canvas,
              pts[i] + drift * k,
              r * 0.7 * (1 - k),
              p.threadCore.withValues(alpha: 1 - k),
            );
          }
        case FxKind.retract:
          final from = at(e.nodes[1]);
          final to = at(e.nodes[0]);
          final tip = Offset.lerp(from, to, 1 - Curves.easeIn.transform(k))!;
          canvas.drawLine(
            from,
            tip,
            Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = cell * 0.07 * (1 - k * 0.5)
              ..color = Color.lerp(
                p.thread,
                p.danger,
                0.6,
              )!.withValues(alpha: 1 - k),
          );
          canvas.drawCircle(
            to,
            r * (1.3 + k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.16
              ..color = p.danger.withValues(alpha: 0.7 * (1 - k)),
          );
        default:
          break;
      }
    }

    // The drawn line.
    final pts = <Offset>[for (final n in path) at(n)];
    final breathing = completeAt != null && wave >= 1
        ? 1 + 0.35 * math.sin((t - completeAt) * 2.4)
        : 1.0;
    paintThread(canvas, pts, p, width: cell * 0.075, time: t, glow: breathing);
    if (completeAt != null && wave < 1) {
      _paintWave(canvas, pts, cell, wave, p);
    }

    // Drag preview: a loose thread from the line end to the finger.
    final pointer = drag.value;
    if (pointer != null && !complete) {
      _paintDashed(
        canvas,
        at(end),
        pointer,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = cell * 0.035
          ..color = p.thread.withValues(alpha: 0.45),
        cell * 0.12,
      );
    }

    // Hint: a dashed guide from the line end and a beacon on the target.
    final hint = fx.hintNode(t);
    if (hint != null && !complete) {
      _paintDashed(
        canvas,
        at(end),
        at(hint),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = cell * 0.04
          ..color = p.gold.withValues(alpha: 0.8),
        cell * 0.1,
      );
    }

    // Knots.
    final order = <int, int>{for (var i = 0; i < path.length; i++) path[i]: i};
    for (var i = 0; i < puzzle.nodeCount; i++) {
      final c = at(i);
      final position = order[i];
      var pop = 0.0;
      final visited = fx.visitedAt[i];
      if (visited != null) {
        final k = ((t - visited) / 0.35).clamp(0.0, 1.0);
        pop = math.sin(k * math.pi) * (1 - k * 0.6);
      }
      if (completeAt != null && position != null && path.length > 1) {
        final arrive = position / (path.length - 1);
        final dt = (wave - arrive) * completionWaveSeconds / 0.3;
        if (dt >= 0 && dt <= 1) pop = math.max(pop, math.sin(dt * math.pi));
      }
      final KnotLook look;
      if (i == puzzle.start) {
        look = KnotLook.start;
      } else if (i == puzzle.finish) {
        look = complete ? KnotLook.finishLit : KnotLook.finish;
      } else if (position != null) {
        look = KnotLook.visited;
      } else if (candidates.contains(i)) {
        look = KnotLook.candidate;
      } else {
        look = KnotLook.idle;
      }
      paintKnot(canvas, c, r, look, p, time: t, pop: pop, seed: i);
    }

    // Line end: a living spark, red and pulsing in a dead end.
    if (!complete) {
      final c = at(end);
      if (deadEnd) {
        final pulse = 0.5 + 0.5 * math.sin(t * 7);
        paintGlow(
          canvas,
          c,
          r * 3.4,
          p.danger.withValues(alpha: 0.35 + 0.3 * pulse),
        );
        canvas.drawCircle(
          c,
          r * (1.7 + 0.35 * pulse),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.2
            ..color = p.danger.withValues(alpha: 0.85),
        );
      } else {
        final pulse = 0.5 + 0.5 * math.sin(t * 5);
        paintGlow(
          canvas,
          c,
          r * (2.4 + pulse),
          p.threadCore.withValues(alpha: 0.35),
        );
      }
    }

    // Effects drawn over the stars.
    for (final e in fx.events) {
      final k = e.progress(t);
      switch (e.kind) {
        case FxKind.visit:
          final c = at(e.nodes.first);
          canvas.drawCircle(
            c,
            r * (1.2 + 2.2 * Curves.easeOut.transform(k)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.18 * (1 - k)
              ..color = p.threadCore.withValues(alpha: 0.8 * (1 - k)),
          );
          _paintBurst(canvas, c, r * 3.2, k, 6, e.nodes.first, p.threadCore);
        case FxKind.invalid:
          final c = at(e.nodes.first);
          final shake = math.sin(k * math.pi * 7) * r * 0.6 * (1 - k);
          canvas.drawCircle(
            c + Offset(shake, 0),
            r * 1.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.22
              ..color = p.danger.withValues(alpha: 1 - k),
          );
          final x = r * 0.7;
          final cross = Paint()
            ..strokeWidth = r * 0.2
            ..strokeCap = StrokeCap.round
            ..color = p.danger.withValues(alpha: 1 - k);
          final cc = c + Offset(shake, 0);
          canvas.drawLine(cc + Offset(-x, -x), cc + Offset(x, x), cross);
          canvas.drawLine(cc + Offset(-x, x), cc + Offset(x, -x), cross);
        case FxKind.hint:
          final c = at(e.nodes.first);
          for (var ring = 0; ring < 2; ring++) {
            final phase = ((t - e.start) * 1.2 + ring * 0.5) % 1.0;
            canvas.drawCircle(
              c,
              r * (1.3 + 2.4 * phase),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = r * 0.2
                ..color = p.gold.withValues(alpha: 0.9 * (1 - phase)),
            );
          }
        case FxKind.complete:
          final waveEnd = e.start + completionWaveSeconds;
          if (t >= waveEnd) {
            final kb = ((t - waveEnd) / 1.4).clamp(0.0, 1.0);
            if (kb < 1) {
              _paintBurst(
                canvas,
                at(e.nodes.last),
                cell * 1.8,
                kb,
                22,
                3,
                p.gold,
              );
              _paintBurst(
                canvas,
                at(e.nodes.last),
                cell * 1.1,
                kb,
                14,
                9,
                p.threadCore,
              );
            }
          }
          _paintBanner(canvas, size, t - e.start, p);
        default:
          break;
      }
    }
  }

  void _paintPanel(Canvas canvas, Size size, SkyPalette p) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.shortestSide * 0.04),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, <Color>[
          p.panel.withValues(alpha: 0.62),
          p.skyTop.withValues(alpha: 0.72),
        ]),
    );
    paintGlow(
      canvas,
      rect.center,
      size.shortestSide * 0.6,
      p.accent.withValues(alpha: 0.07),
    );
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = p.panelBorder.withValues(alpha: 0.9),
    );
  }

  void _paintWave(
    Canvas canvas,
    List<Offset> pts,
    double cell,
    double wave,
    SkyPalette p,
  ) {
    if (pts.length < 2) return;
    final metric = polyline(pts).computeMetrics().firstOrNull;
    if (metric == null) return;
    final head = metric.length * wave;
    final band = cell * 1.4;
    final segment = metric.extractPath(math.max(0, head - band), head);
    canvas.drawPath(
      segment,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.22
        ..color = p.threadCore.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
    );
    final tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      paintGlow(
        canvas,
        tangent.position,
        cell * 0.5,
        p.threadCore.withValues(alpha: 0.9),
      );
    }
  }

  void _paintBurst(
    Canvas canvas,
    Offset c,
    double reach,
    double k,
    int count,
    int seed,
    Color color,
  ) {
    final ease = Curves.easeOutCubic.transform(k);
    for (var i = 0; i < count; i++) {
      final a = i / count * math.pi * 2 + seed * 0.7;
      final speed = 0.55 + 0.45 * ((i * 37 + seed * 11) % 10) / 10;
      final pos = c + Offset(math.cos(a), math.sin(a)) * reach * speed * ease;
      paintSparkle(
        canvas,
        pos,
        reach * 0.07 * (1 - k * 0.7),
        color.withValues(alpha: (1 - k).clamp(0.0, 1.0)),
        rotation: a,
      );
    }
  }

  void _paintBanner(Canvas canvas, Size size, double since, SkyPalette p) {
    final label = name;
    if (label == null) return;
    const appear = completionWaveSeconds;
    const hold = 2.6;
    if (since < appear || since > appear + hold) return;
    final k = (since - appear) / hold;
    final alpha = k < 0.15
        ? k / 0.15
        : k > 0.8
        ? (1 - k) / 0.2
        : 1.0;
    final fontSize = (size.shortestSide * 0.06).clamp(15.0, 34.0);
    final text = TextPainter(
      text: TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: 'CONSTELLATION\n',
            style: TextStyle(
              fontSize: fontSize * 0.42,
              letterSpacing: fontSize * 0.18,
              fontWeight: FontWeight.w700,
              color: p.muted.withValues(alpha: alpha),
            ),
          ),
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: p.threadCore.withValues(alpha: alpha),
              shadows: <Shadow>[
                Shadow(
                  color: p.thread.withValues(alpha: alpha),
                  blurRadius: fontSize * 0.6,
                ),
              ],
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);
    final rise = (1 - Curves.easeOut.transform((k / 0.2).clamp(0.0, 1.0))) * 12;
    final center = Offset(size.width / 2, size.height / 2 + rise);
    final box = Rect.fromCenter(
      center: center,
      width: text.width + fontSize * 1.6,
      height: text.height + fontSize * 0.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(fontSize * 0.6)),
      Paint()..color = p.skyTop.withValues(alpha: 0.72 * alpha),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(fontSize * 0.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = p.gold.withValues(alpha: 0.6 * alpha),
    );
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  void _paintDashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
  ) {
    final length = (b - a).distance;
    if (length < 1) return;
    final dir = (b - a) / length;
    for (var d = 0.0; d < length; d += dash * 2) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.puzzle != puzzle ||
      old.path != path ||
      old.palette != palette ||
      old.deadEnd != deadEnd ||
      old.complete != complete ||
      old.name != name ||
      !setEquals(old.candidates, candidates) ||
      old.time != time ||
      old.drag != drag;
}

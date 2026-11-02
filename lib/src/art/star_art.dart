import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'sky_theme.dart';

/// A four-point sparkle (concave diamond), the basic star glyph.
void paintSparkle(
  Canvas canvas,
  Offset c,
  double radius,
  Color color, {
  double rotation = 0,
  double waist = 0.22,
}) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = rotation + i * math.pi / 4 - math.pi / 2;
    final r = i.isEven ? radius : radius * waist;
    final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// A soft radial glow (cheaper than a blur mask filter).
void paintGlow(Canvas canvas, Offset c, double radius, Color color) {
  if (radius <= 0) return;
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        radius,
        <Color>[
          color,
          color.withValues(alpha: color.a * 0.35),
          color.withValues(alpha: 0),
        ],
        const <double>[0, 0.35, 1],
      ),
  );
}

/// Visual state of one knot star on the board.
enum KnotLook { idle, candidate, visited, start, finish, finishLit }

/// Draws one knot star of radius unit [r] (about a fifth of a cell).
void paintKnot(
  Canvas canvas,
  Offset c,
  double r,
  KnotLook look,
  SkyPalette p, {
  double time = 0,
  double pop = 0,
  int seed = 0,
}) {
  final twinkle = 0.5 + 0.5 * math.sin(time * 1.7 + seed * 1.3);
  final scale = 1 + pop * 0.7;
  switch (look) {
    case KnotLook.idle:
      paintGlow(canvas, c, r * 1.9, p.star.withValues(alpha: 0.22));
      paintSparkle(
        canvas,
        c,
        r * (0.85 + 0.1 * twinkle),
        p.star.withValues(alpha: 0.75),
      );
      canvas.drawCircle(c, r * 0.22, Paint()..color = p.star);
    case KnotLook.candidate:
      final pulse = 0.5 + 0.5 * math.sin(time * 4 + seed);
      paintGlow(canvas, c, r * 2.3, p.accent.withValues(alpha: 0.35));
      canvas.drawCircle(
        c,
        r * (1.25 + 0.12 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..color = p.accent.withValues(alpha: 0.55 + 0.35 * pulse),
      );
      paintSparkle(canvas, c, r * 1.0, p.star);
      canvas.drawCircle(c, r * 0.26, Paint()..color = p.threadCore);
    case KnotLook.visited:
      paintGlow(canvas, c, r * 2.6 * scale, p.thread.withValues(alpha: 0.55));
      paintSparkle(canvas, c, r * 1.25 * scale, p.thread);
      paintSparkle(
        canvas,
        c,
        r * 0.8 * scale,
        p.threadCore,
        rotation: math.pi / 4,
        waist: 0.3,
      );
      canvas.drawCircle(c, r * 0.3 * scale, Paint()..color = p.threadCore);
    case KnotLook.start:
      paintGlow(canvas, c, r * 3.2 * scale, p.thread.withValues(alpha: 0.6));
      final rays = Paint()
        ..color = p.threadCore.withValues(alpha: 0.5)
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = time * 0.4 + i * math.pi / 4;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * r * 1.5, c + dir * r * 2.2, rays);
      }
      paintSparkle(canvas, c, r * 1.6 * scale, p.thread, waist: 0.26);
      paintSparkle(
        canvas,
        c,
        r * 1.0 * scale,
        p.threadCore,
        rotation: math.pi / 4,
        waist: 0.3,
      );
      canvas.drawCircle(c, r * 0.36, Paint()..color = p.threadCore);
    case KnotLook.finish:
    case KnotLook.finishLit:
      final lit = look == KnotLook.finishLit;
      final ringColor = lit ? p.gold : p.threadCore;
      paintGlow(
        canvas,
        c,
        r * 2.8,
        (lit ? p.gold : p.accent).withValues(alpha: lit ? 0.6 : 0.3),
      );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.2
        ..color = ringColor;
      canvas.drawCircle(c, r * 1.45 * scale, ring);
      // A small moon orbiting the ring marks the exit.
      final a = time * 1.2 + seed;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 1.45 * scale,
        r * 0.24,
        Paint()..color = ringColor,
      );
      paintSparkle(
        canvas,
        c,
        r * 0.8 * scale,
        lit ? p.threadCore : p.star.withValues(alpha: 0.9),
      );
  }
}

/// Builds a polyline path through [points].
Path polyline(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

/// Draws the glowing thread through [points]: a wide soft glow, the coloured
/// thread and a bright core, plus light travelling along it when [shimmer].
void paintThread(
  Canvas canvas,
  List<Offset> points,
  SkyPalette p, {
  required double width,
  double time = 0,
  bool shimmer = true,
  double glow = 1,
  Color? color,
}) {
  if (points.length < 2) return;
  final path = polyline(points);
  final base = color ?? p.thread;
  Paint stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;
  canvas.drawPath(
    path,
    stroke(width * 3.2, base.withValues(alpha: 0.18 * glow))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 1.2),
  );
  canvas.drawPath(path, stroke(width, base));
  canvas.drawPath(path, stroke(width * 0.36, p.threadCore));
  if (!shimmer) return;
  final spacing = width * 9;
  final dash = width * 2.4;
  final highlight = stroke(width * 0.7, p.threadCore.withValues(alpha: 0.9));
  for (final metric in path.computeMetrics()) {
    var offset = (time * width * 6) % spacing;
    while (offset < metric.length) {
      canvas.drawPath(
        metric.extractPath(offset, math.min(offset + dash, metric.length)),
        highlight,
      );
      offset += spacing;
    }
  }
}

/// Small constellation picture of a solved line (album, result card).
/// [points] are normalized (0..1) in path order. Empty points draw a faint
/// unknown constellation.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.points,
    required this.palette,
    this.time,
    this.seed = 0,
  }) : super(repaint: time);

  final List<math.Point<double>> points;
  final SkyPalette palette;
  final ValueListenable<double>? time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final t = time?.value ?? 0;
    if (points.isEmpty) {
      final random = math.Random(seed);
      for (var i = 0; i < 7; i++) {
        final c =
            origin +
            Offset(
              side * (0.15 + random.nextDouble() * 0.7),
              side * (0.15 + random.nextDouble() * 0.7),
            );
        canvas.drawCircle(
          c,
          side * 0.018,
          Paint()..color = palette.muted.withValues(alpha: 0.35),
        );
      }
      return;
    }
    // Fit the shape into the box with a margin.
    var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (final p in points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    final span = math.max(0.05, math.max(maxX - minX, maxY - minY));
    final scale = side * 0.8 / span;
    final offset =
        origin +
        Offset(
          (side - (maxX - minX) * scale) / 2,
          (side - (maxY - minY) * scale) / 2,
        );
    final pts = <Offset>[
      for (final p in points)
        offset + Offset((p.x - minX) * scale, (p.y - minY) * scale),
    ];
    final width = math.max(1.2, side * 0.022);
    paintThread(
      canvas,
      pts,
      palette,
      width: width,
      time: t,
      shimmer: time != null,
      glow: 0.8,
    );
    for (var i = 0; i < pts.length; i++) {
      final r = width * (i == 0 || i == pts.length - 1 ? 1.9 : 1.2);
      paintSparkle(canvas, pts[i], r * 1.6, palette.threadCore);
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points) ||
      oldDelegate.palette != palette ||
      oldDelegate.time != time;
}

/// Five-point rating star used by the HUD, level map and result card.
void paintRatingStar(
  Canvas canvas,
  Offset c,
  double radius,
  bool earned,
  SkyPalette p,
) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final r = i.isEven ? radius : radius * 0.45;
    final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  if (earned) {
    paintGlow(canvas, c, radius * 1.8, p.gold.withValues(alpha: 0.45));
    canvas.drawPath(path, Paint()..color = p.gold);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.1
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFF4C2),
    );
  } else {
    canvas.drawPath(path, Paint()..color = p.muted.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.1
        ..strokeJoin = StrokeJoin.round
        ..color = p.muted.withValues(alpha: 0.5),
    );
  }
}

/// A row of [max] rating stars with [earned] filled; [reveal] (0..max) lets
/// the result card pop them in one by one.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.earned,
    required this.palette,
    this.size = 16,
    this.max = 3,
    this.reveal,
  });

  final int earned;
  final SkyPalette palette;
  final double size;
  final int max;
  final ValueListenable<double>? reveal;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$earned of $max stars',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size(size * max + size * 0.3 * (max - 1), size),
          painter: _RatingPainter(earned, max, palette, reveal),
        ),
      ),
    );
  }
}

class _RatingPainter extends CustomPainter {
  _RatingPainter(this.earned, this.max, this.palette, this.reveal)
    : super(repaint: reveal);

  final int earned;
  final int max;
  final SkyPalette palette;
  final ValueListenable<double>? reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    final shown = reveal?.value ?? max.toDouble();
    for (var i = 0; i < max; i++) {
      final c = Offset(s / 2 + i * s * 1.3, s / 2);
      final k = (shown - i).clamp(0.0, 1.0);
      final isEarned = i < earned && k > 0;
      // Overshoot pop while revealing.
      final pop = isEarned && k < 1 ? 1 + 0.5 * math.sin(k * math.pi) : 1.0;
      paintRatingStar(canvas, c, s * 0.48 * pop, isEarned, palette);
    }
  }

  @override
  bool shouldRepaint(covariant _RatingPainter old) =>
      old.earned != earned ||
      old.max != max ||
      old.palette != palette ||
      old.reveal != reveal;
}

/// Small sky preview for the theme picker.
class SkySwatchPainter extends CustomPainter {
  const SkySwatchPainter(this.theme);

  final SkyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final p = theme.palette;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          <Color>[p.skyTop, p.skyMid, p.skyBottom],
          const <double>[0, 0.5, 1],
        ),
    );
    paintGlow(
      canvas,
      Offset(size.width * 0.3, size.height * 0.35),
      size.width * 0.6,
      p.nebulaA.withValues(alpha: 0.45),
    );
    final pts = <Offset>[
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.45, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.55),
      Offset(size.width * 0.82, size.height * 0.25),
    ];
    paintThread(
      canvas,
      pts,
      p,
      width: size.shortestSide * 0.045,
      shimmer: false,
    );
    for (final pt in pts) {
      paintSparkle(canvas, pt, size.shortestSide * 0.09, p.threadCore);
    }
  }

  @override
  bool shouldRepaint(covariant SkySwatchPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'sky_theme.dart';
import 'star_art.dart';

/// One background star; positions are normalized to the canvas.
class _FieldStar {
  const _FieldStar(this.x, this.y, this.size, this.phase, this.speed);

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
}

final List<_FieldStar> _field = () {
  final random = math.Random(42);
  return <_FieldStar>[
    for (var i = 0; i < 170; i++)
      _FieldStar(
        random.nextDouble(),
        // Denser towards the top of the sky.
        math.pow(random.nextDouble(), 1.4) * 0.86,
        0.5 + math.pow(random.nextDouble(), 3) * 2.2,
        random.nextDouble() * math.pi * 2,
        0.6 + random.nextDouble() * 1.8,
      ),
  ];
}();

/// Themed night sky behind the whole screen: gradient, nebula clouds,
/// twinkling stars, an occasional shooting star, theme decoration (moon,
/// aurora ribbons, nebula veil, eclipse corona) and a hill horizon with a
/// small observatory. Repaints from [time] (seconds) only.
class SkyPainter extends CustomPainter {
  SkyPainter({required this.theme, required this.time}) : super(repaint: time);

  final SkyTheme theme;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final p = theme.palette;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          <Color>[p.skyTop, p.skyMid, p.skyBottom],
          const <double>[0, 0.55, 1],
        ),
    );

    _paintNebula(canvas, size, t, p);
    switch (theme) {
      case SkyTheme.twilight:
        _paintMoon(canvas, size, p);
      case SkyTheme.aurora:
        _paintAurora(canvas, size, t, p);
      case SkyTheme.nebula:
        _paintVeil(canvas, size, t, p);
      case SkyTheme.eclipse:
        _paintEclipse(canvas, size, t, p);
    }
    _paintStars(canvas, size, t, p);
    _paintShootingStar(canvas, size, t, p);
    _paintHorizon(canvas, size, p);
  }

  void _paintNebula(Canvas canvas, Size size, double t, SkyPalette p) {
    final d = size.longestSide;
    final blobs = <(double, double, double, Color, double)>[
      (0.22, 0.28, 0.42, p.nebulaA, 0.20),
      (0.78, 0.18, 0.36, p.nebulaB, 0.16),
      (0.62, 0.62, 0.5, p.nebulaA, 0.12),
      (0.12, 0.72, 0.3, p.nebulaB, 0.10),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final (x, y, r, color, alpha) = blobs[i];
      final drift = Offset(
        math.sin(t * 0.03 + i * 1.7) * d * 0.02,
        math.cos(t * 0.025 + i) * d * 0.015,
      );
      final center = Offset(x * size.width, y * size.height) + drift;
      final radius = r * d;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]),
      );
    }
  }

  void _paintMoon(Canvas canvas, Size size, SkyPalette p) {
    final r = size.shortestSide * 0.05;
    final c = Offset(size.width * 0.86, size.height * 0.14);
    canvas.drawCircle(
      c,
      r * 4,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 4, <Color>[
          p.star.withValues(alpha: 0.16),
          p.star.withValues(alpha: 0),
        ]),
    );
    final moon = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(center: c + Offset(r * 0.45, -r * 0.2), radius: r),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      Paint()..color = const Color(0xFFFFF1D0),
    );
  }

  void _paintAurora(Canvas canvas, Size size, double t, SkyPalette p) {
    for (var band = 0; band < 3; band++) {
      final baseY = size.height * (0.18 + band * 0.1);
      final amp = size.height * (0.05 + band * 0.015);
      final path = Path()..moveTo(0, baseY);
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y =
            baseY +
            math.sin(i * 0.55 + t * (0.25 + band * 0.07) + band) * amp +
            math.sin(i * 0.21 - t * 0.12) * amp * 0.6;
        path.lineTo(x, y);
      }
      final curtain = Path.from(path)
        ..lineTo(size.width, baseY + size.height * 0.28)
        ..lineTo(0, baseY + size.height * 0.28)
        ..close();
      final color = band.isEven ? p.nebulaA : p.nebulaB;
      canvas.drawPath(
        curtain,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, baseY - amp),
            Offset(0, baseY + size.height * 0.28),
            <Color>[
              color.withValues(alpha: 0.30 - band * 0.06),
              color.withValues(alpha: 0),
            ],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.35),
      );
    }
  }

  void _paintVeil(Canvas canvas, Size size, double t, SkyPalette p) {
    final c = Offset(size.width * 0.5, size.height * 0.4);
    final r = size.longestSide * 0.45;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 0.01);
    for (var arm = 0; arm < 3; arm++) {
      canvas.rotate(math.pi * 2 / 3);
      final path = Path()..moveTo(0, 0);
      for (var i = 1; i <= 30; i++) {
        final a = i * 0.12;
        final rr = r * i / 30;
        path.lineTo(math.cos(a) * rr, math.sin(a) * rr);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.16
          ..color = (arm.isEven ? p.nebulaA : p.nebulaB).withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
    canvas.restore();
  }

  void _paintEclipse(Canvas canvas, Size size, double t, SkyPalette p) {
    final r = size.shortestSide * 0.075;
    final c = Offset(size.width * 0.82, size.height * 0.2);
    final pulse = 1 + 0.04 * math.sin(t * 0.8);
    canvas.drawCircle(
      c,
      r * 3.2 * pulse,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 3.2 * pulse,
          <Color>[
            p.nebulaA.withValues(alpha: 0.55),
            p.nebulaB.withValues(alpha: 0.18),
            p.nebulaB.withValues(alpha: 0),
          ],
          const <double>[0.3, 0.5, 1],
        ),
    );
    canvas.drawCircle(
      c,
      r * 1.04,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = const Color(0xFFFFF0C8),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF020202));
  }

  void _paintStars(Canvas canvas, Size size, double t, SkyPalette p) {
    final paint = Paint();
    final scale = (size.shortestSide / 700).clamp(0.7, 1.6);
    for (final s in _field) {
      final twinkle = 0.55 + 0.45 * math.sin(t * s.speed + s.phase);
      final c = Offset(s.x * size.width, s.y * size.height);
      final r = s.size * scale;
      paint.color = p.star.withValues(alpha: 0.25 + 0.6 * twinkle);
      if (r > 1.9) {
        paintSparkle(
          canvas,
          c,
          r * (2.2 + twinkle),
          p.star.withValues(alpha: 0.5 + 0.4 * twinkle),
        );
      }
      canvas.drawCircle(c, r * 0.6, paint);
    }
  }

  void _paintShootingStar(Canvas canvas, Size size, double t, SkyPalette p) {
    const period = 9.0;
    const duration = 1.1;
    final cycle = (t / period).floor();
    final k = (t - cycle * period) / duration;
    if (k < 0 || k > 1) return;
    final random = math.Random(cycle * 31 + 7);
    final start = Offset(
      size.width * (0.15 + random.nextDouble() * 0.7),
      size.height * (0.04 + random.nextDouble() * 0.25),
    );
    final dir = Offset(-0.8 + random.nextDouble() * 0.3, 0.45);
    final travel = size.shortestSide * 0.5;
    final head = start + dir * travel * k;
    final tail = head - dir * travel * 0.35 * (1 - k * 0.5);
    final fade = math.sin(k * math.pi);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..shader = ui.Gradient.linear(tail, head, <Color>[
          p.star.withValues(alpha: 0),
          p.threadCore.withValues(alpha: 0.9 * fade),
        ]),
    );
    canvas.drawCircle(
      head,
      2.2,
      Paint()..color = p.threadCore.withValues(alpha: fade),
    );
  }

  void _paintHorizon(Canvas canvas, Size size, SkyPalette p) {
    final h = size.height;
    final w = size.width;
    final base = h * 0.9;
    final far = Path()..moveTo(0, h);
    final near = Path()..moveTo(0, h);
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final u = i / steps;
      far.lineTo(
        x,
        base -
            h *
                (0.035 +
                    0.025 * math.sin(u * 9.2 + 1.3) +
                    0.015 * math.sin(u * 23)),
      );
      near.lineTo(
        x,
        base +
            h *
                (0.03 +
                    0.02 * math.sin(u * 5.1 + 0.4) +
                    0.008 * math.sin(u * 31)),
      );
    }
    far
      ..lineTo(w, h)
      ..close();
    near
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      far,
      Paint()..color = Color.lerp(p.horizon, p.skyBottom, 0.45)!,
    );
    canvas.drawPath(near, Paint()..color = p.horizon);

    // A tiny observatory on the near hill.
    final ox = w * 0.14;
    final oy =
        base + h * (0.03 + 0.02 * math.sin(0.14 * 5.1 + 0.4)) - h * 0.012;
    final unit = (h * 0.018).clamp(5.0, 14.0);
    final body = Paint()..color = p.horizon;
    canvas.drawRect(
      Rect.fromLTWH(ox - unit, oy - unit * 1.2, unit * 2, unit * 1.4),
      body,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(ox, oy - unit * 1.2), radius: unit),
      math.pi,
      math.pi,
      true,
      body,
    );
    canvas.drawCircle(
      Offset(ox + unit * 0.45, oy - unit * 0.5),
      unit * 0.18,
      Paint()..color = p.thread.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.time != time;
}

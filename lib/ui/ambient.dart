import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The ambient dynamic background: follows the time of day (deep navy at night,
/// rose at dawn, azure by day, warm gold at late afternoon, dusk violet;
/// deep in dark mode, calm in light), faint topographic contour lines so the
/// glass above has authentic depth and refraction texture to blur, and a light
/// wash of the chosen accent at the top. Re-evaluates once a minute.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.accent});
  final Color accent;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _Sky(
          sky: skyAt(now.hour + now.minute / 60, dark: dark),
          dark: dark,
          accent: widget.accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Sky extends CustomPainter {
  _Sky({required this.sky, required this.dark, required this.accent});
  final (Color, Color) sky;
  final bool dark;
  final Color accent;

  static ui.Picture? _topo;
  static String? _topoKey;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _calm(sky.$2, dark));

    // Accent light wash from the top left
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.center,
          colors: [
            accent.withValues(alpha: dark ? 0.06 : 0.05),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    final side = math
        .sqrt(size.width * size.width + size.height * size.height)
        .ceilToDouble();
    final key = '$side|$dark';
    if (_topoKey != key) {
      _topo = _drawTopo(
        side,
        dark ? Colors.white : Colors.black,
        dark ? 0.07 : 0.06,
      );
      _topoKey = key;
    }
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.42);
    canvas.rotate(-0.35);
    canvas.translate(-side / 2, -side / 2);
    if (_topo != null) {
      canvas.drawPicture(_topo!);
    }
    canvas.restore();
  }

  /// Smooth topographic contour lines via marching squares
  static ui.Picture _drawTopo(double side, Color color, double alpha) {
    double f(double x, double y) =>
        math.sin(x / 95 + math.sin(y / 140) * 1.3) +
        math.cos(y / 115 - math.sin(x / 175) * 1.1) +
        0.6 * math.sin((x + y) / 75);

    const step = 10.0;
    final n = (side / step).ceil() + 1;
    final v = List.generate(
      n,
      (i) => List.generate(n, (j) => f(i * step, j * step)),
    );

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = -2.4; level <= 2.4; level += 0.4) {
      final path = Path();
      for (var i = 0; i < n - 1; i++) {
        for (var j = 0; j < n - 1; j++) {
          final a = v[i][j], b = v[i + 1][j];
          final cc = v[i + 1][j + 1], d = v[i][j + 1];
          final x = i * step, y = j * step;
          final pts = <Offset>[];
          void edge(double p0, double p1, Offset o0, Offset o1) {
            if ((p0 < level) != (p1 < level)) {
              final t = (level - p0) / (p1 - p0);
              pts.add(Offset.lerp(o0, o1, t)!);
            }
          }

          edge(a, b, Offset(x, y), Offset(x + step, y));
          edge(b, cc, Offset(x + step, y), Offset(x + step, y + step));
          edge(cc, d, Offset(x + step, y + step), Offset(x, y + step));
          edge(d, a, Offset(x, y + step), Offset(x, y));
          for (var k = 0; k + 1 < pts.length; k += 2) {
            path
              ..moveTo(pts[k].dx, pts[k].dy)
              ..lineTo(pts[k + 1].dx, pts[k + 1].dy);
          }
        }
      }
      canvas.drawPath(path, paint);
    }
    return rec.endRecording();
  }

  @override
  bool shouldRepaint(_Sky old) =>
      old.sky != sky || old.dark != dark || old.accent != accent;
}

Color _calm(Color c, bool dark) {
  final h = HSLColor.fromColor(c);
  return h
      .withSaturation((h.saturation * (dark ? 0.35 : 0.50)).clamp(0.0, 1.0))
      .withLightness(dark ? 0.055 : 0.970)
      .toColor();
}

(Color, Color) skyAt(double hour, {required bool dark}) {
  final keys = dark ? _darkSky : _lightSky;
  for (var i = 0; i < keys.length - 1; i++) {
    final (h0, t0, b0) = keys[i];
    final (h1, t1, b1) = keys[i + 1];
    if (hour >= h0 && hour <= h1) {
      final t = Curves.easeInOut.transform((hour - h0) / (h1 - h0));
      return (Color.lerp(t0, t1, t)!, Color.lerp(b0, b1, t)!);
    }
  }
  return (keys.first.$2, keys.first.$3);
}

const _darkSky = [
  (0.0, Color(0xFF070B1C), Color(0xFF000000)),
  (5.0, Color(0xFF141233), Color(0xFF040308)),
  (6.5, Color(0xFF2E1E45), Color(0xFF4A2420)),
  (8.5, Color(0xFF0C2440), Color(0xFF070F1C)),
  (13.0, Color(0xFF0D2A4C), Color(0xFF081424)),
  (17.0, Color(0xFF2A2240), Color(0xFF4A2A12)),
  (19.0, Color(0xFF231A3E), Color(0xFF2A1014)),
  (21.0, Color(0xFF0B0F28), Color(0xFF020206)),
  (24.0, Color(0xFF070B1C), Color(0xFF000000)),
];

const _lightSky = [
  (0.0, Color(0xFFD8DDF1), Color(0xFFF0F3FA)),
  (5.0, Color(0xFFDED8EF), Color(0xFFF6F2F9)),
  (6.5, Color(0xFFF8D2C0), Color(0xFFFDEEE4)),
  (8.5, Color(0xFFD0E2F8), Color(0xFFF0F6FE)),
  (13.0, Color(0xFFC3DCF8), Color(0xFFEDF5FE)),
  (17.0, Color(0xFFF8D2AD), Color(0xFFFDEDDD)),
  (19.0, Color(0xFFE0CCEC), Color(0xFFF7EDF2)),
  (21.0, Color(0xFFD5D9F0), Color(0xFFEFF1FA)),
  (24.0, Color(0xFFD8DDF1), Color(0xFFF0F3FA)),
];

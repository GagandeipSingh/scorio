import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'motion.dart';

class GlassLens {
  GlassLens._();

  static ui.FragmentProgram? _program;

  static Future<void> load() async {
    if (!ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/lens.frag');
    } catch (_) {
      _program = null;
    }
  }

  static bool get ready => _program != null;
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.gradient,
    this.thick = false,
    this.lit = false,
    this.blur,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Gradient? gradient;
  final bool thick;
  final bool lit;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);

    if (MediaQuery.highContrastOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
          borderRadius: shape,
          border: Border.all(
            color: dark ? Colors.white70 : Colors.black54,
            width: 1.2,
          ),
        ),
        child: Padding(padding: padding, child: child),
      );
    }

    final nested = _GlassNest.inside(context);
    if (!nested && GlassLens.ready) {
      return _lens(context, dark, shape);
    }
    return _frost(dark, shape);
  }

  Widget _lens(BuildContext context, bool dark, BorderRadius shape) {
    final fill = gradient;
    final Color glass = fill != null && fill.colors.isNotEmpty
        ? Color.lerp(
            Color.lerp(fill.colors.first, fill.colors.last, 0.5)!,
            Colors.black,
            0.12,
          )!.withValues(alpha: 0.9)
        : tint ??
            (dark
                ? const Color(0xFF3C3F46).withValues(alpha: 0.38)
                : const Color(0xFFF8F9FB).withValues(alpha: 0.42));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF001030).withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: const Color(0xFF001030).withValues(alpha: 0.09),
                  blurRadius: 22,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: _Lens(
          radius: radius,
          dark: dark,
          lit: lit,
          floating: thick,
          tint: glass,
          blur: blur ?? 5.5,
          child: _GlassNest(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: fill == null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.09),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
              ),
              child: _TouchGlow(
                glow: PressGlow.of(context),
                dark: dark,
                child: PressGlow(
                  point: null,
                  strength: 0,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _frost(bool dark, BorderRadius shape) {
    final fill = dark
        ? (tint ?? const Color(0xFF1E2230)).withValues(
            alpha: lit ? 0.45 : (thick ? 0.35 : 0.26),
          )
        : (tint ?? Colors.white).withValues(
            alpha: lit ? 0.92 : (thick ? 0.82 : 0.72),
          );

    final shadows = dark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: thick ? 18 : 12,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF001030).withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
            BoxShadow(
              color: const Color(0xFF001030).withValues(alpha: 0.07),
              blurRadius: thick ? 20 : 14,
              offset: const Offset(0, 4),
            ),
          ];

    final sigma = blur ?? (thick ? 14.0 : 12.0);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: CustomPaint(
            foregroundPainter: _FrostRim(
              radius: radius,
              dark: dark,
              lit: lit,
              hasCustomFill: gradient != null,
            ),
            child: _GlassNest(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: gradient == null ? fill : null,
                  gradient: gradient,
                  borderRadius: shape,
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNest extends InheritedWidget {
  const _GlassNest({required super.child});

  static bool inside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_GlassNest>() != null;

  @override
  bool updateShouldNotify(_GlassNest old) => false;
}

class _Lens extends SingleChildRenderObjectWidget {
  const _Lens({
    required this.radius,
    required this.dark,
    required this.lit,
    required this.floating,
    required this.tint,
    required this.blur,
    super.child,
  });

  final bool floating;
  final double radius;
  final bool dark;
  final bool lit;
  final Color tint;
  final double blur;

  static Listenable? _scrolls(BuildContext context) {
    final positions = <Listenable>[];
    var ctx = context;
    while (true) {
      final s = Scrollable.maybeOf(ctx);
      if (s == null) break;
      positions.add(s.position);
      ctx = s.context;
    }
    final route = ModalRoute.of(context);
    if (route?.animation != null) positions.add(route!.animation!);
    if (route?.secondaryAnimation != null) {
      positions.add(route!.secondaryAnimation!);
    }
    return positions.isEmpty ? null : Listenable.merge(positions);
  }

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLens()
    ..scrolls = _scrolls(context)
    ..pixelRatio = View.of(context).devicePixelRatio
    ..radius = radius
    ..dark = dark
    ..lit = lit
    ..floating = floating
    ..tint = tint
    ..blur = blur;

  @override
  void updateRenderObject(BuildContext context, _RenderLens r) {
    r
      ..scrolls = _scrolls(context)
      ..pixelRatio = View.of(context).devicePixelRatio
      ..radius = radius
      ..dark = dark
      ..lit = lit
      ..floating = floating
      ..tint = tint
      ..blur = blur;
  }
}

class _RenderLens extends RenderProxyBox {
  _RenderLens() : _shader = GlassLens._program!.fragmentShader();

  final ui.FragmentShader _shader;
  final LayerHandle<BackdropFilterLayer> _layer =
      LayerHandle<BackdropFilterLayer>();
  Rect? _painted;
  bool _watching = false;

  Listenable? _scrolls;
  set scrolls(Listenable? v) {
    if (identical(v, _scrolls)) return;
    if (attached) _scrolls?.removeListener(markNeedsPaint);
    _scrolls = v;
    if (attached) _scrolls?.addListener(markNeedsPaint);
  }

  double _pixelRatio = 1;
  set pixelRatio(double v) => _set(_pixelRatio != v, () => _pixelRatio = v);
  double _radius = 0;
  set radius(double v) => _set(_radius != v, () => _radius = v);
  bool _dark = false;
  set dark(bool v) => _set(_dark != v, () => _dark = v);
  bool _lit = false;
  set lit(bool v) => _set(_lit != v, () => _lit = v);
  bool _floating = true;
  set floating(bool v) => _set(_floating != v, () => _floating = v);
  Color _tint = Colors.transparent;
  set tint(Color v) => _set(_tint != v, () => _tint = v);
  double _blur = 7;
  set blur(double v) => _set(_blur != v, () => _blur = v);

  void _set(bool changed, VoidCallback apply) {
    if (!changed) return;
    apply();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  Rect _physical(RenderBox box) {
    final r = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    return Rect.fromLTWH(
      r.left * _pixelRatio,
      r.top * _pixelRatio,
      r.width * _pixelRatio,
      r.height * _pixelRatio,
    );
  }

  Offset _passOrigin() {
    for (var node = parent; node != null; node = node.parent) {
      final passes =
          node is RenderShaderMask ||
          node is RenderBackdropFilter ||
          (node is RenderOpacity && node.opacity < 1) ||
          (node is RenderAnimatedOpacity && node.opacity.value < 1);
      if (passes && node is RenderBox && node.hasSize) {
        return _physical(node).topLeft;
      }
    }
    return Offset.zero;
  }

  Rect _onScreen() => _physical(this).shift(-_passOrigin());

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrolls?.addListener(markNeedsPaint);
    _watching = true;
    _watch();
  }

  @override
  void detach() {
    _watching = false;
    _scrolls?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _layer.layer = null;
    _shader.dispose();
    super.dispose();
  }

  void _watch() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_watching || !attached) return;
      if (hasSize && _painted != null && _onScreen() != _painted) {
        markNeedsPaint();
      } else if (_fadedLast != _inFade()) {
        markNeedsPaint();
      }
      _watch();
    });
  }

  bool _fadedLast = false;

  bool _inFade() {
    for (var node = parent; node != null; node = node.parent) {
      if (node is RenderAnimatedOpacity && node.opacity.value < 1) return true;
      if (node is RenderOpacity && node.opacity < 1) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!hasSize || size.isEmpty) {
      super.paint(context, offset);
      return;
    }
    _fadedLast = _inFade();
    if (_fadedLast) {
      _layer.layer = null;
      _painted = null;
      final fadeBg = _dark
          ? const Color(0x14FFFFFF)
          : (_tint.a > 0
              ? _tint.withValues(alpha: 0.12)
              : const Color(0x18FFFFFF));
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(offset & size, Radius.circular(_radius)),
        Paint()..color = fadeBg,
      );
      super.paint(context, offset);
      return;
    }
    final rect = _onScreen();
    _painted = rect;
    final px = rect.width / size.width;

    final bevel = math.min(_floating ? 12.0 : 9.0, _radius * 0.5) * px;
    final boost = _lit ? 1.35 : 1.0;
    final tintAlpha = (_tint.a + (_lit ? 0.08 : 0.0)).clamp(0.0, 1.0);

    _shader
      ..setFloat(2, rect.left)
      ..setFloat(3, rect.top)
      ..setFloat(4, rect.width)
      ..setFloat(5, rect.height)
      ..setFloat(6, _radius * px)
      ..setFloat(7, bevel)
      ..setFloat(8, _floating ? 0.24 : 0.16)
      ..setFloat(9, _tint.r)
      ..setFloat(10, _tint.g)
      ..setFloat(11, _tint.b)
      ..setFloat(12, tintAlpha)
      ..setFloat(13, _dark ? 0.10 : 0.0)
      ..setFloat(14, _dark ? 1.6 : 1.25)
      ..setFloat(15, (_dark ? 1.1 : 1.0) * boost)
      ..setFloat(16, px)
      ..setFloat(17, _dark ? 1.0 : 0.0);

    final filter = ImageFilter.compose(
      outer: ImageFilter.shader(_shader),
      inner: ImageFilter.blur(
        sigmaX: _blur,
        sigmaY: _blur,
        tileMode: TileMode.clamp,
      ),
    );
    final layer = _layer.layer ??= BackdropFilterLayer();
    layer.filter = filter;
    context.pushLayer(layer, super.paint, offset);
  }
}

class _FrostRim extends CustomPainter {
  const _FrostRim({
    required this.radius,
    required this.dark,
    this.lit = false,
    this.hasCustomFill = false,
  });

  final double radius;
  final bool dark;
  final bool lit;
  final bool hasCustomFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final rr = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(math.max(0, r - 0.5)),
    );

    final boost = lit ? 1.25 : 1.0;

    final Shader shader;
    if (dark) {
      shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: (0.35 * boost).clamp(0.0, 1.0)),
          Colors.white.withValues(alpha: (0.16 * boost).clamp(0.0, 1.0)),
          Colors.white.withValues(alpha: (0.08 * boost).clamp(0.0, 1.0)),
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(rect);
    } else {
      // iOS Liquid Glass in light mode:
      // Strong specular white at top, fading to a subtle ambient contrast rim at bottom
      // so boundaries remain crisp against pale / white backgrounds.
      shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: (0.95 * boost).clamp(0.0, 1.0)),
          Colors.white.withValues(alpha: (0.55 * boost).clamp(0.0, 1.0)),
          Color.lerp(Colors.white, const Color(0xFF64748B), 0.35)!
              .withValues(alpha: (0.42 * boost).clamp(0.0, 1.0)),
        ],
        stops: const [0.0, 0.30, 1.0],
      ).createShader(rect);
    }

    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_FrostRim old) =>
      old.radius != radius ||
      old.dark != dark ||
      old.lit != lit ||
      old.hasCustomFill != hasCustomFill;
}

class _TouchGlow extends StatelessWidget {
  const _TouchGlow({
    required this.glow,
    required this.dark,
    required this.child,
  });
  final PressGlow? glow;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = glow;
    if (g == null || g.point == null || g.strength <= 0.001) return child;
    return CustomPaint(
      foregroundPainter: _GlowPainter(g.point!, g.strength, dark),
      child: child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.at, this.strength, this.dark);
  final Offset at;
  final double strength;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max(size.shortestSide * 1.1, 60.0);
    final a = (dark ? 0.16 : 0.32) * strength;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: a),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.at != at || old.strength != strength || old.dark != dark;
}

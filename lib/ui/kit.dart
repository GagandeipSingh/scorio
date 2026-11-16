import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ambient.dart';
import 'glass_chrome.dart';
import 'glass_surface.dart';
import 'motion.dart';
import 'scale.dart';

class Pal {
  Pal._(this.dark, this.accent);
  factory Pal.of(BuildContext context) => Pal._(
        Theme.of(context).brightness == Brightness.dark,
        AppTheme.accent,
      );

  final bool dark;
  final Color accent;
  Color get ink => dark ? Colors.white : const Color(0xFF0F172A);
  Color get sub => dark ? const Color(0xB3FFFFFF) : const Color(0xFF475569);
  Color get faint => dark ? const Color(0x1FFFFFFF) : const Color(0x1A0F172A);

  LinearGradient get accentFill {
    final a = dark ? 0.94 : 0.98;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF38BDF8).withValues(alpha: a),
        const Color(0xFF007AF8).withValues(alpha: a),
      ],
    );
  }
}

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      const AmbientBackground(accent: AppTheme.accent);
}

EdgeInsets pagePadding(BuildContext context, {bool bottomBar = false}) {
  final mq = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    16.dp,
    mq.top + GlassAppBar.gap + GlassAppBar.barHeight + 14.dp,
    16.dp,
    mq.bottom + (bottomBar ? 84.dp : 28.dp),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.bg = true,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final bool bg;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bg)
              SizedBox.square(
                dimension: 88.dp,
                child: GlassSurface(
                  radius: 44.dp,
                  thick: true,
                  child: Center(
                    child: Icon(icon, size: 38.dp, color: p.accent),
                  ),
                ),
              )
            else
              Icon(icon, size: 48.dp, color: p.accent.withValues(alpha: 0.9)),
            SizedBox(height: 18.dp),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.ink,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (hint != null) ...[
              SizedBox(height: 8.dp),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.sub,
                  fontSize: 13.5.sp,
                  height: 1.45,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 22.dp),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class Pane extends StatelessWidget {
  const Pane({
    super.key,
    required this.child,
    this.padding,
    this.tint,
    this.radius,
    this.expand = false,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? tint;
  final double? radius;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final surface = GlassSurface(
      radius: radius ?? 24.dp,
      padding: padding ?? EdgeInsets.all(16.dp),
      tint: tint,
      child: child,
    );
    return expand ? SizedBox.expand(child: surface) : surface;
  }
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color, this.align});
  final String text;
  final Color? color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        textAlign: align,
        style: TextStyle(
          color: color ?? Pal.of(context).sub,
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(6.dp, 16.dp, 6.dp, 8.dp),
        child: Caption(text),
      );
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 12.dp),
        child: Container(height: 0.6.dp, color: Pal.of(context).faint),
      );
}

class Segments<T> extends StatelessWidget {
  const Segments({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final h = height ?? 38.dp;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    return GlassSurface(
      radius: h / 2,
      thick: true,
      padding: EdgeInsets.all(3.dp),
      child: SizedBox(
        height: h - 6.dp,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / values.length;
            return Stack(
              children: [
                SpringValue(
                  value: index.toDouble(),
                  builder: (context, at, child) => Positioned(
                    left: w * at,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: child!,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: p.dark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.85),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: p.dark ? 0.22 : 0.9,
                        ),
                        width: 0.8,
                      ),
                      boxShadow: p.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                              ),
                            ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == index,
                          label: labels[i],
                          excludeSemantics: true,
                          onTap: () => onChanged(values[i]),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i == index) return;
                              HapticFeedback.selectionClick();
                              onChanged(values[i]);
                            },
                            child: Center(
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  color: i == index ? p.ink : p.sub,
                                  fontSize: 13.5.sp,
                                  fontWeight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

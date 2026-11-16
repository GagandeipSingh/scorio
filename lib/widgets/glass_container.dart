import 'package:flutter/material.dart';
import '../ui/glass_chrome.dart';
import '../ui/glass_surface.dart';
import '../ui/scale.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22,
    this.onTap,
    this.color,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassSurface(
      radius: borderRadius.dp,
      padding: padding ?? EdgeInsets.all(16.dp),
      tint: color,
      child: child,
    );

    final wrapped = onTap != null
        ? GlassPress(
            onTap: onTap!,
            label: 'Card',
            child: card,
          )
        : card;

    if (margin != null) {
      return Padding(padding: margin!, child: wrapped);
    }
    return wrapped;
  }
}

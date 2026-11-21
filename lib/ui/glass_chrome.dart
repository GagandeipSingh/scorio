import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';
import 'motion.dart';

enum GlassStatusBarStyle { light, dark }

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.background,
    this.appBar,
    this.statusBarStyle = GlassStatusBarStyle.dark,
    this.maxContentWidth,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = false,
  });

  final Widget body;
  final Widget? background;
  final GlassAppBar? appBar;
  final GlassStatusBarStyle statusBarStyle;
  final double? maxContentWidth;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final overlay = statusBarStyle == GlassStatusBarStyle.light
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final stack = Stack(
      children: [
        Positioned.fill(child: body),
        if (appBar != null)
          Positioned(left: 0, top: 0, right: 0, child: appBar!),
      ],
    );
    final content = maxContentWidth != null
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth!),
              child: stack,
            ),
          )
        : stack;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        // The presets assume a BLACK nav bar and so draw white nav buttons.
        // Ours is transparent over the app, so the buttons must follow the
        // status icons, or they vanish on a light screen (3-button nav; seen
        // on an Android 9 emulator).
        systemNavigationBarIconBrightness: overlay.statusBarIconBrightness,
      ),
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            body: content,
            floatingActionButton: floatingActionButton,
          ),
          const NavButtonBacking(),
        ],
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget {
  const GlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.centerTitle = false,
  });

  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;
  final bool centerTitle;

  static const double barHeight = 44;
  static const double gap = 8;

  static double bottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + gap + barHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;

    final row = SizedBox(
      height: barHeight,
      child: NavigationToolbar(
        leading: leading == null
            ? null
            : Center(widthFactor: 1, child: leading),
        middle: title == null
            ? null
            : DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title!,
              ),
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
        centerMiddle: centerTitle,
        middleSpacing: 12,
      ),
    );

    if (MediaQuery.highContrastOf(context)) {
      return ColoredBox(
        color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        child: Padding(
          padding: EdgeInsets.only(top: top + gap),
          child: row,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: top + gap, bottom: 6),
      child: row,
    );
  }
}

Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final isWide = isWideLayout(context);
  if (isWide) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: motion(context, kSpringMs),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final pop = CurvedAnimation(
          parent: anim,
          curve: kSpring,
          reverseCurve: Curves.easeInCubic,
        );
        final screenH = MediaQuery.sizeOf(ctx).height;
        return Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(pop),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: math.min(640, screenH - 32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GlassSurface(
                  radius: 34,
                  thick: true,
                  blur: 12,
                  tint: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF16181C).withValues(alpha: 0.30)
                      : const Color(0xFFEEF0F4).withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(child: builder(ctx)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.18,
    ),
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, kSpringMs),
      reverseCurve: Curves.easeInCubic,
      reverseDuration: motion(context, 240),
    ),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final inset = MediaQuery.viewInsetsOf(ctx).bottom;
      return _SheetSpring(
        child: _SheetStretch(
          child: Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: GlassSurface(
                  radius: 32,
                  thick: true,
                  blur: 14,
                  tint: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF141720).withValues(alpha: 0.40)
                      : const Color(0xFFF4F6FB).withValues(alpha: 0.65),
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.onSurface.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(child: builder(ctx)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SheetSpring extends StatelessWidget {
  const _SheetSpring({required this.child});
  final Widget child;

  static const Curve _flutter = Cubic(0.0, 0.0, 0.2, 1.0);

  @override
  Widget build(BuildContext context) {
    final anim = ModalRoute.of(context)?.animation;
    if (anim == null || MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, child) {
        final t = anim.value;
        final dy = anim.status == AnimationStatus.forward
            ? _flutter.transform(t) - kSpring.transform(t)
            : 0.0;
        return FractionalTranslation(translation: Offset(0, dy), child: child);
      },
    );
  }
}

class _SheetStretch extends StatefulWidget {
  const _SheetStretch({required this.child});
  final Widget child;

  @override
  State<_SheetStretch> createState() => _SheetStretchState();
}

class _SheetStretchState extends State<_SheetStretch> {
  double _pull = 0;
  double _from = 0;
  int _release = 0;
  bool _held = false;

  static double _rubber(double d) => 48 * (1 - math.exp(-d / 110));

  void _up() {
    if (!_held) return;
    setState(() {
      _held = false;
      _from = _rubber(_pull);
      _pull = 0;
      _release++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    Widget body;
    if (_held) {
      body = Transform.translate(
        offset: Offset(0, -_rubber(_pull)),
        child: widget.child,
      );
    } else if (_from > 0 && !still) {
      body = TweenAnimationBuilder<double>(
        key: ValueKey(_release),
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: kSpringMs),
        curve: kSpring,
        child: widget.child,
        builder: (context, v, child) =>
            Transform.translate(offset: Offset(0, -_from * v), child: child),
      );
    } else {
      body = widget.child;
    }
    return Listener(
      onPointerMove: (e) {
        final next = _pull - e.delta.dy;
        if (next <= 0 && !_held) return;
        setState(() {
          _held = next > 0;
          _pull = math.max(0, next);
        });
      },
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: body,
    );
  }
}

class GlassPress extends StatefulWidget {
  const GlassPress({
    super.key,
    required this.onTap,
    required this.label,
    this.child,
    this.builder,
    this.onLongPress,
  }) : assert(child != null || builder != null);

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String label;
  final Widget? child;
  final Widget Function(bool down)? builder;

  @override
  State<GlassPress> createState() => _GlassPressState();
}

class _GlassPressState extends State<GlassPress> {
  bool _down = false;
  bool _hover = false;
  Offset? _at;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!_hover) setState(() => _hover = true);
        },
        onExit: (_) {
          if (_hover) setState(() => _hover = false);
        },
        child: Listener(
          onPointerDown: (e) => setState(() => _at = e.localPosition),
          onPointerMove: (e) {
            if (_down) setState(() => _at = e.localPosition);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _set(true),
            onTapCancel: () => _set(false),
            onTapUp: (_) => _set(false),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            onLongPress: widget.onLongPress,
            child: SpringValue(
              value: _down && !still ? 1 : (_hover && !still ? 0.33 : 0),
              stiffness: _down ? 420 : 180,
              dampingRatio: _down ? 0.8 : 0.5,
              child: widget.builder?.call(_down) ?? widget.child,
              builder: (context, v, child) => Transform.scale(
                scale: 1 + 0.05 * v,
                child: PressGlow(
                  point: _at,
                  strength: v.clamp(0.0, 1.0),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SemiboldIcon extends StatelessWidget {
  const SemiboldIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0.35, 0.35),
          child: Icon(icon, size: size, color: color),
        ),
        Icon(icon, size: size, color: color),
      ],
    );
  }
}

class RoundGlassButton extends StatelessWidget {
  const RoundGlassButton({
    super.key,
    this.icon,
    this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.size,
    this.iconSize,
    this.tint,
    this.gradient,
    this.iconColor,
  }) : assert(
         icon != null || child != null,
         'Either icon or child must be provided',
       );

  final IconData? icon;
  final Widget? child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double? size;
  final double? iconSize;
  final Color? tint;
  final Gradient? gradient;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = size ?? 40.0;
    return GlassPress(
      onTap: onPressed,
      label: semanticLabel,
      builder: (down) => SizedBox.square(
        dimension: s,
        child: GlassSurface(
          radius: s / 2,
          thick: true,
          lit: down,
          tint: tint,
          gradient: gradient,
          child: Center(
            child:
                child ??
                Icon(
                  icon!,
                  color:
                      iconColor ??
                      (dark ? Colors.white : const Color(0xFF14151A)),
                  size: iconSize ?? (s * 0.44),
                ),
          ),
        ),
      ),
    );
  }
}

/// Under 3-button navigation the back, home and recents buttons sit on their
/// own strip of the app's liquid glass: the same floating lens as the tab bar
/// ([GlassSurface], thick), square and full width. The page scrolls on under
/// it, bent and frosted, so the buttons stay readable over any content.
///
/// Under GESTURE navigation there is no strip. The handle is a thin pill the
/// system re-colours against what is behind it, and a 16-24 dp band of glass
/// under it read as a stray ledge cut off the page; content runs to the edge
/// there, as in native apps.
///
/// Told apart by the REAL inset in dp (the View's, not the tree's scaled
/// MediaQuery): 3-button bars are 48 dp (42 on some phones), gesture bars
/// 16-32 dp. Nothing in the app hides the buttons; they are always on screen.
class NavButtonBacking extends StatelessWidget {
  const NavButtonBacking({super.key});

  static const double threeButtonMinDp = 40;

  static bool threeButton(BuildContext context) {
    final view = View.of(context);
    return view.viewPadding.bottom / view.devicePixelRatio >= threeButtonMinDp;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).viewPadding.bottom;
    if (h <= 0 || !threeButton(context)) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: h,
      child: const IgnorePointer(
        child: GlassSurface(
          radius: 0,
          edgeless: true,
          thick: true,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

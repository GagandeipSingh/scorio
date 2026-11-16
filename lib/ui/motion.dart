import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

class SpringCurve extends Curve {
  const SpringCurve({required this.dampingRatio, this.stiffness = 180});

  final double dampingRatio;
  final double stiffness;

  double get settle => 4.6 / (dampingRatio * math.sqrt(stiffness));

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      SpringDescription(
        mass: 1,
        stiffness: stiffness,
        damping: 2 * dampingRatio * math.sqrt(stiffness),
      ),
      0,
      1,
      0,
    );
    return sim.x(t * settle);
  }
}

const Curve kSpring = SpringCurve(dampingRatio: 0.55);
const Curve kSpringSoft = SpringCurve(dampingRatio: 0.7);

const int kSpringMs = 620;
const int kSpringSoftMs = 520;

Duration motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: ms);

class SpringIn extends StatelessWidget {
  const SpringIn({
    super.key,
    required this.from,
    required this.child,
    this.soft = false,
    this.scaleFrom = 1,
  });

  final Offset from;
  final double scaleFrom;
  final Widget child;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: soft ? kSpringSoftMs : kSpringMs),
      curve: soft ? kSpringSoft : kSpring,
      child: child,
      builder: (context, v, child) => Transform.translate(
        offset: from * (1 - v),
        child: scaleFrom == 1
            ? child
            : Transform.scale(
                scale: scaleFrom + (1 - scaleFrom) * v,
                child: child,
              ),
      ),
    );
  }
}

class SpringValue extends StatefulWidget {
  const SpringValue({
    super.key,
    required this.value,
    required this.builder,
    this.child,
    this.dampingRatio = 0.55,
    this.stiffness = 180,
  });

  final double value;
  final double dampingRatio;
  final double stiffness;
  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child)
      builder;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  );

  @override
  void didUpdateWidget(SpringValue old) {
    super.didUpdateWidget(old);
    if (widget.value == old.value) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = widget.value;
      return;
    }
    final k = widget.stiffness;
    _c.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: k,
          damping: 2 * widget.dampingRatio * math.sqrt(k),
        ),
        _c.value,
        widget.value,
        _c.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => widget.builder(context, _c.value, child),
      );
}

class PressGlow extends InheritedWidget {
  const PressGlow({
    super.key,
    required this.point,
    required this.strength,
    required super.child,
  });

  final Offset? point;
  final double strength;

  static PressGlow? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PressGlow>();

  @override
  bool updateShouldNotify(PressGlow old) =>
      old.point != point || old.strength != strength;
}

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

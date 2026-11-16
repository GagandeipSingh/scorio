import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

export 'package:flutter_screenutil/flutter_screenutil.dart' show SizeExtension;

extension Dp on num {
  double get dp => r;
}

class ScaleToWidth extends StatelessWidget {
  const ScaleToWidth({super.key, required this.child});
  final Widget child;

  static const designWidth = 418.0;
  static const designHeight = 860.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final f = math
        .min(
          mq.size.shortestSide / designWidth,
          mq.size.longestSide / designHeight,
        )
        .clamp(0.8, (mq.size.longestSide / 1200).clamp(1.15, 2.0));
    if ((f - 1).abs() < 0.01) return child;
    final size = mq.size / f;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: mq.copyWith(
              size: size,
              devicePixelRatio: mq.devicePixelRatio * f,
              padding: mq.padding / f,
              viewPadding: mq.viewPadding / f,
              viewInsets: mq.viewInsets / f,
              systemGestureInsets: mq.systemGestureInsets / f,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ScreenUtilScope extends StatefulWidget {
  const ScreenUtilScope({super.key, required this.child});
  final Widget child;

  @override
  State<ScreenUtilScope> createState() => _ScreenUtilScopeState();
}

class _ScreenUtilScopeState extends State<ScreenUtilScope> {
  Size? _configured;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.isEmpty) return const SizedBox.shrink();
    if (_configured != mq.size) {
      final first = _configured == null;
      ScreenUtil.configure(
        data: mq,
        designSize: mq.size.width > mq.size.height
            ? Size(mq.size.width, ScaleToWidth.designWidth)
            : Size(ScaleToWidth.designWidth, mq.size.height),
        minTextAdapt: true,
        splitScreenMode: false,
      );
      _configured = mq.size;
      if (!first) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          void rebuild(Element e) {
            e.markNeedsBuild();
            e.visitChildren(rebuild);
          }

          (context as Element).visitChildren(rebuild);
        });
      }
    }
    return widget.child;
  }
}

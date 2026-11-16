import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'ui/glass_surface.dart' show GlassLens;
import 'ui/scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final isLargeScreen = view != null &&
      view.physicalSize.shortestSide > 0 &&
      (view.physicalSize.shortestSide / view.devicePixelRatio) >= 600;
  if (!isLargeScreen) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Load the Liquid Glass Lens Fragment Shader
  await GlassLens.load();

  runApp(const ProviderScope(child: ScoringApp()));
}

class ScoringApp extends StatelessWidget {
  const ScoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scorio',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _StillScroll(),
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.25,
            ),
          ),
          child: ScaleToWidth(
            child: ScreenUtilScope(
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}

/// Gentle damped bounce physics that preserves glass blur filters without
/// distortion on overscroll.
class _StillScroll extends MaterialScrollBehavior {
  const _StillScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _SubtleBounce(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class _SubtleBounce extends BouncingScrollPhysics {
  const _SubtleBounce({super.parent});

  @override
  _SubtleBounce applyTo(ScrollPhysics? ancestor) =>
      _SubtleBounce(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) =>
      0.035 * (1 - overscrollFraction) * (1 - overscrollFraction);

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 700, ratio: 1.0);
}

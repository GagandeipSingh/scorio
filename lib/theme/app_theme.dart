import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ClassAvatarInfo {
  final String? label;
  final IconData? icon;
  final Color accent;
  const ClassAvatarInfo({this.label, this.icon, required this.accent});
}

class AppTheme {
  // Core palette — Classroom Chalkboard Green
  static const Color background = Color(0xFFF2F4F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF007AF8); // Electric Azure (App Icon Blue)
  static const Color accentBright = Color(0xFF38BDF8); // Radiant Sky Blue
  static const Color accentSoft = Color(0xFFEFF6FF); // Soft Ice Blue
  static const Color positive = Color(0xFF10B981); // Emerald
  static const Color positiveSoft = Color(0xFFECFDF5);
  static const Color negative = Color(0xFFEF4444); // Crimson
  static const Color negativeSoft = Color(0xFFFEF2F2);
  static const Color border = Color(0x1F001030);
  static const Color divider = Color(0x12001030);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Dark palette
  static const Color darkBackground = Color(0xFF070A12);
  static const Color darkSurface = Color(0xFF131824);
  static const Color darkBorder = Color(0x28FFFFFF);
  static const Color darkDivider = Color(0x1AFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Per-class color palette — Distinct, vibrant, contrasting hues across classes
  // Each class gets an instantly recognizable signature color:
  // 0: Royal Blue, 1: Warm Amber, 2: Vivid Violet, 3: Sunset Coral, 4: Lush Emerald, 5: Berry Rose, 6: Ocean Cyan, 7: Modern Slate
  static const List<List<Color>> _classPalette = [
    [Color(0xFFEFF6FF), Color(0xFF3B82F6)], // 0: Apple Blue
    [Color(0xFFFFFBEB), Color(0xFFD97706)], // 1: Warm Amber
    [Color(0xFFF5F3FF), Color(0xFF8B5CF6)], // 2: Lavender Violet
    [Color(0xFFFFF7ED), Color(0xFFF97316)], // 3: Soft Coral Orange
    [Color(0xFFECFDF5), Color(0xFF10B981)], // 4: Mint Emerald
    [Color(0xFFFFF1F2), Color(0xFFF43F5E)], // 5: Rose
    [Color(0xFFECFEFF), Color(0xFF06B6D4)], // 6: Sky Teal
    [Color(0xFFF8FAFC), Color(0xFF64748B)], // 7: Slate
  ];

  static Color classBg(int index, {bool dark = false}) {
    final pair = _classPalette[index.abs() % _classPalette.length];
    if (!dark) return pair[0];
    return Color.lerp(pair[1], Colors.black, 0.72)!.withValues(alpha: 0.35);
  }

  static Color classAccent(int index) =>
      _classPalette[index.abs() % _classPalette.length][1];

  /// Intelligent class identity generator:
  /// Extracts meaningful subject icons or distinct grade/number badges
  /// so that classes like "Class 8", "Class 9", "Class 10" never show identical initials.
  static ClassAvatarInfo classAvatarInfo(
    String name,
    String? section,
    int index,
  ) {
    final accent = classAccent(index);
    final clean = name.trim();
    final lower = clean.toLowerCase();

    // 1. Subject keyword detection for Apple Cupertino academic glyphs
    if (lower.contains('math') ||
        lower.contains('algebra') ||
        lower.contains('calc') ||
        lower.contains('geom') ||
        lower.contains('stat')) {
      return ClassAvatarInfo(icon: CupertinoIcons.function, accent: accent);
    }
    if (lower.contains('physic') || lower.contains('mechanic')) {
      return ClassAvatarInfo(icon: CupertinoIcons.compass, accent: accent);
    }
    if (lower.contains('chem') || lower.contains('lab')) {
      return ClassAvatarInfo(icon: CupertinoIcons.lab_flask, accent: accent);
    }
    if (lower.contains('bio') ||
        lower.contains('botany') ||
        lower.contains('zoolog')) {
      return ClassAvatarInfo(
          icon: CupertinoIcons.leaf_arrow_circlepath, accent: accent);
    }
    if (lower.contains('science')) {
      return ClassAvatarInfo(icon: CupertinoIcons.sparkles, accent: accent);
    }
    if (lower.contains('eng') ||
        lower.contains('lit') ||
        lower.contains('read') ||
        lower.contains('gramm')) {
      return ClassAvatarInfo(icon: CupertinoIcons.book_fill, accent: accent);
    }
    if (lower.contains('hist') ||
        lower.contains('civic') ||
        lower.contains('social') ||
        lower.contains('geo')) {
      return ClassAvatarInfo(icon: CupertinoIcons.globe, accent: accent);
    }
    if (lower.contains('art') ||
        lower.contains('design') ||
        lower.contains('draw') ||
        lower.contains('paint')) {
      return ClassAvatarInfo(
          icon: CupertinoIcons.paintbrush_fill, accent: accent);
    }
    if (lower.contains('music') ||
        lower.contains('band') ||
        lower.contains('choir') ||
        lower.contains('orchestra')) {
      return ClassAvatarInfo(icon: CupertinoIcons.music_note_2, accent: accent);
    }
    if (lower.contains('code') ||
        lower.contains('cs') ||
        lower.contains('prog') ||
        lower.contains('comp') ||
        lower.contains('it')) {
      return ClassAvatarInfo(
          icon: CupertinoIcons.chevron_left_slash_chevron_right,
          accent: accent);
    }
    if (lower.contains('pe') ||
        lower.contains('sport') ||
        lower.contains('gym') ||
        lower.contains('fit')) {
      return ClassAvatarInfo(
          icon: CupertinoIcons.sportscourt_fill, accent: accent);
    }

    // 2. Numbered / Grade classes: e.g. "Class 8", "Grade 10", "8th Std", "Class 8B"
    final secClean = (section != null && section.trim().isNotEmpty)
        ? section.trim().toUpperCase()
        : '';
    final numMatch = RegExp(
            r'\b(?:class|grade|std|standard|sec|room)?\s*([0-9]{1,2}(?:st|nd|rd|th)?|[IVXLCDM]{1,4})\b',
            caseSensitive: false)
        .firstMatch(clean);

    if (numMatch != null && numMatch.group(1) != null) {
      final numStr = numMatch.group(1)!;
      if (secClean.isNotEmpty && numStr.length <= 2) {
        return ClassAvatarInfo(label: '$numStr$secClean', accent: accent);
      }
      return ClassAvatarInfo(label: numStr, accent: accent);
    }

    // 3. Multi-word: e.g. "Morning Batch" -> "MB", "Data Structures" -> "DS"
    final words = clean.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final w1 = words[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final w2 = words[1].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (w1.isNotEmpty && w2.isNotEmpty) {
        return ClassAvatarInfo(
            label: '${w1[0]}${w2[0]}'.toUpperCase(), accent: accent);
      }
    }

    // 4. Short single word: e.g. "CS" -> "CS", "Bio" -> "BIO"
    if (clean.length <= 3) {
      return ClassAvatarInfo(label: clean.toUpperCase(), accent: accent);
    }

    // 5. Curated academic Apple glyphs as distinct subject marks based on index/hash
    const fallbackGlyphs = [
      CupertinoIcons.book_fill,
      CupertinoIcons.sparkles,
      CupertinoIcons.function,
      CupertinoIcons.globe,
      CupertinoIcons.lightbulb_fill,
      CupertinoIcons.chart_bar_alt_fill,
      CupertinoIcons.compass,
      CupertinoIcons.star_fill,
      CupertinoIcons.bookmark_fill,
      CupertinoIcons.layers_alt_fill,
      CupertinoIcons.flag_fill,
      CupertinoIcons.rosette,
    ];
    final glyph = fallbackGlyphs[index.abs() % fallbackGlyphs.length];
    return ClassAvatarInfo(icon: glyph, accent: accent);
  }

  // Diverse, vibrant 12-color student avatar palette for clear individual recognition
  static const List<Color> studentPalette = [
    Color(0xFF2563EB), // Royal Blue
    Color(0xFFD97706), // Warm Amber
    Color(0xFF7C3AED), // Vivid Purple
    Color(0xFF059669), // Emerald
    Color(0xFFEA580C), // Sunset Coral
    Color(0xFFE11D48), // Berry Rose
    Color(0xFF0891B2), // Ocean Cyan
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF84CC16), // Lime
    Color(0xFF64748B), // Slate Chalk
  ];

  static Color studentAccent(int idOrIndex) {
    return studentPalette[idOrIndex.abs() % studentPalette.length];
  }

  static Color studentColorFor(String name, [String? id]) {
    final key = id != null && id.isNotEmpty ? id : name;
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return studentPalette[hash % studentPalette.length];
  }

  static String studentInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Color scoreColor(int score, {bool dark = false}) {
    if (score > 0) return dark ? const Color(0xFF34D399) : positive;
    if (score < 0) return dark ? const Color(0xFFF87171) : negative;
    return dark ? darkTextSecondary : textSecondary;
  }

  static Color scoreBg(int score, {bool dark = false}) {
    if (score > 0) {
      return dark
          ? const Color(0xFF064E3B).withValues(alpha: 0.4)
          : positiveSoft;
    }
    if (score < 0) {
      return dark
          ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
          : negativeSoft;
    }
    return dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF8FAFC);
  }

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x06001030), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A001848), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static ThemeData lightTheme() => _buildTheme(Brightness.light);
  static ThemeData darkTheme() => _buildTheme(Brightness.dark);

  static ThemeData get theme => lightTheme();

  static ThemeData _buildTheme(Brightness b) {
    final dark = b == Brightness.dark;
    final primary = accent;
    final bg = dark ? darkBackground : background;
    final surf = dark ? darkSurface : surface;
    final txt = dark ? darkTextPrimary : textPrimary;
    final txtSec = dark ? darkTextSecondary : textSecondary;
    final txtTer = dark ? darkTextTertiary : textTertiary;

    final baseTextTheme = TextTheme(
      headlineLarge: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontFamily: 'Inter', color: txt),
      bodyMedium: TextStyle(fontFamily: 'Inter', color: txtSec),
      bodySmall: TextStyle(fontFamily: 'Inter', color: txtTer, fontSize: 12),
      labelLarge: TextStyle(fontFamily: 'Inter', color: txt, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      brightness: b,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(fontFamily: 'Inter'),
        ),
      ),
      colorScheme: ColorScheme(
        brightness: b,
        primary: primary,
        onPrimary: Colors.white,
        secondary: accentBright,
        onSecondary: Colors.white,
        error: negative,
        onError: Colors.white,
        surface: surf,
        onSurface: txt,
      ),
      textTheme: baseTextTheme,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: txt),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),
      iconTheme: IconThemeData(color: txt),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' show BoxWidthStyle;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../ui/glass_chrome.dart';
import '../ui/glass_surface.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import '../ui/scale.dart';
import 'class_detail_screen.dart';

enum ClassViewMode {
  detailed,
  stats,
  grid,
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchOpen = false;
  int _filterMode = 0; // 0: All, 1: Top Scorers, 2: A-Z
  ClassViewMode _viewMode = ClassViewMode.detailed;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(appProvider);
    final p = Pal.of(context);

    int totalStudents = 0;
    int totalScore = 0;
    int scoredCount = 0;
    for (final cls in classes) {
      totalStudents += cls.students.length;
      for (final st in cls.students) {
        totalScore += st.score;
        scoredCount++;
      }
    }
    final avgScore = scoredCount > 0 ? (totalScore / scoredCount).round() : 0;

    var filtered = _query.isEmpty
        ? classes
        : classes
            .where((c) => c.displayName
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    if (_filterMode == 1) {
      filtered = List.of(filtered)
        ..sort((a, b) {
          final aTop = a.students.isEmpty
              ? -9999
              : a.students.map((s) => s.score).reduce(math.max);
          final bTop = b.students.isEmpty
              ? -9999
              : b.students.map((s) => s.score).reduce(math.max);
          return bTop.compareTo(aTop);
        });
    } else if (_filterMode == 2) {
      filtered = List.of(filtered)
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    return GlassScaffold(
      background: const GradientBackground(),
      statusBarStyle:
          p.dark ? GlassStatusBarStyle.light : GlassStatusBarStyle.dark,
      body: Listener(
        onPointerDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.paddingOf(context).top + 10.dp,
                ),
                // Header & Important Overview Section (Never unmounts, zero flash)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1400.dp),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWideLayout(context) ? 24.dp : 16.dp,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(p, classes),
                          if (_searchOpen) ...[
                            SizedBox(height: 10.dp),
                            SpringIn(
                              key: const ValueKey('hdr-search'),
                              from: Offset(0, -10.dp),
                              child: _searchField(p),
                            ),
                          ] else if (classes.isNotEmpty) ...[
                            SizedBox(height: 12.dp),
                            _overviewControlBar(p),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.dp),
                Expanded(
                  child: classes.isEmpty
                      ? _empty(p)
                      : filtered.isEmpty
                          ? _noResults(p)
                          : _classList(context, p, filtered, classes),
                ),
              ],
            ),
            // Floating bottom dock & FAB
            if (!_searchOpen ||
                MediaQuery.viewInsetsOf(context).bottom == 0)
              SpringIn(
                key: const ValueKey('dock-bar'),
                from: Offset(0, 90.dp),
                child: Stack(
                  children: [
                    _bottomBar(p, classes.length, totalStudents, avgScore),
                    _fab(p),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header (Permanent, zero flash) ────────────────────────────────
  Widget _header(Pal p, List<ClassModel> classes) {
    return SizedBox(
      height: 46.dp,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 4.dp),
          // App Brand Mark
          Image.asset(
            'assets/icon/mark.png',
            height: 18.5.dp,
            color: p.ink,
            colorBlendMode: BlendMode.srcIn,
            semanticLabel: 'Scorio',
            errorBuilder: (context, error, stackTrace) => Icon(
              CupertinoIcons.chart_bar_fill,
              color: p.accent,
              size: 18.5.dp,
            ),
          ),
          SizedBox(width: 10.dp),
          // Brand Title
          Expanded(
            child: Text(
              'Scorio',
              style: TextStyle(
                color: p.ink,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // Search toggle button
          RoundGlassButton(
            icon: _searchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
            size: 40.dp,
            semanticLabel: _searchOpen ? 'Close search' : 'Search classes',
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  _query = '';
                  FocusManager.instance.primaryFocus?.unfocus();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Classroom View Controls & Filter Bar (Above Class List) ──────
  Widget _overviewControlBar(Pal p) {
    return GlassSurface(
      radius: 18.dp,
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 7.dp),
      child: Row(
        children: [
          // Sort Tabs: All · Top · A-Z
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterTab('All', 0, p),
              SizedBox(width: 4.dp),
              _filterTab('Top', 1, p),
              SizedBox(width: 4.dp),
              _filterTab('A-Z', 2, p),
            ],
          ),
          const Spacer(),
          // Vertical divider
          Container(
            width: 1.dp,
            height: 14.dp,
            color: p.faint,
            margin: EdgeInsets.symmetric(horizontal: 4.dp),
          ),
          // View Mode Options: Detailed · Stats · Grid
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewModeTab('Detailed', ClassViewMode.detailed, CupertinoIcons.rectangle_grid_1x2, p),
              SizedBox(width: 3.dp),
              _viewModeTab('Stats', ClassViewMode.stats, CupertinoIcons.chart_bar_alt_fill, p),
              SizedBox(width: 3.dp),
              _viewModeTab('Grid', ClassViewMode.grid, CupertinoIcons.square_grid_2x2, p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewModeTab(
    String label,
    ClassViewMode mode,
    IconData icon,
    Pal p,
  ) {
    final selected = _viewMode == mode;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _viewMode = mode);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 8.dp : 6.dp,
            vertical: 4.dp,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (p.dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : p.accent.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10.dp),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13.dp,
                color: selected ? (p.dark ? Colors.white : p.accent) : p.sub,
              ),
              if (selected) ...[
                SizedBox(width: 4.dp),
                Text(
                  label,
                  style: TextStyle(
                    color: p.dark ? Colors.white : p.accent,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterTab(String label, int mode, Pal p) {
    final selected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterMode = mode);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 8.5.dp, vertical: 4.dp),
        decoration: BoxDecoration(
          color: selected
              ? (p.dark ? Colors.white.withValues(alpha: 0.14) : p.accent.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.dp),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (p.dark ? Colors.white : p.accent) : p.sub,
            fontSize: 11.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Search Field (Smooth inline dropdown, zero flash) ─────────────
  Widget _searchField(Pal p) {
    return SizedBox(
      height: 42.dp,
      child: GlassSurface(
        radius: 21.dp,
        thick: true,
        padding: EdgeInsets.symmetric(horizontal: 14.dp),
        child: Row(
          children: [
            Icon(CupertinoIcons.search, size: 16.dp, color: p.sub),
            SizedBox(width: 8.dp),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                selectionWidthStyle: BoxWidthStyle.tight,
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                cursorColor: p.accent,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: p.ink, fontSize: 15.sp),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.dp),
                  border: InputBorder.none,
                  hintText: 'Search classes…',
                  hintStyle: TextStyle(color: p.sub, fontSize: 14.sp),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: p.sub,
                  size: 16.dp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Class List (Detailed, Stats, and Grid modes) ──
  Widget _classList(
    BuildContext context,
    Pal p,
    List<ClassModel> filtered,
    List<ClassModel> allClasses,
  ) {
    final isWide = isWideLayout(context);
    final pad = EdgeInsets.fromLTRB(
      isWide ? 24.dp : 16.dp,
      4.dp,
      isWide ? 24.dp : 16.dp,
      100.dp,
    );

    if (_viewMode == ClassViewMode.grid || (isWide && _viewMode != ClassViewMode.stats)) {
      final gap = 10.dp;
      final room = math.min(MediaQuery.sizeOf(context).width, 1400.dp) -
          pad.horizontal;
      final minColumn = _viewMode == ClassViewMode.grid ? 150.0 : 360.0;
      final columns = isWide
          ? ((room + gap) / (minColumn + gap)).floor().clamp(1, 4)
          : 2;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1400.dp),
          child: GridView.builder(
            padding: pad,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: _viewMode == ClassViewMode.grid ? 120.dp : 74.dp,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final cls = filtered[i];
              final colorIndex = allClasses.indexOf(cls);
              return EntranceIn(
                index: i,
                child: _viewMode == ClassViewMode.grid
                    ? _classCardGrid(context, p, cls, colorIndex)
                    : _classCard(context, p, cls, colorIndex),
              );
            },
          ),
        ),
      );
    }

    if (_viewMode == ClassViewMode.stats) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720.dp),
          child: ListView.builder(
            padding: pad,
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final cls = filtered[i];
              final colorIndex = allClasses.indexOf(cls);
              return Padding(
                padding: EdgeInsets.only(bottom: 10.dp),
                child: EntranceIn(
                  index: i,
                  child: _classCardStats(context, p, cls, colorIndex),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default: Detailed list
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720.dp),
        child: ListView.builder(
          padding: pad,
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final cls = filtered[i];
            final colorIndex = allClasses.indexOf(cls);
            return Padding(
              padding: EdgeInsets.only(bottom: 10.dp),
              child: EntranceIn(
                index: i,
                child: _classCard(context, p, cls, colorIndex),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Stats Class Card (Score Analytics & Top Performer) ────────────
  Widget _classCardStats(
    BuildContext context,
    Pal p,
    ClassModel cls,
    int colorIndex,
  ) {
    final avatarInfo =
        AppTheme.classAvatarInfo(cls.name, cls.section, colorIndex);
    final accent = avatarInfo.accent;
    final students = cls.students;
    final topStudent = students.isNotEmpty
        ? students.reduce((a, b) => a.score > b.score ? a : b)
        : null;
    final totalScore = students.fold<int>(0, (s, st) => s + st.score);

    return Dismissible(
      key: Key('stats-${cls.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, cls.displayName),
      onDismissed: (_) {
        ref.read(appProvider.notifier).deleteClass(cls.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 22.dp),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20.dp),
        ),
        child: Icon(CupertinoIcons.trash, color: Colors.white, size: 22.dp),
      ),
      child: GlassPress(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassDetailScreen(classId: cls.id),
            ),
          );
        },
        onLongPress: () => _showClassOptions(context, cls, colorIndex),
        label: cls.displayName,
        builder: (down) => GlassSurface(
          radius: 20.dp,
          lit: down,
          padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 8.dp, 12.dp),
          child: Row(
            children: [
              // Avatar with soft gradient & hairline rim
              Container(
                width: 44.dp,
                height: 44.dp,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.20)!,
                      Color.lerp(accent, Colors.black, 0.04)!,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: p.dark ? 0.20 : 0.35),
                    width: 0.8.dp,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: p.dark ? 0.16 : 0.10),
                      blurRadius: 6.dp,
                      offset: Offset(0, 1.5.dp),
                    ),
                  ],
                ),
                child: Center(
                  child: avatarInfo.icon != null
                      ? Icon(avatarInfo.icon, size: 20.dp, color: Colors.white)
                      : Text(
                          avatarInfo.label ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 13.dp),
              // Class Name + Analytic Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cls.name,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 16.5.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cls.section != null && cls.section!.isNotEmpty) ...[
                          SizedBox(width: 6.dp),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.5.dp, vertical: 1.5.dp),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: p.dark ? 0.20 : 0.10),
                              borderRadius: BorderRadius.circular(6.dp),
                            ),
                            child: Text(
                              cls.section!.length <= 2 ? 'Sec ${cls.section}' : cls.section!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 5.dp),
                    // Stats Badges Row: Total Score Capsule + Top Student Capsule
                    Row(
                      children: [
                        // Total Score Capsule
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.dp, vertical: 2.dp),
                          decoration: BoxDecoration(
                            color: p.dark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6.dp),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.chart_bar_fill,
                                size: 10.dp,
                                color: p.accent,
                              ),
                              SizedBox(width: 3.5.dp),
                              Text(
                                '${totalScore >= 0 ? "+$totalScore" : "$totalScore"} pts',
                                style: TextStyle(
                                  color: p.ink,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.dp),
                        // Top Student or Count Capsule
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.dp, vertical: 2.dp),
                            decoration: BoxDecoration(
                              color: topStudent != null && topStudent.score > 0
                                  ? (p.dark
                                      ? const Color(0xFF059669).withValues(alpha: 0.18)
                                      : const Color(0xFF10B981).withValues(alpha: 0.12))
                                  : (p.dark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(6.dp),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  topStudent != null && topStudent.score > 0
                                      ? CupertinoIcons.star_fill
                                      : CupertinoIcons.person_2_fill,
                                  size: 10.dp,
                                  color: topStudent != null && topStudent.score > 0
                                      ? (p.dark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                      : p.sub,
                                ),
                                SizedBox(width: 3.5.dp),
                                Flexible(
                                  child: Text(
                                    topStudent != null && topStudent.score > 0
                                        ? '${topStudent.name} (+${topStudent.score})'
                                        : '${students.length} ${students.length == 1 ? "student" : "students"}',
                                    style: TextStyle(
                                      color: topStudent != null && topStudent.score > 0
                                          ? (p.dark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                          : p.sub,
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Options menu
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showClassOptions(context, cls, colorIndex),
                child: Padding(
                  padding: EdgeInsets.all(8.dp),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 20.dp,
                    color: p.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Grid Class Card ────────────────────────────────────────────────
  Widget _classCardGrid(
    BuildContext context,
    Pal p,
    ClassModel cls,
    int colorIndex,
  ) {
    final avatarInfo =
        AppTheme.classAvatarInfo(cls.name, cls.section, colorIndex);
    final accent = avatarInfo.accent;
    final students = cls.students;
    final topStudent = students.isNotEmpty
        ? students.reduce((a, b) => a.score > b.score ? a : b)
        : null;

    return GlassPress(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassDetailScreen(classId: cls.id),
          ),
        );
      },
      onLongPress: () => _showClassOptions(context, cls, colorIndex),
      label: cls.displayName,
      builder: (down) => GlassSurface(
        radius: 18.dp,
        lit: down,
        padding: EdgeInsets.all(12.dp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Avatar + Ellipsis
            Row(
              children: [
                Container(
                  width: 30.dp,
                  height: 30.dp,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(accent, Colors.white, 0.20)!,
                        Color.lerp(accent, Colors.black, 0.04)!,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: p.dark ? 0.20 : 0.35),
                      width: 0.8.dp,
                    ),
                  ),
                  child: Center(
                    child: avatarInfo.icon != null
                        ? Icon(avatarInfo.icon, size: 13.dp, color: Colors.white)
                        : Text(
                            avatarInfo.label ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showClassOptions(context, cls, colorIndex),
                  child: Padding(
                    padding: EdgeInsets.all(4.dp),
                    child: Icon(
                      CupertinoIcons.ellipsis,
                      size: 16.dp,
                      color: p.sub,
                    ),
                  ),
                ),
              ],
            ),
            // Middle: Name & Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cls.name,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.5.dp),
                Text(
                  cls.section != null && cls.section!.isNotEmpty
                      ? 'Sec ${cls.section} · ${students.length} st.'
                      : '${students.length} ${students.length == 1 ? "student" : "students"}',
                  style: TextStyle(color: p.sub, fontSize: 11.5.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // Bottom: Top score indicator
            if (topStudent != null)
              Text(
                topStudent.score > 0
                    ? 'top +${topStudent.score}'
                    : (topStudent.score < 0 ? 'top ${topStudent.score}' : 'top 0'),
                style: TextStyle(
                  color: topStudent.score > 0
                      ? (p.dark ? const Color(0xFF34D399) : const Color(0xFF059669))
                      : (topStudent.score < 0
                          ? (p.dark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                          : p.sub),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _classCard(
    BuildContext context,
    Pal p,
    ClassModel cls,
    int colorIndex,
  ) {
    final avatarInfo =
        AppTheme.classAvatarInfo(cls.name, cls.section, colorIndex);
    final accent = avatarInfo.accent;

    final students = cls.students;
    final topStudent = students.isNotEmpty
        ? students.reduce((a, b) => a.score > b.score ? a : b)
        : null;

    return Dismissible(
      key: Key(cls.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, cls.displayName),
      onDismissed: (_) {
        ref.read(appProvider.notifier).deleteClass(cls.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 22.dp),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20.dp),
        ),
        child: Icon(CupertinoIcons.trash, color: Colors.white, size: 22.dp),
      ),
      child: GlassPress(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassDetailScreen(classId: cls.id),
            ),
          );
        },
        onLongPress: () => _showClassOptions(context, cls, colorIndex),
        label: cls.displayName,
        builder: (down) => GlassSurface(
          radius: 20.dp,
          lit: down,
          padding: EdgeInsets.fromLTRB(16.dp, 13.dp, 8.dp, 13.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Softened circular pastel avatar with gentle ambient glow & hairline rim
              Container(
                width: 44.dp,
                height: 44.dp,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.22)!,
                      Color.lerp(accent, Colors.black, 0.04)!,
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: p.dark ? 0.20 : 0.35),
                    width: 0.8.dp,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: p.dark ? 0.16 : 0.10),
                      blurRadius: 6.dp,
                      offset: Offset(0, 1.5.dp),
                    ),
                  ],
                ),
                child: Center(
                  child: avatarInfo.icon != null
                      ? Icon(
                          avatarInfo.icon,
                          size: 20.dp,
                          color: Colors.white,
                        )
                      : Text(
                          avatarInfo.label!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: avatarInfo.label!.length > 2
                                ? 12.5.sp
                                : 15.sp,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 14.dp),
              // Title and clean typographic subtitle (Breeze style)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2.dp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cls.name,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 16.5.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.5.dp),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (cls.section != null &&
                                cls.section!.isNotEmpty) ...[
                              TextSpan(
                                text: cls.section!.length <= 2
                                    ? 'Sec ${cls.section}'
                                    : cls.section!,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '  ·  '),
                            ],
                            TextSpan(
                              text:
                                  '${students.length} ${students.length == 1 ? "student" : "students"}',
                            ),
                            if (topStudent != null) ...[
                              TextSpan(text: '  ·  '),
                              TextSpan(
                                text: topStudent.score > 0
                                    ? 'top +${topStudent.score}'
                                    : (topStudent.score < 0
                                        ? 'top ${topStudent.score}'
                                        : 'top 0'),
                                style: TextStyle(
                                  color: topStudent.score > 0
                                      ? (p.dark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF059669))
                                      : (topStudent.score < 0
                                          ? (p.dark
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFFDC2626))
                                          : p.sub),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.sub, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
              ),
              // Options menu
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showClassOptions(context, cls, colorIndex),
                child: Padding(
                  padding: EdgeInsets.all(8.dp),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 20.dp,
                    color: p.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating Bottom Dock (Breeze style, responsive on wide screens) ──
  Widget _bottomBar(
    Pal p,
    int classCount,
    int studentCount,
    int avgScore,
  ) {
    final isWide = isWideLayout(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 14.dp;
    final sideOffset = isWide
        ? math.max(24.dp, (MediaQuery.sizeOf(context).width - 1400.dp) / 2 + 24.dp)
        : 16.dp;

    return Positioned(
      left: sideOffset,
      bottom: bottom,
      child: GlassSurface(
        radius: 28.dp,
        thick: true,
        padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.folder, size: 14.dp, color: p.accent),
            SizedBox(width: 6.dp),
            Text(
              '$classCount ${classCount == 1 ? "class" : "classes"}',
              style: TextStyle(
                color: p.ink,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8.dp),
            Container(width: 1, height: 12.dp, color: p.faint),
            SizedBox(width: 8.dp),
            Icon(CupertinoIcons.person_2, size: 14.dp, color: p.accent),
            SizedBox(width: 6.dp),
            Text(
              '$studentCount students',
              style: TextStyle(
                color: p.ink,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Floating Action Button (Breeze style, responsive on wide screens) ──
  Widget _fab(Pal p) {
    final isWide = isWideLayout(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 14.dp;
    final sideOffset = isWide
        ? math.max(24.dp, (MediaQuery.sizeOf(context).width - 1400.dp) / 2 + 24.dp)
        : 16.dp;

    return Positioned(
      right: sideOffset,
      bottom: bottom,
      child: GlassPress(
        onTap: () {
          HapticFeedback.lightImpact();
          _showClassForm(context, null);
        },
        label: 'Create Class',
        builder: (down) => SizedBox.square(
          dimension: 48.dp,
          child: GlassSurface(
            radius: 24.dp,
            thick: true,
            lit: down,
            gradient: p.accentFill,
            child: const Center(
              child: Icon(
                CupertinoIcons.plus,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────
  Widget _empty(Pal p) {
    return Transform.translate(
      offset: Offset(0, -40.dp),
      child: EmptyState(
        icon: CupertinoIcons.folder_badge_plus,
        title: 'No Classes Yet',
        hint: 'Tap the + button below to create your first class.',
        bg: false,
      ),
    );
  }

  Widget _noResults(Pal p) {
    return Transform.translate(
      offset: Offset(0, -40.dp),
      child: EmptyState(
        icon: CupertinoIcons.search,
        title: 'No Classes Found',
        hint: 'No classes match "$_query".',
        bg: false,
      ),
    );
  }

  // ── Options Sheet ─────────────────────────────────────────────────
  void _showClassOptions(
    BuildContext context,
    ClassModel cls,
    int colorIndex,
  ) {
    final p = Pal.of(context);
    final avatarInfo =
        AppTheme.classAvatarInfo(cls.name, cls.section, colorIndex);
    final accent = avatarInfo.accent;

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 16.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.dp, 8.dp, 8.dp, 12.dp),
              child: Row(
                children: [
                  Container(
                    width: 44.dp,
                    height: 44.dp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.dp),
                      color: accent.withValues(alpha: p.dark ? 0.16 : 0.08),
                      border: Border.all(
                        color: accent.withValues(alpha: p.dark ? 0.30 : 0.20),
                        width: 1.1.dp,
                      ),
                    ),
                    child: Center(
                      child: avatarInfo.icon != null
                          ? Icon(
                              avatarInfo.icon,
                              size: 20.dp,
                              color: accent,
                            )
                          : Text(
                              avatarInfo.label!,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: avatarInfo.label!.length > 2
                                    ? 12.5.sp
                                    : 15.sp,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls.displayName,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${cls.students.length} students',
                          style: TextStyle(color: p.sub, fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Hairline(),
            _sheetTile(
              p,
              icon: CupertinoIcons.arrow_up_right_square,
              title: 'Open Class',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassDetailScreen(classId: cls.id),
                  ),
                );
              },
            ),
            _sheetTile(
              p,
              icon: CupertinoIcons.pencil,
              title: 'Edit Class Name',
              onTap: () {
                Navigator.pop(ctx);
                _showClassForm(context, cls);
              },
            ),
            _sheetTile(
              p,
              icon: CupertinoIcons.arrow_counterclockwise,
              title: 'Reset All Scores',
              onTap: () {
                Navigator.pop(ctx);
                _confirmResetScores(context, cls.displayName).then((ok) {
                  if (ok == true) {
                    ref.read(appProvider.notifier).resetScores(cls.id);
                  }
                });
              },
            ),
            const Hairline(),
            _sheetTile(
              p,
              icon: CupertinoIcons.trash,
              title: 'Delete Class',
              danger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, cls.displayName).then((ok) {
                  if (ok == true) {
                    ref.read(appProvider.notifier).deleteClass(cls.id);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
    Pal p, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final dangerColor =
        p.dark ? const Color(0xFFFF5449) : const Color(0xFFE53935);
    final color = danger ? dangerColor : p.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 48.dp,
        padding: EdgeInsets.symmetric(horizontal: 10.dp),
        child: Row(
          children: [
            Container(
              width: 36.dp,
              height: 36.dp,
              decoration: BoxDecoration(
                color: danger
                    ? dangerColor.withValues(alpha: p.dark ? 0.28 : 0.15)
                    : p.accent.withValues(alpha: p.dark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10.dp),
                border: danger
                    ? Border.all(
                        color:
                            dangerColor.withValues(alpha: p.dark ? 0.45 : 0.30),
                        width: 0.8.dp,
                      )
                    : null,
              ),
              child: Center(
                child: Icon(icon,
                    size: 18.dp, color: danger ? dangerColor : p.accent),
              ),
            ),
            SizedBox(width: 14.dp),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15.5.sp,
                  fontWeight: danger ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 15.dp,
              color: danger ? dangerColor.withValues(alpha: 0.7) : p.sub,
            ),
          ],
        ),
      ),
    );
  }

  // ── Class Form Sheet ──────────────────────────────────────────────
  void _showClassForm(BuildContext context, ClassModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sectionCtrl = TextEditingController(text: existing?.section ?? '');
    final formKey = GlobalKey<FormState>();
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16.dp, 10.dp, 16.dp, 20.dp),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'New Class' : 'Edit Class',
                style: TextStyle(
                  color: p.ink,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 18.dp),
              Caption('CLASS NAME'),
              SizedBox(height: 6.dp),
              GlassSurface(
                radius: 14.dp,
                padding: EdgeInsets.symmetric(horizontal: 14.dp),
                child: TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  style: TextStyle(color: p.ink, fontSize: 15.sp),
                  cursorColor: p.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.dp),
                    border: InputBorder.none,
                    hintText: 'e.g., Grade 10',
                    hintStyle: TextStyle(color: p.sub, fontSize: 14.5.sp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Caption('SECTION (OPTIONAL)'),
              SizedBox(height: 6.dp),
              GlassSurface(
                radius: 14.dp,
                padding: EdgeInsets.symmetric(horizontal: 14.dp),
                child: TextFormField(
                  controller: sectionCtrl,
                  style: TextStyle(color: p.ink, fontSize: 15.sp),
                  cursorColor: p.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.dp),
                    border: InputBorder.none,
                    hintText: 'e.g., A',
                    hintStyle: TextStyle(color: p.sub, fontSize: 14.5.sp),
                  ),
                ),
              ),
              SizedBox(height: 24.dp),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 48.dp,
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: p.sub,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    flex: 2,
                    child: GlassPress(
                      onTap: () {
                        if (formKey.currentState!.validate()) {
                          final sec = sectionCtrl.text.trim();
                          if (existing == null) {
                            ref.read(appProvider.notifier).addClass(
                                  ClassModel(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    name: nameCtrl.text.trim(),
                                    section: sec.isEmpty ? null : sec,
                                  ),
                                );
                          } else {
                            ref.read(appProvider.notifier).updateClass(
                                  existing.copyWith(
                                    name: nameCtrl.text.trim(),
                                    section: sec.isEmpty ? null : sec,
                                  ),
                                );
                          }
                          Navigator.pop(ctx);
                        }
                      },
                      label: 'Save',
                      child: SizedBox(
                        height: 48.dp,
                        child: GlassSurface(
                          radius: 16.dp,
                          thick: true,
                          gradient: p.accentFill,
                          child: Center(
                            child: Text(
                              existing == null ? 'Create' : 'Save',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Confirmation Sheets ───────────────────────────────────────────
  Future<bool?> _confirmResetScores(BuildContext context, String name) {
    final p = Pal.of(context);
    return showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18.dp, 10.dp, 18.dp, 20.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset Scores?',
              style: TextStyle(
                color: p.ink,
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'All student scores in $name will be reset to 0.',
              style: TextStyle(color: p.sub, fontSize: 14.sp),
            ),
            SizedBox(height: 20.dp),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 46.dp,
                      alignment: Alignment.center,
                      child: Text('Cancel',
                          style: TextStyle(color: p.sub, fontSize: 15.sp)),
                    ),
                  ),
                ),
                SizedBox(width: 10.dp),
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx, true),
                    label: 'Reset',
                    child: SizedBox(
                      height: 46.dp,
                      child: GlassSurface(
                        radius: 14.dp,
                        thick: true,
                        tint: const Color(0xFFF59E0B),
                        child: Center(
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    final p = Pal.of(context);
    return showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18.dp, 10.dp, 18.dp, 20.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete Class?',
              style: TextStyle(
                color: p.ink,
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'Delete "$name"? All students and scores will be removed.',
              style: TextStyle(color: p.sub, fontSize: 14.sp),
            ),
            SizedBox(height: 20.dp),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 46.dp,
                      alignment: Alignment.center,
                      child: Text('Cancel',
                          style: TextStyle(color: p.sub, fontSize: 15.sp)),
                    ),
                  ),
                ),
                SizedBox(width: 10.dp),
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx, true),
                    label: 'Delete',
                    child: Container(
                      height: 46.dp,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            p.dark
                                ? const Color(0xFFFF5449)
                                : const Color(0xFFEF4444),
                            p.dark
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFDC2626),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14.dp),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: p.dark ? 0.45 : 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

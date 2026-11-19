import 'dart:math' as math;
import 'dart:ui' show BoxWidthStyle;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../ui/glass_chrome.dart';
import '../ui/glass_surface.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import '../ui/scale.dart';
import 'class_detail_screen.dart';

enum ClassViewMode { cards, list, grid }

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
  ClassViewMode? _userSelectedViewMode;
  bool _introPlayed = false;
  bool? _lastGrid;
  DateTime? _swappedAt;

  ClassViewMode _resolvedViewMode(BuildContext context) {
    if (_userSelectedViewMode != null) return _userSelectedViewMode!;
    return isWideLayout(context) ? ClassViewMode.grid : ClassViewMode.cards;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _introPlayed = true);
    });
  }

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
              .where(
                (c) =>
                    c.displayName.toLowerCase().contains(_query.toLowerCase()),
              )
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
      statusBarStyle: p.dark
          ? GlassStatusBarStyle.light
          : GlassStatusBarStyle.dark,
      body: Listener(
        onPointerDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 2.dp),
                // Header & Important Overview Section (Never unmounts, zero flash)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1040.dp),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWideLayout(context) ? 24.dp : 16.dp,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isWideLayout(context) && _searchOpen) ...[
                            // On mobile: search container & cross replaces header in place
                            SpringIn(
                              key: const ValueKey('hdr-search-mobile'),
                              from: Offset(0, -6.dp),
                              child: _searchField(p),
                            ),
                          ] else ...[
                            // Header (on wide screens / tab mode / Moto Connect: search opens IN PLACE)
                            _header(p, classes),
                          ],
                          if (!isWideLayout(context) &&
                              classes.isNotEmpty &&
                              !_searchOpen) ...[
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
            // Floating bottom dock & FAB (Prism/Breeze style, responsive on fold, tab & mobile)
            if (classes.isNotEmpty &&
                (!_searchOpen || MediaQuery.viewInsetsOf(context).bottom == 0))
              SpringIn(
                key: const ValueKey('dock-bar'),
                from: Offset(0, 90.dp),
                child: isWideLayout(context)
                    ? _desktopDock(p, classes.length, totalStudents)
                    : Stack(
                        children: [
                          _bottomBar(
                            p,
                            classes.length,
                            totalStudents,
                            avgScore,
                          ),
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
    final isWide = isWideLayout(context);
    return SizedBox(
      height: 52.dp,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 4.dp),
          // App Brand Mark (slightly smaller, elegant footprint)
          Image.asset(
            'assets/icon/mark.png',
            height: 15.5.dp,
            color: p.ink,
            colorBlendMode: BlendMode.srcIn,
            semanticLabel: 'Scorio',
            errorBuilder: (context, error, stackTrace) => Icon(
              CupertinoIcons.chart_bar_fill,
              color: p.accent,
              size: 15.5.dp,
            ),
          ),
          SizedBox(width: 8.dp),
          // Brand Title (slightly less bold & slightly smaller font)
          Text(
            'Scorio',
            style: TextStyle(
              color: p.ink,
              fontSize: 19.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (isWide && classes.isNotEmpty) ...[
            _overviewControlBar(p),
            SizedBox(width: 10.dp),
          ],
          // Appearance: follow the phone, or always light / dark.
          if (!_searchOpen) ...[
            RoundGlassButton(
              size: 38.dp,
              semanticLabel: 'Appearance',
              onPressed: () => _showAppearanceSheet(context),
              child: Icon(
                _themeIcon(ref.watch(themeModeProvider)),
                size: 16.dp,
                color: p.ink,
              ),
            ),
            SizedBox(width: 8.dp),
          ],
          // On wide screens (tab mode / Moto Connect / Fold / Desktop), search opens AT PLACE in header row!
          if (isWide && _searchOpen)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 320.dp),
              child: SpringIn(
                key: const ValueKey('hdr-search-inplace'),
                from: Offset(10.dp, 0),
                child: _searchField(p),
              ),
            )
          else if (!_searchOpen)
            RoundGlassButton(
              size: 38.dp,
              semanticLabel: 'Search classes',
              onPressed: () {
                setState(() => _searchOpen = true);
              },
              child: isWide
                  ? Icon(CupertinoIcons.search, size: 15.5.dp, color: p.ink)
                  : SemiboldIcon(
                      CupertinoIcons.search,
                      size: 15.5.dp,
                      color: p.ink,
                    ),
            ),
        ],
      ),
    );
  }

  // ── Classroom View Controls & Filter Bar (Above Class List) ──────
  Widget _overviewControlBar(Pal p) {
    final isWide = isWideLayout(context);
    return SizedBox(
      height: 44.dp,
      child: GlassSurface(
        radius: 22.dp,
        card: true,
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 10.dp : 12.dp,
          vertical: 4.dp,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (!isWide) const Spacer() else SizedBox(width: 8.dp),
            // Vertical divider
            Container(
              width: 1.dp,
              height: 16.dp,
              color: p.faint,
              margin: EdgeInsets.symmetric(horizontal: 5.dp),
            ),
            if (isWide) SizedBox(width: 4.dp),
            // View Mode Options: Cards · List · Grid
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewModeTab(
                  'Cards',
                  ClassViewMode.cards,
                  CupertinoIcons.rectangle_grid_1x2,
                  p,
                ),
                SizedBox(width: 3.5.dp),
                _viewModeTab(
                  'List',
                  ClassViewMode.list,
                  CupertinoIcons.list_bullet,
                  p,
                ),
                SizedBox(width: 3.5.dp),
                _viewModeTab(
                  'Grid',
                  ClassViewMode.grid,
                  CupertinoIcons.square_grid_2x2,
                  p,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewModeTab(String label, ClassViewMode mode, IconData icon, Pal p) {
    final selected = _resolvedViewMode(context) == mode;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _userSelectedViewMode = mode);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: kSpringSoft,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 9.5.dp : 7.dp,
            vertical: 5.5.dp,
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
                size: 13.5.dp,
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
        duration: const Duration(milliseconds: 240),
        curve: kSpringSoft,
        padding: EdgeInsets.symmetric(horizontal: 9.5.dp, vertical: 5.5.dp),
        decoration: BoxDecoration(
          color: selected
              ? (p.dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : p.accent.withValues(alpha: 0.12))
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

  // ── Search Field (Vertically centered hint, compact footprint, smaller icons) ─
  Widget _searchField(Pal p) {
    return SizedBox(
      height: 40.dp,
      child: Row(
        children: [
          Expanded(
            child: GlassSurface(
              radius: 20.dp,
              thick: true,
              card: true,
              padding: EdgeInsets.symmetric(horizontal: 13.dp),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 15.dp,
                    color: p.ink.withValues(alpha: 0.82),
                  ),
                  SizedBox(width: 8.dp),
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
                        selectionWidthStyle: BoxWidthStyle.tight,
                        magnifierConfiguration:
                            TextMagnifierConfiguration.disabled,
                        cursorColor: p.accent,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 14.sp,
                          height: 1.15,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Search classes…',
                          hintStyle: TextStyle(
                            color: p.sub,
                            fontSize: 14.sp,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      child: Padding(
                        padding: EdgeInsets.only(left: 4.dp),
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          color: p.sub,
                          size: 14.dp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.dp),
          RoundGlassButton(
            icon: CupertinoIcons.xmark,
            size: 38.dp,
            iconSize: 13.5.dp,
            semanticLabel: 'Close search',
            onPressed: () {
              _searchCtrl.clear();
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _searchOpen = false;
                _query = '';
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Class List (Cards, List, and Grid modes with Breeze-style morph) ──
  Widget _classList(
    BuildContext context,
    Pal p,
    List<ClassModel> filtered,
    List<ClassModel> allClasses,
  ) {
    final viewMode = _resolvedViewMode(context);
    final isWide = isWideLayout(context);
    final pad = EdgeInsets.fromLTRB(
      isWide ? 24.dp : 16.dp,
      4.dp,
      isWide ? 24.dp : 16.dp,
      MediaQuery.paddingOf(context).bottom +
          104.dp +
          (_searchOpen ? MediaQuery.viewInsetsOf(context).bottom : 0),
    );

    final isGrid = viewMode == ClassViewMode.grid;
    if (_lastGrid != null && _lastGrid != isGrid) _swappedAt = DateTime.now();
    _lastGrid = isGrid;
    final swapped =
        _swappedAt != null &&
        DateTime.now().difference(_swappedAt!) <
            const Duration(milliseconds: 600);

    Widget content;
    if (isGrid) {
      final gap = 12.dp;

      content = Center(
        key: const ValueKey('grid-view'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200.dp),
          child: LayoutBuilder(
            builder: (context, box) {
              // Two columns on a phone, three on a fold or desktop, matching
              // the student grid inside a class.
              final columns = (box.maxWidth / 340.dp).floor().clamp(2, 3);
              return GridView.builder(
                padding: pad,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: 112.dp,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final cls = filtered[i];
                  final colorIndex = allClasses.indexOf(cls);
                  return KeyedSubtree(
                    key: ValueKey('class-grid-${cls.id}'),
                    child: _SwapIn(
                      index: i,
                      play: swapped,
                      child: EntranceIn(
                        index: i,
                        play: !_introPlayed && !_searchOpen,
                        child: _classCardGrid(context, p, cls, colorIndex),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    } else {
      final isList = viewMode == ClassViewMode.list;
      if (isWide) {
        final gap = 12.dp;
        const columns = 2;

        content = Center(
          key: ValueKey('wide-morph-view-$isList'),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1040.dp),
            child: GridView.builder(
              padding: pad,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: isList ? 58.dp : 88.dp,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final cls = filtered[i];
                final colorIndex = allClasses.indexOf(cls);
                return KeyedSubtree(
                  key: ValueKey('class-morph-${cls.id}'),
                  child: _SwapIn(
                    index: i,
                    play: swapped,
                    child: EntranceIn(
                      index: i,
                      play: !_introPlayed && !_searchOpen,
                      child: _classCardMorph(
                        context,
                        p,
                        cls,
                        colorIndex,
                        isList: isList,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        content = Center(
          key: const ValueKey('list-morph-view'),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720.dp),
            child: ListView.builder(
              padding: pad,
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final cls = filtered[i];
                final colorIndex = allClasses.indexOf(cls);
                return KeyedSubtree(
                  key: ValueKey('class-morph-${cls.id}'),
                  child: _SwapIn(
                    index: i,
                    play: swapped,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isList ? 8.dp : 10.dp),
                      child: EntranceIn(
                        index: i,
                        play: !_introPlayed && !_searchOpen,
                        child: _classCardMorph(
                          context,
                          p,
                          cls,
                          colorIndex,
                          isList: isList,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    return KeyedSubtree(
      key: ValueKey(isGrid ? 'classes-grid-$isWide' : 'classes-list-$isWide'),
      child: content,
    );
  }

  // ── Morphing Class Card (Breeze spring morph for Cards & List) ────
  Widget _classCardMorph(
    BuildContext context,
    Pal p,
    ClassModel cls,
    int colorIndex, {
    required bool isList,
  }) {
    final avatarInfo = AppTheme.classAvatarInfo(
      cls.name,
      cls.section,
      colorIndex,
    );
    final accent = avatarInfo.accent;
    final students = cls.students;
    final topStudent = students.isNotEmpty
        ? students.reduce((a, b) => a.score > b.score ? a : b)
        : null;

    final morphDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: kSpringMs);

    return Dismissible(
      key: Key('morph-${cls.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, cls.displayName),
      onDismissed: (_) {
        ref.read(appProvider.notifier).deleteClass(cls.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.dp),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(isList ? 16.dp : 20.dp),
        ),
        child: Icon(CupertinoIcons.trash, color: Colors.white, size: 20.dp),
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
        builder: (down) => TweenAnimationBuilder<double>(
          tween: Tween(end: isList ? 16.dp : 20.dp),
          duration: morphDuration,
          curve: kSpring,
          builder: (context, radius, child) => GlassSurface(
            radius: radius,
            lit: down,
            card: true,
            child: child!,
          ),
          child: AnimatedPadding(
            duration: morphDuration,
            curve: kSpring,
            padding: isList
                ? EdgeInsets.symmetric(horizontal: 14.dp, vertical: 10.5.dp)
                : EdgeInsets.fromLTRB(16.dp, 13.dp, 8.dp, 13.dp),
            child: AnimatedSize(
              duration: morphDuration,
              curve: kSpring,
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: (kSpringMs * 0.55).round()),
                reverseDuration: Duration(
                  milliseconds: (kSpringMs * 0.22).round(),
                ),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    for (final w in previous)
                      Positioned(left: 0, right: 0, top: 0, child: w),
                    ?current,
                  ],
                ),
                child: KeyedSubtree(
                  key: ValueKey(isList ? 'list-body' : 'cards-body'),
                  child: isList
                      ? _classCardListBody(p, cls, accent, avatarInfo, students)
                      : _classCardCardsBody(
                          context,
                          p,
                          cls,
                          accent,
                          avatarInfo,
                          students,
                          topStudent,
                          colorIndex,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── List View Class Card Body (Clean single-line layout) ──────────
  Widget _classCardListBody(
    Pal p,
    ClassModel cls,
    Color accent,
    ClassAvatarInfo avatarInfo,
    List<StudentModel> students,
  ) {
    return Row(
      children: [
        Container(
          width: 32.dp,
          height: 32.dp,
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
                ? Icon(avatarInfo.icon, size: 14.dp, color: Colors.white)
                : Text(
                    avatarInfo.label ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        SizedBox(width: 12.dp),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  cls.name,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 15.sp,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 5.5.dp,
                    vertical: 1.5.dp,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: p.dark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(6.dp),
                  ),
                  child: Text(
                    cls.section!.length <= 2
                        ? 'Sec ${cls.section}'
                        : cls.section!,
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
        ),
        Text(
          '${students.length} ${students.length == 1 ? "student" : "students"}',
          style: TextStyle(
            color: p.sub,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8.dp),
        Icon(
          CupertinoIcons.chevron_forward,
          size: 14.dp,
          color: p.sub.withValues(alpha: 0.6),
        ),
      ],
    );
  }

  // ── Cards Mode Class Card Body (Two-line typographic Breeze layout) ─
  Widget _classCardCardsBody(
    BuildContext context,
    Pal p,
    ClassModel cls,
    Color accent,
    ClassAvatarInfo avatarInfo,
    List<StudentModel> students,
    StudentModel? topStudent,
    int colorIndex,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
                ? Icon(avatarInfo.icon, size: 20.dp, color: Colors.white)
                : Text(
                    avatarInfo.label!,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: avatarInfo.label!.length > 2 ? 12.5.sp : 15.sp,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
        SizedBox(width: 14.dp),
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
                      if (cls.section != null && cls.section!.isNotEmpty) ...[
                        TextSpan(
                          text: cls.section!.length <= 2
                              ? 'Sec ${cls.section}'
                              : cls.section!,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: '  ·  '),
                      ],
                      TextSpan(
                        text:
                            '${students.length} ${students.length == 1 ? "student" : "students"}',
                      ),
                      if (topStudent != null) ...[
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text: topStudent.score > 0
                              ? 'Top +${topStudent.score}'
                              : (topStudent.score < 0
                                    ? 'Top ${topStudent.score}'
                                    : 'Top 0'),
                          style: TextStyle(
                            color: topStudent.score > 0
                                ? (p.dark ? const Color(0xFF60A5FA) : p.accent)
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showClassOptions(context, cls, colorIndex),
          child: Padding(
            padding: EdgeInsets.all(8.dp),
            child: Icon(CupertinoIcons.ellipsis, size: 20.dp, color: p.sub),
          ),
        ),
      ],
    );
  }

  // ── Grid Class Card ────────────────────────────────────────────────
  Widget _classCardGrid(
    BuildContext context,
    Pal p,
    ClassModel cls,
    int colorIndex,
  ) {
    final avatarInfo = AppTheme.classAvatarInfo(
      cls.name,
      cls.section,
      colorIndex,
    );
    final accent = avatarInfo.accent;
    final students = cls.students;
    final topStudent = students.isNotEmpty
        ? students.reduce((a, b) => a.score > b.score ? a : b)
        : null;

    return GlassPress(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: cls.id)),
        );
      },
      onLongPress: () => _showClassOptions(context, cls, colorIndex),
      label: cls.displayName,
      builder: (down) => GlassSurface(
        radius: 22.dp,
        lit: down,
        card: true,
        padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 8.dp, 12.dp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40.dp,
                  height: 40.dp,
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
                      color: Colors.white.withValues(
                        alpha: p.dark ? 0.20 : 0.35,
                      ),
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
                            size: 17.dp,
                            color: Colors.white,
                          )
                        : Text(
                            avatarInfo.label ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 10.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cls.name,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.dp),
                      Text(
                        [
                          if (cls.section != null && cls.section!.isNotEmpty)
                            'Sec ${cls.section}',
                          '${students.length} ${students.length == 1 ? "student" : "students"}',
                        ].join(' · '),
                        style: TextStyle(
                          color: p.sub,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showClassOptions(context, cls, colorIndex),
                  child: SizedBox(
                    width: 32.dp,
                    height: 32.dp,
                    child: Icon(
                      CupertinoIcons.ellipsis,
                      size: 16.dp,
                      color: p.sub,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Who leads the class, at a glance: the top score, big, and
            // whose it is.
            Padding(
              padding: EdgeInsets.only(left: 2.dp, right: 8.dp),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (topStudent != null) ...[
                    Text(
                      topStudent.score > 0
                          ? '+${topStudent.score}'
                          : '${topStudent.score}',
                      style: TextStyle(
                        color: AppTheme.scoreColor(
                          topStudent.score,
                          dark: p.dark,
                        ),
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 6.dp),
                    Expanded(
                      child: Text(
                        'Top · ${topStudent.name}',
                        style: TextStyle(
                          color: p.sub,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'No students yet',
                        style: TextStyle(
                          color: p.sub,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14.dp,
                    color: p.sub.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Unified Floating Bottom Dock for Wide Displays (Center combined dock) ──
  Widget _desktopDock(Pal p, int classCount, int studentCount) {
    final bottom = MediaQuery.paddingOf(context).bottom + 20.dp;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: GlassSurface(
          radius: 28.dp,
          thick: true,
          padding: EdgeInsets.fromLTRB(16.dp, 6.dp, 6.dp, 6.dp),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
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
              SizedBox(width: 12.dp),
              Container(width: 1, height: 20.dp, color: p.faint),
              SizedBox(width: 10.dp),
              GlassPress(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showClassForm(context, null);
                },
                label: 'Create Class',
                builder: (down) => SizedBox.square(
                  dimension: 40.dp,
                  child: GlassSurface(
                    radius: 20.dp,
                    thick: true,
                    lit: down,
                    gradient: p.accentFill,
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.plus,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating Bottom Dock (Breeze style, responsive on wide & fold displays) ──
  Widget _bottomBar(Pal p, int classCount, int studentCount, int avgScore) {
    final isWide = isWideLayout(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 20.dp;
    final sideOffset = isWide
        ? math.max(
            24.dp,
            (MediaQuery.sizeOf(context).width - 1040.dp) / 2 + 24.dp,
          )
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
    final bottom = MediaQuery.paddingOf(context).bottom + 20.dp;
    final sideOffset = isWide
        ? math.max(
            24.dp,
            (MediaQuery.sizeOf(context).width - 1040.dp) / 2 + 24.dp,
          )
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
              child: Icon(CupertinoIcons.plus, color: Colors.white, size: 22),
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
  // ── Appearance (theme) ───────────────────────────────────────────
  IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => CupertinoIcons.sun_max,
        ThemeMode.dark => CupertinoIcons.moon,
        ThemeMode.system => CupertinoIcons.circle_lefthalf_fill,
      };

  void _showAppearanceSheet(BuildContext context) {
    showGlassSheet(
      context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final p = Pal.of(ctx);
          final current = ref.watch(themeModeProvider);
          Widget option(ThemeMode mode, String title, String hint) {
            final selected = current == mode;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).set(mode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(bottom: 6.dp),
                padding: EdgeInsets.symmetric(
                  horizontal: 12.dp,
                  vertical: 10.dp,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? p.accent.withValues(alpha: p.dark ? 0.18 : 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14.dp),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36.dp,
                      height: 36.dp,
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: p.dark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(10.dp),
                      ),
                      child: Icon(
                        _themeIcon(mode),
                        size: 17.dp,
                        color: p.accent,
                      ),
                    ),
                    SizedBox(width: 12.dp),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            hint,
                            style: TextStyle(color: p.sub, fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 18.dp,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 16.dp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8.dp, 8.dp, 8.dp, 12.dp),
                  child: Text(
                    'Appearance',
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                option(ThemeMode.system, 'System', 'Match the phone'),
                option(ThemeMode.light, 'Light', 'Always light'),
                option(ThemeMode.dark, 'Dark', 'Always dark'),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showClassOptions(BuildContext context, ClassModel cls, int colorIndex) {
    final p = Pal.of(context);
    final avatarInfo = AppTheme.classAvatarInfo(
      cls.name,
      cls.section,
      colorIndex,
    );
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
                          ? Icon(avatarInfo.icon, size: 20.dp, color: accent)
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
    final dangerColor = p.dark
        ? const Color(0xFFFF5449)
        : const Color(0xFFE53935);
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
                        color: dangerColor.withValues(
                          alpha: p.dark ? 0.45 : 0.30,
                        ),
                        width: 0.8.dp,
                      )
                    : null,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18.dp,
                  color: danger ? dangerColor : p.accent,
                ),
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
                            ref
                                .read(appProvider.notifier)
                                .addClass(
                                  ClassModel(
                                    id: DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                    name: nameCtrl.text.trim(),
                                    section: sec.isEmpty ? null : sec,
                                  ),
                                );
                          } else {
                            ref
                                .read(appProvider.notifier)
                                .updateClass(
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: p.sub, fontSize: 15.sp),
                      ),
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
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: p.sub, fontSize: 15.sp),
                      ),
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
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: p.dark ? 0.45 : 0.30),
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

/// A card arriving after a grid/list switch: it rises the last few dp
/// into its slot on a spring, a beat after the card before it (Breeze style).
class _SwapIn extends StatefulWidget {
  const _SwapIn({required this.index, required this.play, required this.child});

  final int index;
  final bool play;
  final Widget child;

  @override
  State<_SwapIn> createState() => _SwapInState();
}

class _SwapInState extends State<_SwapIn> {
  late final bool _play =
      widget.play && !MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    if (!_play) return widget.child;
    final step = 35 * widget.index.clamp(0, 8);
    final total = kSpringMs + step;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(step / total, 1, curve: kSpring),
      child: widget.child,
      builder: (context, v, child) =>
          Transform.translate(offset: Offset(0, 24.dp * (1 - v)), child: child),
    );
  }
}

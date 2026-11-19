import 'dart:ui' show BoxWidthStyle;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_model.dart';
import '../models/student_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../ui/glass_chrome.dart';
import '../ui/glass_surface.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import '../ui/scale.dart';

enum StudentViewMode { cards, list, grid }

class ClassDetailScreen extends ConsumerStatefulWidget {
  final String classId;
  const ClassDetailScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  int _step = 1;
  final _steps = [1, 5, 10];
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _sortBy = 'roll'; // 'roll' | 'name' | 'score'
  bool _sortAscending = true;
  String _scoreFilter = 'all'; // 'all' | 'positive' | 'zero' | 'negative'
  bool _searchOpen = false;
  bool _introPlayed = false;
  StudentViewMode? _userSelectedViewMode;
  bool? _lastGrid;
  DateTime? _swappedAt;

  StudentViewMode _resolvedViewMode(BuildContext context) {
    if (_userSelectedViewMode != null) return _userSelectedViewMode!;
    return isWideLayout(context) ? StudentViewMode.grid : StudentViewMode.cards;
  }

  bool get _hasActiveFilters =>
      _sortBy != 'roll' || !_sortAscending || _scoreFilter != 'all';

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
    ClassModel? cls;
    try {
      cls = classes.firstWhere((c) => c.id == widget.classId);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final p = Pal.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final students = cls.students;
    final sum = students.fold<int>(0, (s, st) => s + st.score);
    final avg = students.isNotEmpty ? sum / students.length : 0.0;
    final avgStr = avg >= 0
        ? '+${avg.toStringAsFixed(avg.truncateToDouble() == avg ? 0 : 1)}'
        : avg.toStringAsFixed(avg.truncateToDouble() == avg ? 0 : 1);

    return GlassScaffold(
      background: const GradientBackground(),
      statusBarStyle: p.dark
          ? GlassStatusBarStyle.light
          : GlassStatusBarStyle.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: top + 2.dp),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1040.dp),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchOpen)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWideLayout(context) ? 24.dp : 16.dp,
                              vertical: 4.dp,
                            ),
                            child: isWideLayout(context)
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      RoundGlassButton(
                                        icon: CupertinoIcons.chevron_back,
                                        size: 44.dp,
                                        onPressed: () => Navigator.pop(context),
                                        semanticLabel: 'Back',
                                      ),
                                      SizedBox(width: 12.dp),
                                      Expanded(
                                        child: Text(
                                          cls.displayName,
                                          style: TextStyle(
                                            color: p.ink,
                                            fontSize: 18.5.sp,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (students.isNotEmpty) ...[
                                        SizedBox(width: 10.dp),
                                        _controlsStrip(p),
                                      ],
                                      SizedBox(width: 10.dp),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 320.dp,
                                        ),
                                        child: SpringIn(
                                          key: const ValueKey(
                                            'detail-search-wide',
                                          ),
                                          from: Offset(10.dp, 0),
                                          child: _searchField(p),
                                        ),
                                      ),
                                    ],
                                  )
                                : SpringIn(
                                    key: const ValueKey('detail-search'),
                                    from: Offset(0, -6.dp),
                                    child: _searchField(p),
                                  ),
                          )
                        else
                          _header(p, cls, avgStr),
                        // ── Controls Strip (Step selector + Filter indicator) - only separate row on mobile ──
                        if (students.isNotEmpty && !isWideLayout(context)) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.dp,
                              12.dp,
                              16.dp,
                              8.dp,
                            ),
                            child: _controlsStrip(p),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ── Student List or Empty State ──
                Expanded(
                  child: students.isEmpty
                      ? _buildEmptyState(context, cls)
                      : _buildStudentList(context, cls),
                ),
              ],
            ),
          ),
          // ── Floating bottom dock & FAB (Prism/Breeze style, responsive on fold, tab & mobile) ──
          if (students.isNotEmpty &&
              (!_searchOpen || MediaQuery.viewInsetsOf(context).bottom == 0))
            SpringIn(
              key: const ValueKey('detail-dock-bar'),
              from: Offset(0, 90.dp),
              child: isWideLayout(context)
                  ? _desktopDock(p, cls, students.length, avgStr)
                  : Stack(
                      children: [
                        _bottomBar(p, students.length, avgStr),
                        _fab(p, cls),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _header(Pal p, ClassModel cls, String avgStr) {
    final isWide = isWideLayout(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 24.dp : 16.dp,
        vertical: 4.dp,
      ),
      child: SizedBox(
        height: 54.dp,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RoundGlassButton(
              icon: CupertinoIcons.chevron_back,
              size: 44.dp,
              onPressed: () => Navigator.pop(context),
              semanticLabel: 'Back',
            ),
            SizedBox(width: 12.dp),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cls.displayName,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 18.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.dp),
                  Text(
                    '${cls.students.length} students  ·  avg $avgStr',
                    style: TextStyle(
                      color: p.sub,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isWide && cls.students.isNotEmpty) ...[
              SizedBox(width: 10.dp),
              _controlsStrip(p),
            ],
            SizedBox(width: 8.dp),
            // Floating tool capsule (Search, Filter, Class Options) - slightly taller
            SizedBox(
              height: 44.dp,
              child: GlassSurface(
                radius: 22.dp,
                thick: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _pillIcon(CupertinoIcons.search, 'Search', () {
                      setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) {
                          _searchCtrl.clear();
                          _query = '';
                        }
                      });
                    }, on: _searchOpen),
                    Container(width: 1, height: 14.dp, color: p.faint),
                    _pillIcon(
                      CupertinoIcons.slider_horizontal_3,
                      'Filter',
                      () => _showFilterSheet(context),
                      on: _hasActiveFilters,
                      badge: _hasActiveFilters,
                    ),
                    Container(width: 1, height: 14.dp, color: p.faint),
                    _pillIcon(
                      CupertinoIcons.ellipsis,
                      'Options',
                      () => _showClassOptions(context, cls),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillIcon(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool on = false,
    bool badge = false,
  }) {
    final p = Pal.of(context);
    return GlassPress(
      onTap: onTap,
      label: label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.dp, vertical: 3.dp),
        child: SizedBox.square(
          dimension: 30.dp,
          child: Stack(
            alignment: Alignment.center,
            children: [
              on
                  ? Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.dp),
                        gradient: p.accentFill,
                      ),
                      child: Center(
                        child: Icon(icon, size: 14.dp, color: Colors.white),
                      ),
                    )
                  : Center(
                      child: Icon(icon, size: 15.dp, color: p.ink),
                    ),
              if (badge && !on)
                Positioned(
                  top: 4.dp,
                  right: 4.dp,
                  child: Container(
                    width: 6.dp,
                    height: 6.dp,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search Field (Breeze pattern with clean cancel, centered hint, smaller icons) ─
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
                  Icon(CupertinoIcons.search, size: 14.dp, color: p.sub),
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
                          hintText: 'Search by name or roll…',
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

  // ── Controls Strip (Step Selector + View Mode Switcher: Cards · List · Grid) ──
  Widget _controlsStrip(Pal p) {
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
            // Step selector tabs (±1, ±5, ±10)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) SizedBox(width: 3.5.dp),
                  _stepTab(_steps[i], p),
                ],
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
                  StudentViewMode.cards,
                  CupertinoIcons.rectangle_grid_1x2,
                  p,
                ),
                SizedBox(width: 3.5.dp),
                _viewModeTab(
                  'List',
                  StudentViewMode.list,
                  CupertinoIcons.list_bullet,
                  p,
                ),
                SizedBox(width: 3.5.dp),
                _viewModeTab(
                  'Grid',
                  StudentViewMode.grid,
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

  Widget _viewModeTab(
    String label,
    StudentViewMode mode,
    IconData icon,
    Pal p,
  ) {
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

  Widget _stepTab(int step, Pal p) {
    final selected = _step == step;
    return Tooltip(
      message: 'Step ±$step',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _step = step);
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
          child: Text(
            '±$step',
            style: TextStyle(
              color: selected ? (p.dark ? Colors.white : p.accent) : p.sub,
              fontSize: 11.5.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ── Unified Floating Bottom Dock for Wide Displays (Center combined dock) ──
  Widget _desktopDock(Pal p, ClassModel cls, int studentCount, String avgStr) {
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
              Icon(CupertinoIcons.person_2, size: 14.dp, color: p.accent),
              SizedBox(width: 6.dp),
              Text(
                '$studentCount ${studentCount == 1 ? "student" : "students"}',
                style: TextStyle(
                  color: p.ink,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8.dp),
              Container(width: 1, height: 12.dp, color: p.faint),
              SizedBox(width: 8.dp),
              Icon(
                CupertinoIcons.chart_bar_alt_fill,
                size: 14.dp,
                color: p.accent,
              ),
              SizedBox(width: 6.dp),
              Text(
                'avg $avgStr',
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
                  _showStudentForm(context, cls, null);
                },
                label: 'Add Student',
                builder: (down) => SizedBox.square(
                  dimension: 40.dp,
                  child: GlassSurface(
                    radius: 20.dp,
                    thick: true,
                    lit: down,
                    gradient: p.accentFill,
                    child: const Center(
                      child: Icon(
                        Icons.person_add_rounded,
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

  // ── Floating Bottom Dock (Breeze style, mobile left dock) ──
  Widget _bottomBar(Pal p, int studentCount, String avgStr) {
    final bottom = MediaQuery.paddingOf(context).bottom + 20.dp;
    return Positioned(
      left: 16.dp,
      bottom: bottom,
      child: GlassSurface(
        radius: 28.dp,
        thick: true,
        padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_2, size: 14.dp, color: p.accent),
            SizedBox(width: 6.dp),
            Text(
              '$studentCount ${studentCount == 1 ? "student" : "students"}',
              style: TextStyle(
                color: p.ink,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8.dp),
            Container(width: 1, height: 12.dp, color: p.faint),
            SizedBox(width: 8.dp),
            Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 14.dp,
              color: p.accent,
            ),
            SizedBox(width: 6.dp),
            Text(
              'avg $avgStr',
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

  // ── Floating Action Button (Mobile right fab) ──
  Widget _fab(Pal p, ClassModel cls) {
    final bottom = MediaQuery.paddingOf(context).bottom + 20.dp;
    return Positioned(
      right: 16.dp,
      bottom: bottom,
      child: GlassPress(
        onTap: () {
          HapticFeedback.lightImpact();
          _showStudentForm(context, cls, null);
        },
        label: 'Add Student',
        builder: (down) => SizedBox.square(
          dimension: 48.dp,
          child: GlassSurface(
            radius: 24.dp,
            thick: true,
            lit: down,
            gradient: p.accentFill,
            child: const Center(
              child: Icon(
                Icons.person_add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Student List ──────────────────────────────────────────────────
  Widget _buildStudentList(BuildContext context, ClassModel cls) {
    var students = [...cls.students];

    // Score filter
    if (_scoreFilter == 'positive') {
      students = students.where((s) => s.score > 0).toList();
    } else if (_scoreFilter == 'zero') {
      students = students.where((s) => s.score == 0).toList();
    } else if (_scoreFilter == 'negative') {
      students = students.where((s) => s.score < 0).toList();
    }

    // Sort
    students.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'score':
          cmp = a.score.compareTo(b.score);
          break;
        default: // 'roll'
          final na = int.tryParse(a.rollNumber);
          final nb = int.tryParse(b.rollNumber);
          cmp = (na != null && nb != null)
              ? na.compareTo(nb)
              : a.rollNumber.compareTo(b.rollNumber);
      }
      return _sortAscending ? cmp : -cmp;
    });

    // Search filter
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      students = students
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.rollNumber.toLowerCase().contains(q),
          )
          .toList();
    }

    final topScore = cls.students.isNotEmpty
        ? cls.students.map((s) => s.score).reduce((a, b) => a > b ? a : b)
        : null;

    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.search,
                size: 38.dp,
                color: Pal.of(context).sub.withValues(alpha: 0.5),
              ),
              SizedBox(height: 12.dp),
              Text(
                _query.isNotEmpty
                    ? 'No students found for "$_query"'
                    : 'No students match active filters',
                style: TextStyle(
                  color: Pal.of(context).ink,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_hasActiveFilters) ...[
                SizedBox(height: 12.dp),
                GlassPress(
                  onTap: () {
                    setState(() {
                      _sortBy = 'roll';
                      _sortAscending = true;
                      _scoreFilter = 'all';
                    });
                  },
                  label: 'Reset Filters',
                  child: GlassSurface(
                    radius: 16.dp,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.dp,
                      vertical: 8.dp,
                    ),
                    child: Text(
                      'Clear Filters',
                      style: TextStyle(
                        color: Pal.of(context).accent,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

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

    final isGrid = viewMode == StudentViewMode.grid;
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
        key: const ValueKey('student-grid-view'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1200.dp),
          child: LayoutBuilder(
            builder: (context, box) {
              // Two columns on a phone, three on a fold or desktop: each card
              // stays wide enough for a long name.
              final columns = (box.maxWidth / 340.dp).floor().clamp(2, 3);
              return GridView.builder(
                padding: pad,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: 116.dp,
                ),
                itemCount: students.length,
                itemBuilder: (ctx, i) {
                  final student = students[i];
                  return KeyedSubtree(
                    key: ValueKey('student-grid-${student.id}'),
                    child: _SwapIn(
                      index: i,
                      play: swapped,
                      child: EntranceIn(
                        index: i,
                        play: !_introPlayed && !_searchOpen,
                        child: _buildStudentGridCard(
                          ctx,
                          student,
                          cls,
                          index: i,
                          isTopScorer:
                              topScore != null &&
                              student.score == topScore &&
                              topScore > 0,
                        ),
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
      final isList = viewMode == StudentViewMode.list;
      if (isWide) {
        final gap = 12.dp;
        const columns = 2;

        content = Center(
          key: ValueKey('student-wide-morph-view-$isList'),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1040.dp),
            child: GridView.builder(
              padding: pad,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: isList ? 58.dp : 76.dp,
              ),
              itemCount: students.length,
              itemBuilder: (ctx, i) {
                final student = students[i];
                return KeyedSubtree(
                  key: ValueKey('student-morph-${student.id}'),
                  child: _SwapIn(
                    index: i,
                    play: swapped,
                    child: EntranceIn(
                      index: i,
                      play: !_introPlayed && !_searchOpen,
                      child: _buildStudentCardMorph(
                        ctx,
                        student,
                        cls,
                        index: i,
                        isTopScorer:
                            topScore != null &&
                            student.score == topScore &&
                            topScore > 0,
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
          key: const ValueKey('student-list-morph-view'),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720.dp),
            child: ListView.builder(
              padding: pad,
              itemCount: students.length,
              itemBuilder: (ctx, i) {
                final student = students[i];
                return KeyedSubtree(
                  key: ValueKey('student-morph-${student.id}'),
                  child: _SwapIn(
                    index: i,
                    play: swapped,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isList ? 8.dp : 10.dp),
                      child: EntranceIn(
                        index: i,
                        play: !_introPlayed && !_searchOpen,
                        child: _buildStudentCardMorph(
                          ctx,
                          student,
                          cls,
                          index: i,
                          isTopScorer:
                              topScore != null &&
                              student.score == topScore &&
                              topScore > 0,
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
      key: ValueKey(isGrid ? 'students-grid-$isWide' : 'students-list-$isWide'),
      child: content,
    );
  }

  // ── Morphing Student Card (Breeze spring morph for Cards & List) ──
  Widget _buildStudentCardMorph(
    BuildContext context,
    StudentModel student,
    ClassModel cls, {
    required int index,
    required bool isTopScorer,
    required bool isList,
  }) {
    final p = Pal.of(context);
    final studentAccent = AppTheme.studentColorFor(student.name, student.id);
    final initials = AppTheme.studentInitials(student.name);
    final scoreColor = AppTheme.scoreColor(student.score, dark: p.dark);
    final scoreStr = student.score > 0
        ? '+${student.score}'
        : '${student.score}';

    final morphDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: kSpringMs);

    return Dismissible(
      key: Key('student-morph-${student.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.dp),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(isList ? 16.dp : 20.dp),
        ),
        child: Icon(CupertinoIcons.trash, color: Colors.white, size: 20.dp),
      ),
      confirmDismiss: (_) => _confirmRemove(context, student.name),
      onDismissed: (_) =>
          ref.read(appProvider.notifier).deleteStudent(cls.id, student.id),
      child: GlassPress(
        onTap: () => _showStudentOptions(context, cls, student),
        onLongPress: () => _showStudentOptions(context, cls, student),
        label: student.name,
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
                ? EdgeInsets.symmetric(horizontal: 14.dp, vertical: 8.5.dp)
                : EdgeInsets.fromLTRB(16.dp, 12.dp, 10.dp, 12.dp),
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
                  key: ValueKey(
                    isList ? 'student-list-body' : 'student-cards-body',
                  ),
                  child: isList
                      ? _studentCardListBody(
                          p,
                          student,
                          cls,
                          studentAccent,
                          initials,
                          scoreColor,
                          scoreStr,
                          isTopScorer,
                        )
                      : _studentCardCardsBody(
                          p,
                          student,
                          cls,
                          studentAccent,
                          initials,
                          scoreColor,
                          scoreStr,
                          isTopScorer,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── List View Student Card Body (Clean single-row compact layout) ─
  Widget _studentCardListBody(
    Pal p,
    StudentModel student,
    ClassModel cls,
    Color studentAccent,
    String initials,
    Color scoreColor,
    String scoreStr,
    bool isTopScorer,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34.dp,
          height: 34.dp,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(studentAccent, Colors.white, 0.22)!,
                Color.lerp(studentAccent, Colors.black, 0.04)!,
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: p.dark ? 0.20 : 0.35),
              width: 0.8.dp,
            ),
            boxShadow: [
              BoxShadow(
                color: studentAccent.withValues(alpha: p.dark ? 0.16 : 0.10),
                blurRadius: 5.dp,
                offset: Offset(0, 1.dp),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: initials.length > 2 ? 10.5.sp : 12.5.sp,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.dp),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  student.name,
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5.sp,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.dp),
              Text(
                '#${student.rollNumber}',
                style: TextStyle(
                  color: studentAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5.sp,
                ),
              ),
              if (isTopScorer && student.score > 0) ...[
                SizedBox(width: 4.dp),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.5.dp,
                    vertical: 1.dp,
                  ),
                  decoration: BoxDecoration(
                    color: studentAccent.withValues(
                      alpha: p.dark ? 0.20 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(4.dp),
                  ),
                  child: Text(
                    'Top',
                    style: TextStyle(
                      color: studentAccent,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 8.dp),
        _stepper(cls, student, size: 26),
      ],
    );
  }

  // ── Cards View Student Card Body (avatar · name · stepper) ─────────
  Widget _studentCardCardsBody(
    Pal p,
    StudentModel student,
    ClassModel cls,
    Color studentAccent,
    String initials,
    Color scoreColor,
    String scoreStr,
    bool isTopScorer,
  ) {
    return Row(
      children: [
        _avatar(p, studentAccent, initials, 44.dp),
        SizedBox(width: 12.dp),
        Expanded(
          child: _nameBlock(
            p,
            student,
            studentAccent,
            isTopScorer,
            nameSize: 16,
          ),
        ),
        SizedBox(width: 8.dp),
        _stepper(cls, student, size: 32),
      ],
    );
  }

  // ── Shared pieces of every student card ─────────────────────────
  Widget _avatar(Pal p, Color accent, String initials, double size) {
    return Container(
      width: size,
      height: size,
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
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * (initials.length > 2 ? 0.28 : 0.33),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  /// Name on top, roll number (and a Top badge) under it.
  Widget _nameBlock(
    Pal p,
    StudentModel student,
    Color accent,
    bool isTopScorer, {
    required double nameSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          student.name,
          style: TextStyle(
            color: p.ink,
            fontWeight: FontWeight.w700,
            fontSize: nameSize.sp,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 3.dp),
        Row(
          children: [
            Text(
              '#${student.rollNumber}',
              style: TextStyle(
                color: p.sub,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (isTopScorer && student.score > 0) ...[
              SizedBox(width: 6.dp),
              _topChip(p, accent),
            ],
          ],
        ),
      ],
    );
  }

  Widget _topChip(Pal p, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.dp, vertical: 1.5.dp),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: p.dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20.dp),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.star_fill, size: 9.dp, color: accent),
          SizedBox(width: 3.dp),
          Text(
            'Top',
            style: TextStyle(
              color: accent,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// The grid card's score: large, tabular, tap to type a new one.
  Widget _bigScore(ClassModel cls, StudentModel student) {
    final p = Pal.of(context);
    final score = student.score;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSetScoreSheet(context, cls.id, student),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: kSpring),
              child: child,
            ),
            child: Text(
              score > 0 ? '+$score' : '$score',
              key: ValueKey('big-score-${student.id}-$score'),
              style: TextStyle(
                color: AppTheme.scoreColor(score, dark: p.dark),
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(width: 4.dp),
          Text(
            'pts',
            style: TextStyle(
              color: p.sub,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(
    ClassModel cls,
    StudentModel student, {
    required double size,
    bool showScore = true,
  }) {
    final notifier = ref.read(appProvider.notifier);
    return _ScoreStepper(
      score: student.score,
      scoreKey: student.id,
      step: _step,
      size: size.dp,
      showScore: showScore,
      onMinus: () => notifier.updateScore(cls.id, student.id, -_step),
      onPlus: () => notifier.updateScore(cls.id, student.id, _step),
      onSet: () => _showSetScoreSheet(context, cls.id, student),
    );
  }

  // ── Grid View Student Card (Vertical card with avatar, name & stepper) ─
  Widget _buildStudentGridCard(
    BuildContext context,
    StudentModel student,
    ClassModel cls, {
    required int index,
    required bool isTopScorer,
  }) {
    final p = Pal.of(context);
    final studentAccent = AppTheme.studentColorFor(student.name, student.id);
    final initials = AppTheme.studentInitials(student.name);

    return Dismissible(
      key: Key('grid-${student.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 18.dp),
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20.dp),
        ),
        child: Icon(CupertinoIcons.trash, color: Colors.white, size: 20.dp),
      ),
      confirmDismiss: (_) => _confirmRemove(context, student.name),
      onDismissed: (_) =>
          ref.read(appProvider.notifier).deleteStudent(cls.id, student.id),
      child: GlassPress(
        onTap: () => _showStudentOptions(context, cls, student),
        onLongPress: () => _showStudentOptions(context, cls, student),
        label: student.name,
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
                  _avatar(p, studentAccent, initials, 40.dp),
                  SizedBox(width: 10.dp),
                  Expanded(
                    child: _nameBlock(
                      p,
                      student,
                      studentAccent,
                      isTopScorer,
                      nameSize: 15,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showStudentOptions(context, cls, student),
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
              // The score is the thing a teacher reads across the room, so
              // it is big and on its own; the − + pair sits beside it.
              Padding(
                padding: EdgeInsets.only(left: 2.dp, right: 6.dp),
                child: Row(
                  children: [
                    Expanded(child: _bigScore(cls, student)),
                    _stepper(cls, student, size: 32, showScore: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Bottom Sheet ───────────────────────────────────────────
  void _showFilterSheet(BuildContext context) {
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: TextStyle(
                      color: p.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18.sp,
                    ),
                  ),
                  if (_hasActiveFilters)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _sortBy = 'roll';
                          _sortAscending = true;
                          _scoreFilter = 'all';
                        });
                        setSheet(() {});
                      },
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: p.accent,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 18.dp),
              Caption('SORT BY'),
              SizedBox(height: 8.dp),
              Wrap(
                spacing: 8.dp,
                children: [
                  _filterChip(
                    context,
                    label: 'Roll Number',
                    selected: _sortBy == 'roll',
                    onTap: () {
                      setState(() => _sortBy = 'roll');
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Name',
                    selected: _sortBy == 'name',
                    onTap: () {
                      setState(() => _sortBy = 'name');
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Score',
                    selected: _sortBy == 'score',
                    onTap: () {
                      setState(() => _sortBy = 'score');
                      setSheet(() {});
                    },
                  ),
                ],
              ),
              SizedBox(height: 14.dp),
              Caption('ORDER'),
              SizedBox(height: 8.dp),
              Wrap(
                spacing: 8.dp,
                children: [
                  _filterChip(
                    context,
                    label: 'Ascending',
                    selected: _sortAscending,
                    onTap: () {
                      setState(() => _sortAscending = true);
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Descending',
                    selected: !_sortAscending,
                    onTap: () {
                      setState(() => _sortAscending = false);
                      setSheet(() {});
                    },
                  ),
                ],
              ),
              SizedBox(height: 14.dp),
              Caption('SCORE STATUS'),
              SizedBox(height: 8.dp),
              Wrap(
                spacing: 8.dp,
                runSpacing: 8.dp,
                children: [
                  _filterChip(
                    context,
                    label: 'All Scores',
                    selected: _scoreFilter == 'all',
                    onTap: () {
                      setState(() => _scoreFilter = 'all');
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Positive (>0)',
                    selected: _scoreFilter == 'positive',
                    onTap: () {
                      setState(() => _scoreFilter = 'positive');
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Zero (0)',
                    selected: _scoreFilter == 'zero',
                    onTap: () {
                      setState(() => _scoreFilter = 'zero');
                      setSheet(() {});
                    },
                  ),
                  _filterChip(
                    context,
                    label: 'Negative (<0)',
                    selected: _scoreFilter == 'negative',
                    onTap: () {
                      setState(() => _scoreFilter = 'negative');
                      setSheet(() {});
                    },
                  ),
                ],
              ),
              SizedBox(height: 22.dp),
              GlassPress(
                onTap: () => Navigator.pop(ctx),
                label: 'Apply',
                child: SizedBox(
                  height: 48.dp,
                  child: GlassSurface(
                    radius: 16.dp,
                    thick: true,
                    gradient: p.accentFill,
                    child: Center(
                      child: Text(
                        'Apply Filters',
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
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final p = Pal.of(context);

    return GlassPress(
      onTap: onTap,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 13.5.dp, vertical: 7.5.dp),
        decoration: BoxDecoration(
          gradient: selected ? p.accentFill : null,
          color: selected
              ? null
              : (p.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20.dp),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.30)
                : (p.dark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.07)),
            width: 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: p.accent.withValues(alpha: p.dark ? 0.40 : 0.28),
                    blurRadius: 8.dp,
                    offset: Offset(0, 2.dp),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                CupertinoIcons.checkmark_alt,
                size: 13.dp,
                color: Colors.white,
              ),
              SizedBox(width: 4.5.dp),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : p.ink,
                fontSize: 13.5.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Student Options Sheet ─────────────────────────────────────────
  void _showStudentOptions(
    BuildContext context,
    ClassModel cls,
    StudentModel student,
  ) {
    final p = Pal.of(context);
    final studentAccent = AppTheme.studentColorFor(student.name, student.id);
    final initials = AppTheme.studentInitials(student.name);
    final scoreStr = student.score > 0
        ? '+${student.score}'
        : '${student.score}';
    final scoreColor = AppTheme.scoreColor(student.score, dark: p.dark);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46.dp,
                  height: 46.dp,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15.dp),
                    color: studentAccent.withValues(
                      alpha: p.dark ? 0.16 : 0.09,
                    ),
                    border: Border.all(
                      color: studentAccent.withValues(
                        alpha: p.dark ? 0.30 : 0.20,
                      ),
                      width: 1.1.dp,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: studentAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5.sp,
                        ),
                      ),
                      Text(
                        'Roll #${student.rollNumber}',
                        style: TextStyle(color: p.sub, fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.dp,
                    vertical: 4.dp,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: p.dark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(12.dp),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: p.dark ? 0.28 : 0.16),
                      width: 0.8.dp,
                    ),
                  ),
                  child: Text(
                    scoreStr,
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.dp),
            const Hairline(),
            _optionTile(
              context,
              icon: CupertinoIcons.number,
              title: 'Set Score Manually',
              color: p.accent,
              onTap: () {
                Navigator.pop(ctx);
                _showSetScoreSheet(context, cls.id, student);
              },
            ),
            _optionTile(
              context,
              icon: CupertinoIcons.pencil,
              title: 'Edit Student Info',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(ctx);
                _showStudentForm(context, cls, student);
              },
            ),
            _optionTile(
              context,
              icon: CupertinoIcons.arrow_counterclockwise,
              title: 'Reset Score to 0',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(ctx);
                _confirmResetStudentScore(context, cls, student);
              },
            ),
            const Hairline(),
            _optionTile(
              context,
              icon: CupertinoIcons.trash,
              title: 'Remove Student',
              color: AppTheme.negative,
              danger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmRemove(context, student.name).then((ok) {
                  if (ok == true) {
                    ref
                        .read(appProvider.notifier)
                        .deleteStudent(cls.id, student.id);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final p = Pal.of(context);
    final dangerColor = p.dark
        ? const Color(0xFFFF5449)
        : const Color(0xFFE53935);
    final effectiveColor = danger ? dangerColor : color;

    return GlassPress(
      onTap: onTap,
      label: title,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.dp, horizontal: 4.dp),
        child: Row(
          children: [
            Container(
              width: 36.dp,
              height: 36.dp,
              decoration: BoxDecoration(
                color: danger
                    ? dangerColor.withValues(alpha: p.dark ? 0.28 : 0.15)
                    : color.withValues(alpha: p.dark ? 0.22 : 0.12),
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
                child: Icon(icon, color: effectiveColor, size: 18.dp),
              ),
            ),
            SizedBox(width: 14.dp),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: danger ? dangerColor : p.ink,
                  fontSize: 15.sp,
                  fontWeight: danger ? FontWeight.w700 : FontWeight.w600,
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

  // ── Manual Score Sheet ────────────────────────────────────────────
  void _showSetScoreSheet(
    BuildContext context,
    String classId,
    StudentModel student,
  ) {
    final ctrl = TextEditingController(text: student.score.toString());
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set Score',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
              ),
            ),
            SizedBox(height: 2.dp),
            Text(
              'For ${student.name} (Roll #${student.rollNumber})',
              style: TextStyle(color: p.sub, fontSize: 13.5.sp),
            ),
            SizedBox(height: 20.dp),
            Pane(
              radius: 18.dp,
              padding: EdgeInsets.symmetric(vertical: 10.dp),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                cursorColor: p.accent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                ),
              ),
            ),
            SizedBox(height: 20.dp),
            GlassPress(
              onTap: () {
                final score = int.tryParse(ctrl.text.trim());
                if (score != null) {
                  ref
                      .read(appProvider.notifier)
                      .setScore(classId, student.id, score);
                  Navigator.pop(ctx);
                }
              },
              label: 'Apply Score',
              child: SizedBox(
                height: 48.dp,
                child: GlassSurface(
                  radius: 16.dp,
                  thick: true,
                  gradient: p.accentFill,
                  child: Center(
                    child: Text(
                      'Apply Score',
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
      ),
    );
  }

  // ── Student Form Sheet ────────────────────────────────────────────
  void _showStudentForm(
    BuildContext context,
    ClassModel cls,
    StudentModel? existing,
  ) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rollCtrl = TextEditingController(text: existing?.rollNumber ?? '');
    final formKey = GlobalKey<FormState>();
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.dp,
                    height: 38.dp,
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.dp),
                    ),
                    child: Center(
                      child: Icon(
                        existing == null
                            ? Icons.person_add_rounded
                            : CupertinoIcons.pencil,
                        color: p.accent,
                        size: 20.dp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.dp),
                  Text(
                    existing == null ? 'Add Student' : 'Edit Student',
                    style: TextStyle(
                      color: p.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 19.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.dp),
              _glassField(
                context,
                ctrl: rollCtrl,
                label: 'ROLL NUMBER',
                hint: 'e.g., 01, 24, A-12',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 14.dp),
              _glassField(
                context,
                ctrl: nameCtrl,
                label: 'FULL NAME',
                hint: 'e.g., Alex Johnson',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 24.dp),
              Row(
                children: [
                  Expanded(
                    child: GlassPress(
                      onTap: () => Navigator.pop(ctx),
                      label: 'Cancel',
                      child: SizedBox(
                        height: 48.dp,
                        child: Pane(
                          radius: 16.dp,
                          padding: EdgeInsets.zero,
                          child: Center(
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
                    ),
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    flex: 2,
                    child: GlassPress(
                      onTap: () {
                        if (formKey.currentState!.validate()) {
                          if (existing == null) {
                            ref
                                .read(appProvider.notifier)
                                .addStudent(
                                  cls.id,
                                  StudentModel(
                                    id: DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                    name: nameCtrl.text.trim(),
                                    rollNumber: rollCtrl.text.trim(),
                                  ),
                                );
                          } else {
                            ref
                                .read(appProvider.notifier)
                                .updateStudent(
                                  cls.id,
                                  existing.copyWith(
                                    name: nameCtrl.text.trim(),
                                    rollNumber: rollCtrl.text.trim(),
                                  ),
                                );
                          }
                          Navigator.pop(ctx);
                        }
                      },
                      label: 'Save Student',
                      child: SizedBox(
                        height: 48.dp,
                        child: GlassSurface(
                          radius: 16.dp,
                          thick: true,
                          gradient: p.accentFill,
                          child: Center(
                            child: Text(
                              existing == null ? 'Add Student' : 'Save Changes',
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
      ),
    );
  }

  Widget _glassField(
    BuildContext context, {
    required TextEditingController ctrl,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption(label),
        SizedBox(height: 6.dp),
        Pane(
          radius: 14.dp,
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 2.dp),
          child: TextFormField(
            controller: ctrl,
            validator: validator,
            style: TextStyle(
              color: p.ink,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: p.accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: p.sub.withValues(alpha: 0.7),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 11.dp),
            ),
          ),
        ),
      ],
    );
  }

  // ── Class Options Sheet ───────────────────────────────────────────
  void _showClassOptions(BuildContext context, ClassModel cls) {
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              cls.displayName,
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
              ),
            ),
            SizedBox(height: 4.dp),
            Text(
              '${cls.students.length} students enrolled',
              style: TextStyle(color: p.sub, fontSize: 13.sp),
            ),
            SizedBox(height: 16.dp),
            const Hairline(),
            _optionTile(
              context,
              icon: CupertinoIcons.pencil,
              title: 'Edit Class Info',
              color: p.accent,
              onTap: () {
                Navigator.pop(ctx);
                _showEditClassForm(context, cls);
              },
            ),
            _optionTile(
              context,
              icon: CupertinoIcons.arrow_counterclockwise,
              title: 'Reset All Scores to 0',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(ctx);
                _confirmResetScores(context, cls);
              },
            ),
            const Hairline(),
            _optionTile(
              context,
              icon: CupertinoIcons.trash,
              title: 'Delete Class',
              color: AppTheme.negative,
              danger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteClass(context, cls);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClassForm(BuildContext context, ClassModel cls) {
    final nameCtrl = TextEditingController(text: cls.name);
    final sectionCtrl = TextEditingController(text: cls.section ?? '');
    final formKey = GlobalKey<FormState>();
    final p = Pal.of(context);

    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Class',
                style: TextStyle(
                  color: p.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 19.sp,
                ),
              ),
              SizedBox(height: 18.dp),
              _glassField(
                context,
                ctrl: nameCtrl,
                label: 'CLASS NAME',
                hint: 'e.g., Grade 10',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: 14.dp),
              _glassField(
                context,
                ctrl: sectionCtrl,
                label: 'SECTION',
                hint: 'e.g., A',
              ),
              SizedBox(height: 24.dp),
              GlassPress(
                onTap: () {
                  if (formKey.currentState!.validate()) {
                    final sec = sectionCtrl.text.trim();
                    ref
                        .read(appProvider.notifier)
                        .updateClass(
                          cls.copyWith(
                            name: nameCtrl.text.trim(),
                            section: sec.isEmpty ? null : sec,
                          ),
                        );
                    Navigator.pop(ctx);
                  }
                },
                label: 'Save Changes',
                child: SizedBox(
                  height: 48.dp,
                  child: GlassSurface(
                    radius: 16.dp,
                    thick: true,
                    gradient: p.accentFill,
                    child: Center(
                      child: Text(
                        'Save Changes',
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
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, ClassModel cls) {
    final p = Pal.of(context);
    return EmptyState(
      icon: CupertinoIcons.person_2,
      title: 'No Students Enrolled',
      hint:
          'Add students to ${cls.displayName} to start\nrecording points and calculating scores.',
      action: GlassPress(
        onTap: () => _showStudentForm(context, cls, null),
        label: 'Add First Student',
        child: SizedBox(
          height: 38.dp,
          child: GlassSurface(
            radius: 19.dp,
            thick: true,
            gradient: p.accentFill,
            padding: EdgeInsets.symmetric(horizontal: 16.dp),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_add,
                  color: Colors.white,
                  size: 16.dp,
                ),
                SizedBox(width: 7.dp),
                Text(
                  'Add Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirmation Sheets ───────────────────────────────────────────
  void _confirmResetStudentScore(
    BuildContext context,
    ClassModel cls,
    StudentModel student,
  ) {
    final p = Pal.of(context);
    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset Score',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'Reset ${student.name}\'s score back to 0?',
              style: TextStyle(color: p.sub, fontSize: 13.5.sp),
            ),
            SizedBox(height: 22.dp),
            Row(
              children: [
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx),
                    label: 'Cancel',
                    child: SizedBox(
                      height: 48.dp,
                      child: Pane(
                        radius: 16.dp,
                        padding: EdgeInsets.zero,
                        child: Center(
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
                  ),
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  flex: 2,
                  child: GlassPress(
                    onTap: () {
                      ref
                          .read(appProvider.notifier)
                          .setScore(cls.id, student.id, 0);
                      Navigator.pop(ctx);
                    },
                    label: 'Reset',
                    child: SizedBox(
                      height: 48.dp,
                      child: GlassSurface(
                        radius: 16.dp,
                        thick: true,
                        tint: const Color(0xFFF59E0B),
                        child: Center(
                          child: Text(
                            'Reset Score',
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

  void _confirmResetScores(BuildContext context, ClassModel cls) {
    final p = Pal.of(context);
    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset All Scores',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'Set all scores in ${cls.displayName} to 0? This cannot be undone.',
              style: TextStyle(color: p.sub, fontSize: 13.5.sp),
            ),
            SizedBox(height: 22.dp),
            Row(
              children: [
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx),
                    label: 'Cancel',
                    child: SizedBox(
                      height: 48.dp,
                      child: Pane(
                        radius: 16.dp,
                        padding: EdgeInsets.zero,
                        child: Center(
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
                  ),
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  flex: 2,
                  child: GlassPress(
                    onTap: () {
                      ref.read(appProvider.notifier).resetScores(cls.id);
                      Navigator.pop(ctx);
                    },
                    label: 'Reset All',
                    child: SizedBox(
                      height: 48.dp,
                      child: GlassSurface(
                        radius: 16.dp,
                        thick: true,
                        tint: const Color(0xFFF59E0B),
                        child: Center(
                          child: Text(
                            'Reset All Scores',
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

  void _confirmDeleteClass(BuildContext context, ClassModel cls) {
    final p = Pal.of(context);
    showGlassSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete Class',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'Permanently delete "${cls.displayName}" and all its student scores?',
              style: TextStyle(color: p.sub, fontSize: 13.5.sp),
            ),
            SizedBox(height: 22.dp),
            Row(
              children: [
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx),
                    label: 'Cancel',
                    child: SizedBox(
                      height: 48.dp,
                      child: Pane(
                        radius: 16.dp,
                        padding: EdgeInsets.zero,
                        child: Center(
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
                  ),
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  flex: 2,
                  child: GlassPress(
                    onTap: () {
                      ref.read(appProvider.notifier).deleteClass(cls.id);
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    label: 'Delete',
                    child: Container(
                      height: 48.dp,
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
                        borderRadius: BorderRadius.circular(16.dp),
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
                          'Delete Class',
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

  Future<bool?> _confirmRemove(BuildContext context, String name) {
    final p = Pal.of(context);
    return showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.dp, vertical: 14.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Remove Student',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w800,
                fontSize: 19.sp,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'Remove "$name" from this class?',
              style: TextStyle(color: p.sub, fontSize: 13.5.sp),
            ),
            SizedBox(height: 22.dp),
            Row(
              children: [
                Expanded(
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx, false),
                    label: 'Cancel',
                    child: SizedBox(
                      height: 48.dp,
                      child: Pane(
                        radius: 16.dp,
                        padding: EdgeInsets.zero,
                        child: Center(
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
                  ),
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  flex: 2,
                  child: GlassPress(
                    onTap: () => Navigator.pop(ctx, true),
                    label: 'Remove',
                    child: Container(
                      height: 48.dp,
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
                        borderRadius: BorderRadius.circular(16.dp),
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
                          'Remove',
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

/// The − score + control on every student card: one slim capsule, a quiet
/// minus, an accent plus, and the score in fixed-width digits so it does not
/// jitter as it changes. Tap the score to type one.
class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.score,
    required this.scoreKey,
    required this.step,
    required this.size,
    required this.onMinus,
    required this.onPlus,
    required this.onSet,
    this.showScore = true,
  });

  final int score;
  final String scoreKey;
  final int step;
  final double size;
  final bool showScore;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final inset = size * 0.1;
    final scoreStr = score > 0 ? '+$score' : '$score';

    final scoreText = GestureDetector(
      onTap: onSet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(minWidth: size * 1.45),
        padding: EdgeInsets.symmetric(horizontal: size * 0.16),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: kSpring),
            child: child,
          ),
          child: Text(
            scoreStr,
            key: ValueKey('score-$scoreKey-$score'),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: AppTheme.scoreColor(score, dark: p.dark),
              fontWeight: FontWeight.w800,
              fontSize: size * 0.5,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );

    return Container(
      height: size + inset * 2,
      padding: EdgeInsets.all(inset),
      decoration: ShapeDecoration(
        color: p.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035),
        shape: StadiumBorder(
          side: BorderSide(
            color: p.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(p, plus: false),
          if (showScore) scoreText else SizedBox(width: inset * 2),
          _button(p, plus: true),
        ],
      ),
    );
  }

  Widget _button(Pal p, {required bool plus}) {
    return GlassPress(
      onTap: plus ? onPlus : onMinus,
      label: plus ? 'Add $step' : 'Subtract $step',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: plus ? p.accentFill : null,
          color: plus
              ? null
              : (p.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.95)),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: plus ? (p.dark ? 0.22 : 0.40) : (p.dark ? 0.10 : 0.7),
            ),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: plus
                  ? p.accent.withValues(alpha: p.dark ? 0.30 : 0.22)
                  : Colors.black.withValues(alpha: p.dark ? 0.20 : 0.06),
              blurRadius: size * 0.14,
              offset: Offset(0, size * 0.04),
            ),
          ],
        ),
        child: Icon(
          plus ? CupertinoIcons.plus : CupertinoIcons.minus,
          size: size * 0.44,
          color: plus ? Colors.white : p.ink,
        ),
      ),
    );
  }
}

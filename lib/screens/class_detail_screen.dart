import 'dart:math' as math;
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

  bool get _hasActiveFilters =>
      _sortBy != 'roll' || !_sortAscending || _scoreFilter != 'all';

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
      statusBarStyle: p.dark ? GlassStatusBarStyle.light : GlassStatusBarStyle.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: top + 10.dp),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1400.dp),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchOpen)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWideLayout(context) ? 24.dp : 16.dp,
                              vertical: 4.dp,
                            ),
                            child: SpringIn(
                              key: const ValueKey('detail-search'),
                              from: Offset(0, -10.dp),
                              child: _searchField(p),
                            ),
                          )
                        else
                          _header(p, cls, avgStr),
                        // ── Controls Strip (Step selector + Filter indicator) ──
                        if (students.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              isWideLayout(context) ? 24.dp : 16.dp,
                              12.dp,
                              isWideLayout(context) ? 24.dp : 16.dp,
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
          // ── Floating Action Button (Add Student) ──
          if (students.isNotEmpty &&
              (!_searchOpen || MediaQuery.viewInsetsOf(context).bottom == 0))
            Positioned(
              right: isWideLayout(context)
                  ? math.max(24.dp, (MediaQuery.sizeOf(context).width - 1400.dp) / 2 + 24.dp)
                  : 16.dp,
              bottom: MediaQuery.paddingOf(context).bottom + 14.dp,
              child: SpringIn(
                key: const ValueKey('detail-fab'),
                from: Offset(0, 90.dp),
                child: _fab(p, cls),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _header(Pal p, ClassModel cls, String avgStr) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 4.dp),
      child: SizedBox(
        height: 52.dp,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RoundGlassButton(
              icon: CupertinoIcons.chevron_back,
              size: 42.dp,
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
            SizedBox(width: 8.dp),
            // Floating tool capsule (Search, Filter, Class Options) - compact
            GlassSurface(
              radius: 20.dp,
              thick: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pillIcon(
                    CupertinoIcons.search,
                    'Search',
                    () {
                      setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) {
                          _searchCtrl.clear();
                          _query = '';
                        }
                      });
                    },
                    on: _searchOpen,
                  ),
                  Container(
                    width: 1,
                    height: 14.dp,
                    color: p.faint,
                  ),
                  _pillIcon(
                    CupertinoIcons.slider_horizontal_3,
                    'Filter',
                    () => _showFilterSheet(context),
                    on: _hasActiveFilters,
                    badge: _hasActiveFilters,
                  ),
                  Container(
                    width: 1,
                    height: 14.dp,
                    color: p.faint,
                  ),
                  _pillIcon(
                    CupertinoIcons.ellipsis,
                    'Options',
                    () => _showClassOptions(context, cls),
                  ),
                ],
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
        padding: EdgeInsets.all(3.dp),
        child: SizedBox.square(
          dimension: 28.dp,
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

  // ── Search Field (Breeze pattern with clean cancel) ───────────────
  Widget _searchField(Pal p) {
    return SizedBox(
      height: 44.dp,
      child: Row(
        children: [
          Expanded(
            child: GlassSurface(
              radius: 22.dp,
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
                      magnifierConfiguration:
                          TextMagnifierConfiguration.disabled,
                      cursorColor: p.accent,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: p.ink, fontSize: 15.sp),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11.dp),
                        border: InputBorder.none,
                        hintText: 'Search by name or roll…',
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
          ),
          SizedBox(width: 8.dp),
          RoundGlassButton(
            icon: CupertinoIcons.xmark,
            size: 38.dp,
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

  // ── Controls Strip (Step Selector + Filter Pills - Identical Height & Roundness to Home Top Bar) ──
  Widget _controlsStrip(Pal p) {
    return GlassSurface(
      radius: 20.dp,
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 9.dp),
      child: Row(
        children: [
          // Step selector tabs (±1, ±5, ±10 - same roundness as home top bar options)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0) SizedBox(width: 4.dp),
                _stepTab(_steps[i], p),
              ],
            ],
          ),
          const Spacer(),
          // Vertical divider & Filter Status / Quick Action
          if (_hasActiveFilters) ...[
            Container(
              width: 1.dp,
              height: 16.dp,
              color: p.faint,
              margin: EdgeInsets.symmetric(horizontal: 5.dp),
            ),
            _clearFilterTab(p),
          ] else ...[
            GestureDetector(
              onTap: () => _showFilterSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 13.dp,
                    color: p.sub,
                  ),
                  SizedBox(width: 4.dp),
                  Text(
                    _sortBy == 'score'
                        ? 'By Score'
                        : (_sortBy == 'name' ? 'By Name' : 'Roll Order'),
                    style: TextStyle(
                      color: p.sub,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepTab(int step, Pal p) {
    final selected = _step == step;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _step = step);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 11.dp, vertical: 5.5.dp),
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
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _clearFilterTab(Pal p) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _sortBy = 'roll';
          _sortAscending = true;
          _scoreFilter = 'all';
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 9.dp, vertical: 5.5.dp),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: p.dark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10.dp),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _filterSummaryLabel(),
              style: TextStyle(
                color: p.accent,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.dp),
            Icon(
              CupertinoIcons.xmark,
              size: 11.dp,
              color: p.accent,
            ),
          ],
        ),
      ),
    );
  }

  String _filterSummaryLabel() {
    if (_scoreFilter != 'all') {
      return _scoreFilter == 'positive'
          ? '>0'
          : (_scoreFilter == 'negative' ? '<0' : '=0');
    }
    if (_sortBy != 'roll') {
      return _sortBy == 'score' ? 'Score' : 'Name';
    }
    return 'Filter';
  }

  // ── Floating Action Button (compact & sleek) ──────────────────────
  Widget _fab(Pal p, ClassModel cls) {
    return GlassPress(
      onTap: () => _showStudentForm(context, cls, null),
      label: 'Add Student',
      builder: (down) => SizedBox.square(
        dimension: 48.dp,
        child: GlassSurface(
          radius: 24.dp,
          thick: true,
          lit: down,
          gradient: p.accentFill,
          child: Center(
            child: Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 22.dp,
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
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.rollNumber.toLowerCase().contains(q))
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
                        horizontal: 16.dp, vertical: 8.dp),
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

    final isWide = isWideLayout(context);
    final pad = EdgeInsets.fromLTRB(
      isWide ? 24.dp : 16.dp,
      4.dp,
      isWide ? 24.dp : 16.dp,
      MediaQuery.paddingOf(context).bottom + 84.dp,
    );

    if (isWide) {
      final gap = 12.dp;
      final room = math.min(MediaQuery.sizeOf(context).width, 1400.dp) -
          pad.horizontal;
      const minColumn = 380.0;
      final columns = ((room + gap) / (minColumn + gap)).floor().clamp(1, 4);

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1400.dp),
          child: GridView.builder(
            padding: pad,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: 82.dp,
            ),
            itemCount: students.length,
            itemBuilder: (ctx, i) => EntranceIn(
              index: i,
              child: _buildStudentCard(
                ctx,
                students[i],
                cls,
                index: i,
                isTopScorer:
                    topScore != null && students[i].score == topScore && topScore > 0,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720.dp),
        child: ListView.builder(
          padding: pad,
          itemCount: students.length,
          itemBuilder: (ctx, i) => EntranceIn(
            index: i,
            child: _buildStudentCard(
              ctx,
              students[i],
              cls,
              index: i,
              isTopScorer:
                  topScore != null && students[i].score == topScore && topScore > 0,
            ),
          ),
        ),
      ),
    );
  }

  // ── Pure Liquid Frosted Student Card ──────────────────────────────
  Widget _buildStudentCard(
    BuildContext context,
    StudentModel student,
    ClassModel cls, {
    required int index,
    required bool isTopScorer,
  }) {
    final p = Pal.of(context);
    final studentAccent = AppTheme.studentColorFor(student.name, student.id);
    final initials = AppTheme.studentInitials(student.name);
    final scoreColor = AppTheme.scoreColor(student.score, dark: p.dark);
    final scoreStr =
        student.score > 0 ? '+${student.score}' : '${student.score}';

    return Padding(
      padding: EdgeInsets.only(bottom: 12.dp),
      child: Dismissible(
        key: Key(student.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 22.dp),
          decoration: BoxDecoration(
            color: const Color(0xFFE5484D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20.dp),
          ),
          child: Icon(
            CupertinoIcons.trash,
            color: Colors.white,
            size: 22.dp,
          ),
        ),
        confirmDismiss: (_) => _confirmRemove(context, student.name),
        onDismissed: (_) => ref
            .read(appProvider.notifier)
            .deleteStudent(cls.id, student.id),
        child: GlassPress(
          onTap: () => _showStudentOptions(context, cls, student),
          onLongPress: () => _showStudentOptions(context, cls, student),
          label: student.name,
          builder: (down) => GlassSurface(
            radius: 20.dp,
            lit: down,
            padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 10.dp, 12.dp),
            child: Row(
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
                        Color.lerp(studentAccent, Colors.white, 0.22)!,
                        Color.lerp(studentAccent, Colors.black, 0.04)!,
                      ],
                    ),
                    border: Border.all(
                      color:
                          Colors.white.withValues(alpha: p.dark ? 0.20 : 0.35),
                      width: 0.8.dp,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: studentAccent.withValues(alpha: p.dark ? 0.16 : 0.10),
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
                        fontSize: initials.length > 2 ? 12.sp : 14.5.sp,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 13.dp),
                // Student Name and Details (Breeze typographic hierarchy)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.dp),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '#${student.rollNumber}',
                              style: TextStyle(
                                color: studentAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: '  ·  ',
                              style: TextStyle(
                                color: p.sub.withValues(alpha: 0.5),
                              ),
                            ),
                            TextSpan(
                              text: student.score > 0
                                  ? '+${student.score} pts'
                                  : (student.score < 0
                                      ? '${student.score} pts'
                                      : '0 pts'),
                              style: TextStyle(
                                color: student.score > 0
                                    ? (p.dark
                                        ? const Color(0xFF60A5FA)
                                        : p.accent)
                                    : (student.score < 0
                                        ? (p.dark
                                            ? const Color(0xFFF87171)
                                            : const Color(0xFFDC2626))
                                        : p.sub),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isTopScorer && student.score > 0) ...[
                              TextSpan(
                                text: '  ·  ',
                                style: TextStyle(
                                  color: p.sub.withValues(alpha: 0.5),
                                ),
                              ),
                              TextSpan(
                                text: 'Top',
                                style: TextStyle(
                                  color: studentAccent,
                                  fontWeight: FontWeight.w700,
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
                SizedBox(width: 8.dp),
                  // Tactile High-Contrast Stepper Capsule: [ - ]  Score  [ + ]
                  Container(
                    decoration: BoxDecoration(
                      color: p.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18.dp),
                      border: Border.all(
                        color: p.dark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 0.8.dp,
                      ),
                    ),
                    padding: EdgeInsets.all(2.5.dp),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus Button
                        GlassPress(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(appProvider.notifier).updateScore(
                                  cls.id,
                                  student.id,
                                  -_step,
                                );
                          },
                          label: 'Subtract $_step score',
                          child: Container(
                            width: 32.dp,
                            height: 32.dp,
                            decoration: BoxDecoration(
                              color: p.dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.90),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: p.dark ? 0.25 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: p.dark ? 0.15 : 0.6),
                                width: 0.8.dp,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.minus,
                                size: 14.dp,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ),
                        // Score pill (tap to manually set)
                        GestureDetector(
                          onTap: () => _showSetScoreSheet(
                            context,
                            cls.id,
                            student,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            constraints: BoxConstraints(minWidth: 42.dp),
                            padding: EdgeInsets.symmetric(horizontal: 5.dp),
                            alignment: Alignment.center,
                            child: Text(
                              scoreStr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.sp,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                        // Plus Button
                        GlassPress(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(appProvider.notifier).updateScore(
                                  cls.id,
                                  student.id,
                                  _step,
                                );
                          },
                          label: 'Add $_step score',
                          child: Container(
                            width: 32.dp,
                            height: 32.dp,
                            decoration: BoxDecoration(
                              gradient: p.accentFill,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: p.dark ? 0.20 : 0.40),
                                width: 0.8.dp,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: p.dark ? 0.30 : 0.20),
                                  blurRadius: 5.dp,
                                  offset: Offset(0, 1.5.dp),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.plus,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final scoreStr =
        student.score > 0 ? '+${student.score}' : '${student.score}';
    final scoreColor = AppTheme.scoreColor(student.score, dark: p.dark);
    final scoreBg = AppTheme.scoreBg(student.score, dark: p.dark);

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
                        alpha: p.dark ? 0.16 : 0.09),
                    border: Border.all(
                      color: studentAccent.withValues(
                          alpha: p.dark ? 0.30 : 0.20),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.dp, vertical: 4.dp),
                  decoration: BoxDecoration(
                    color: scoreBg,
                    borderRadius: BorderRadius.circular(8.dp),
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
    final dangerColor =
        p.dark ? const Color(0xFFFF5449) : const Color(0xFFE53935);
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
                        color:
                            dangerColor.withValues(alpha: p.dark ? 0.45 : 0.30),
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
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
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
                            ref.read(appProvider.notifier).addStudent(
                                  cls.id,
                                  StudentModel(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    name: nameCtrl.text.trim(),
                                    rollNumber: rollCtrl.text.trim(),
                                  ),
                                );
                          } else {
                            ref.read(appProvider.notifier).updateStudent(
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
                    ref.read(appProvider.notifier).updateClass(
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
      hint: 'Add students to ${cls.displayName} to start\nrecording points and calculating scores.',
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
                Icon(CupertinoIcons.person_add, color: Colors.white, size: 16.dp),
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
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: p.dark ? 0.45 : 0.30),
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
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: p.dark ? 0.45 : 0.30),
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

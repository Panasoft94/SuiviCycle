import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../utils/widgets.dart';
import '../stats/stats_screen.dart';

// ═══════════════════════════════════════
// CYCLE HISTORY SCREEN
// ═══════════════════════════════════════

class CycleHistoryScreen extends StatefulWidget {
  const CycleHistoryScreen({super.key});

  @override
  State<CycleHistoryScreen> createState() => _CycleHistoryScreenState();
}

enum _CycleFilter { all, ongoing, completed }

class _CycleHistoryScreenState extends State<CycleHistoryScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_HistoryData> _dataFuture;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  _CycleFilter _activeFilter = _CycleFilter.all;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchHistoryData();
    });
  }

  Future<_HistoryData> _fetchHistoryData() async {
    final cycles = await _dbHelper.getCycles();
    final avgLength = await _dbHelper.getAverageCycleLength();
    final completed =
        cycles.where((c) => c.cycleLength != null && c.cycleLength! > 0).length;
    final ongoing = cycles.where((c) => c.endDate == null).length;

    return _HistoryData(
      cycles: cycles,
      avgCycleLength: avgLength,
      completedCount: completed,
      ongoingCount: ongoing,
    );
  }

  List<Cycle> _filteredCycles(List<Cycle> cycles) {
    switch (_activeFilter) {
      case _CycleFilter.ongoing:
        return cycles.where((c) => c.endDate == null).toList();
      case _CycleFilter.completed:
        return cycles.where((c) => c.endDate != null).toList();
      case _CycleFilter.all:
        return cycles;
    }
  }

  Map<String, List<Cycle>> _groupCycles(List<Cycle> cycles) {
    final Map<String, List<Cycle>> grouped = {};
    for (final cycle in cycles) {
      final key = DateFormat('MMMM yyyy', 'fr_FR').format(cycle.startDate);
      grouped.putIfAbsent(key, () => []).add(cycle);
    }
    return grouped;
  }

  Future<void> _onRefresh() async {
    final data = await _fetchHistoryData();
    setState(() {
      _dataFuture = Future.value(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<_HistoryData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(cs),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: cs.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement...',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data;
          if (data == null || data.cycles.isEmpty) {
            return _buildEmptyState(cs);
          }

          return _buildContent(data, cs);
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════

  SliverAppBar _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      leading: const AppBackButton(),
      title: const Text('Historique',
          style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
          ),
          tooltip: 'Statistiques',
          onPressed: () {
            Navigator.push(context, slideTransition(const StatsScreen()));
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ═══════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════

  Widget _buildEmptyState(ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(cs),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primaryContainer.withAlpha(60),
                            cs.primaryContainer.withAlpha(30),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withAlpha(20),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          size: 56, color: cs.primary.withAlpha(180)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Aucun cycle enregistré',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Commencez à suivre vos cycles depuis l\'écran principal pour les retrouver ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: cs.primary.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Tirez vers le bas pour rafraîchir',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
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
      ],
    );
  }

  // ═══════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════

  Widget _buildContent(_HistoryData data, ColorScheme cs) {
    final filtered = _filteredCycles(data.cycles);
    final grouped = _groupCycles(filtered);

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _onRefresh,
      color: cs.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(cs),

          // ── Summary Cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _buildSummaryRow(data, cs),
            ),
          ),

          // ── Filter Chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _buildFilterChips(data, cs),
            ),
          ),

          // ── Grouped Cycle List ──
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                child: Column(
                  children: [
                    Icon(Icons.filter_list_off_rounded,
                        size: 40, color: cs.outline.withAlpha(120)),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun cycle pour ce filtre',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._buildGroupedList(grouped, cs),

          // ── Bottom Padding ──
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════

  Widget _buildFilterChips(_HistoryData data, ColorScheme cs) {
    return Row(
      children: [
        _filterChip(
          label: 'Tous',
          count: data.cycles.length,
          isSelected: _activeFilter == _CycleFilter.all,
          color: cs.primary,
          cs: cs,
          onTap: () => setState(() => _activeFilter = _CycleFilter.all),
        ),
        const SizedBox(width: 8),
        _filterChip(
          label: 'En cours',
          count: data.ongoingCount,
          isSelected: _activeFilter == _CycleFilter.ongoing,
          color: const Color(0xFFFFCA28),
          cs: cs,
          onTap: () => setState(() => _activeFilter = _CycleFilter.ongoing),
        ),
        const SizedBox(width: 8),
        _filterChip(
          label: 'Terminés',
          count: data.completedCount,
          isSelected: _activeFilter == _CycleFilter.completed,
          color: const Color(0xFF66BB6A),
          cs: cs,
          onTap: () => setState(() => _activeFilter = _CycleFilter.completed),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color.withAlpha(100) : cs.outlineVariant.withAlpha(60),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(30) : cs.outlineVariant.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // SUMMARY ROW
  // ═══════════════════════════════════════

  Widget _buildSummaryRow(_HistoryData data, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            Icons.sync_rounded,
            'Cycle moy.',
            data.avgCycleLength != null
                ? '${data.avgCycleLength!.round()}j'
                : '--',
            const Color(0xFF42A5F5),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            Icons.check_circle_outline_rounded,
            'Terminés',
            '${data.completedCount}',
            const Color(0xFF66BB6A),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            Icons.hourglass_bottom_rounded,
            'En cours',
            '${data.ongoingCount}',
            const Color(0xFFFFCA28),
            cs,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color,
      ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(20), color.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // GROUPED LIST
  // ═══════════════════════════════════════

  List<Widget> _buildGroupedList(
      Map<String, List<Cycle>> grouped, ColorScheme cs) {
    final List<Widget> slivers = [];

    for (final entry in grouped.entries) {
      // ── Section Header ──
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        _capitalize(entry.key),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entry.value.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                      color: cs.outlineVariant.withAlpha(60), thickness: 1),
                ),
              ],
            ),
          ),
        ),
      );

      // ── Cycle Cards ──
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cycle = entry.value[index];
                final isLast = index == entry.value.length - 1;
                return _CycleCard(
                  cycle: cycle,
                  index: index,
                  isLast: isLast,
                  onTap: () => _showCycleDetails(cycle),
                  onDelete: () => _deleteCycle(cycle),
                );
              },
              childCount: entry.value.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  // ═══════════════════════════════════════
  // CYCLE DETAIL BOTTOM SHEET
  // ═══════════════════════════════════════

  void _showCycleDetails(Cycle cycle) {
    final cs = Theme.of(context).colorScheme;
    final isOngoing = cycle.endDate == null;
    final startDate =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(cycle.startDate);
    final daysSinceStart = DateTime.now().difference(cycle.startDate).inDays;

    // Calcul de la durée des règles
    int? periodDays;
    if (cycle.periodEndDate != null) {
      periodDays =
          cycle.periodEndDate!.difference(cycle.startDate).inDays + 1;
    }

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOngoing
                            ? [
                                cs.primary.withAlpha(30),
                                cs.primary.withAlpha(15)
                              ]
                            : [
                                const Color(0xFF66BB6A).withAlpha(30),
                                const Color(0xFF66BB6A).withAlpha(15),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOngoing
                          ? Icons.play_arrow_rounded
                          : Icons.check_circle_rounded,
                      color: isOngoing ? cs.primary : const Color(0xFF66BB6A),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOngoing ? 'Cycle en cours' : 'Cycle terminé',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isOngoing ? cs.primary : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _capitalize(startDate),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Progress bar for ongoing cycles ──
              if (isOngoing && cycle.cycleLength != null) ...[
                _buildCycleProgressBar(cycle, daysSinceStart, cs),
                const SizedBox(height: 16),
              ],

              // ── Details Grid ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: cs.outlineVariant.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      Icons.calendar_today_rounded,
                      'Début',
                      DateFormat('d MMM yyyy', 'fr_FR')
                          .format(cycle.startDate),
                      const Color(0xFF42A5F5),
                      cs,
                    ),
                    _detailDivider(cs),
                    _detailRow(
                      Icons.event_rounded,
                      'Fin',
                      cycle.endDate != null
                          ? DateFormat('d MMM yyyy', 'fr_FR')
                              .format(cycle.endDate!)
                          : 'En cours',
                      cycle.endDate != null
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFFFCA28),
                      cs,
                    ),
                    if (cycle.periodEndDate != null) ...[
                      _detailDivider(cs),
                      _detailRow(
                        Icons.water_drop_rounded,
                        'Règles',
                        '$periodDays jours (fin ${DateFormat('d MMM', 'fr_FR').format(cycle.periodEndDate!)})',
                        const Color(0xFFEF5350),
                        cs,
                      ),
                    ],
                    if (cycle.cycleLength != null) ...[
                      _detailDivider(cs),
                      _detailRow(
                        Icons.straighten_rounded,
                        'Durée du cycle',
                        '${cycle.cycleLength} jours',
                        const Color(0xFFAB47BC),
                        cs,
                      ),
                    ],
                    if (cycle.ovulationDate != null) ...[
                      _detailDivider(cs),
                      _detailRow(
                        Icons.egg_rounded,
                        'Ovulation',
                        DateFormat('d MMM yyyy', 'fr_FR')
                            .format(cycle.ovulationDate!),
                        const Color(0xFFFFCA28),
                        cs,
                      ),
                    ],
                    if (cycle.expectedPeriod != null) ...[
                      _detailDivider(cs),
                      _detailRow(
                        Icons.event_note_rounded,
                        'Prochaines règles',
                        _formatRelativeDate(cycle.expectedPeriod!),
                        const Color(0xFFFF7043),
                        cs,
                      ),
                    ],
                    if (cycle.phase != null && cycle.phase!.isNotEmpty) ...[
                      _detailDivider(cs),
                      _detailRow(
                        Icons.auto_awesome_rounded,
                        'Phase actuelle',
                        cycle.phase!,
                        const Color(0xFFEC407A),
                        cs,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Duration info bar ──
              if (isOngoing) _ongoingInfoBar(cycle, cs),

              const SizedBox(height: 12),

              // ── Delete button ──
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteCycle(cycle);
                  },
                  icon:
                      const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Supprimer ce cycle'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.error.withAlpha(40)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Cycle Progress Bar (bottom sheet) ──

  Widget _buildCycleProgressBar(
      Cycle cycle, int daysSinceStart, ColorScheme cs) {
    final expectedLength = cycle.cycleLength ?? 28;
    final progress = (daysSinceStart / expectedLength).clamp(0.0, 1.0);
    final remaining = (expectedLength - daysSinceStart).clamp(0, expectedLength);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression du cycle',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: cs.primary),
              ),
              Text(
                '$remaining jours restants',
                style: TextStyle(
                    fontSize: 12, color: cs.primary.withAlpha(180)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.primary.withAlpha(25),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jour $daysSinceStart',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
              Text('Cycle de $expectedLength jours',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ongoingInfoBar(Cycle cycle, ColorScheme cs) {
    final daysSinceStart =
        DateTime.now().difference(cycle.startDate).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jour $daysSinceStart du cycle en cours',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color,
      ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider(ColorScheme cs) {
    return Divider(
        height: 1, color: cs.outlineVariant.withAlpha(40), indent: 42);
  }

  // ═══════════════════════════════════════
  // DELETE CYCLE
  // ═══════════════════════════════════════

  void _deleteCycle(Cycle cycle) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_forever_rounded,
                color: Colors.red, size: 28),
          ),
          title: const Text('Supprimer ce cycle ?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Cette action est irréversible. Toutes les données associées à ce cycle seront définitivement supprimées.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await _dbHelper.deleteCycle(cycle.id!);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text('Cycle supprimé avec succès'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    final formatted = DateFormat('d MMM', 'fr_FR').format(date);
    if (diff == 0) return '$formatted (aujourd\'hui)';
    if (diff == 1) return '$formatted (demain)';
    if (diff == -1) return '$formatted (hier)';
    if (diff > 0 && diff <= 7) return '$formatted (dans $diff j)';
    if (diff < 0 && diff >= -7) return '$formatted (il y a ${-diff} j)';
    return formatted;
  }
}

// ═══════════════════════════════════════════════════
// CYCLE CARD WIDGET (avec animations améliorées)
// ═══════════════════════════════════════════════════

class _CycleCard extends StatefulWidget {
  final Cycle cycle;
  final int index;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CycleCard({
    required this.cycle,
    required this.index,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_CycleCard> createState() => _CycleCardState();
}

class _CycleCardState extends State<_CycleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animController, curve: Curves.easeOutCubic));

    Future.delayed(
        Duration(milliseconds: 70 * widget.index.clamp(0, 8)), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cycle = widget.cycle;
    final isOngoing = cycle.endDate == null;
    final startDate = DateFormat('d MMM', 'fr_FR').format(cycle.startDate);
    final daysSinceStart =
        DateTime.now().difference(cycle.startDate).inDays;

    String endInfo;
    if (isOngoing) {
      endInfo = cycle.expectedPeriod != null
          ? 'Prévu ${DateFormat('d MMM', 'fr_FR').format(cycle.expectedPeriod!)}'
          : 'Jour $daysSinceStart';
    } else {
      endInfo = DateFormat('d MMM', 'fr_FR').format(cycle.endDate!);
    }

    // Period duration
    int? periodDays;
    if (cycle.periodEndDate != null) {
      periodDays =
          cycle.periodEndDate!.difference(cycle.startDate).inDays + 1;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: ValueKey(cycle.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            widget.onDelete();
            return false;
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withAlpha(5),
                  Colors.red.withAlpha(25),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                const SizedBox(height: 4),
                Text('Supprimer',
                    style: TextStyle(
                        color: Colors.red.withAlpha(200),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isOngoing
                      ? cs.primaryContainer.withAlpha(50)
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOngoing
                        ? cs.primary.withAlpha(80)
                        : cs.outlineVariant.withAlpha(60),
                    width: isOngoing ? 1.5 : 1,
                  ),
                  boxShadow: [
                    if (isOngoing)
                      BoxShadow(
                        color: cs.primary.withAlpha(12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // ── Leading Icon ──
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: isOngoing
                                  ? LinearGradient(
                                      colors: [
                                        cs.primary,
                                        cs.primary.withAlpha(200)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color:
                                  isOngoing ? null : cs.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              boxShadow: isOngoing
                                  ? [
                                      BoxShadow(
                                          color: cs.primary.withAlpha(50),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3))
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              isOngoing
                                  ? Icons.play_arrow_rounded
                                  : Icons.check_rounded,
                              color: isOngoing
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // ── Content ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isOngoing
                                            ? 'Cycle actuel'
                                            : 'Cycle terminé',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isOngoing
                                              ? cs.primary
                                              : cs.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (isOngoing) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withAlpha(26),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'J$daysSinceStart',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 13,
                                        color: cs.onSurfaceVariant
                                            .withAlpha(150)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$startDate → $endInfo',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // ── Tags row ──
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (cycle.cycleLength != null)
                                      _tag(
                                          '${cycle.cycleLength}j',
                                          Icons.straighten_rounded,
                                          const Color(0xFF42A5F5),
                                          cs),
                                    if (periodDays != null)
                                      _tag(
                                          '$periodDays j de règles',
                                          Icons.water_drop_rounded,
                                          const Color(0xFFEF5350),
                                          cs),
                                    if (cycle.ovulationDate != null)
                                      _tag(
                                          'Ovul. ${DateFormat('d MMM', 'fr_FR').format(cycle.ovulationDate!)}',
                                          Icons.egg_rounded,
                                          const Color(0xFFFFCA28),
                                          cs),
                                    if (cycle.phase != null &&
                                        cycle.phase!.isNotEmpty)
                                      _tag(cycle.phase!,
                                          Icons.auto_awesome_rounded,
                                          const Color(0xFFAB47BC), cs),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 4),

                          // ── Trailing ──
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant.withAlpha(120),
                            size: 22,
                          ),
                        ],
                      ),
                    ),

                    // ── Mini progress bar for ongoing cycles ──
                    if (isOngoing) _buildMiniProgress(cycle, daysSinceStart, cs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgress(Cycle cycle, int daysSinceStart, ColorScheme cs) {
    final expectedLength = cycle.cycleLength ?? 28;
    final progress = (daysSinceStart / expectedLength).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: cs.primary.withAlpha(15),
        valueColor: AlwaysStoppedAnimation(cs.primary.withAlpha(150)),
      ),
    );
  }

  Widget _tag(
      String text, IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════

class _HistoryData {
  final List<Cycle> cycles;
  final double? avgCycleLength;
  final int completedCount;
  final int ongoingCount;

  _HistoryData({
    required this.cycles,
    this.avgCycleLength,
    required this.completedCount,
    required this.ongoingCount,
  });
}

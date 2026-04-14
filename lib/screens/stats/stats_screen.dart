import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../models/symptom.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════

class _StatsData {
  final Map<DateTime, int> heatmapData;
  final double? avgCycleLength;
  final double? avgPeriodLength;
  final Map<String, int> moodFrequency;
  final int totalCompletedCycles;
  final int? shortestCycle;
  final int? longestCycle;
  final List<_CycleTrendPoint> cycleTrends;
  final List<_PeriodLengthPoint> periodLengths;
  final double? avgPain;
  final double? avgEnergy;
  final double? avgLibido;
  final int totalSymptoms;
  final List<_Insight> insights;

  _StatsData({
    required this.heatmapData,
    this.avgCycleLength,
    this.avgPeriodLength,
    required this.moodFrequency,
    required this.totalCompletedCycles,
    this.shortestCycle,
    this.longestCycle,
    required this.cycleTrends,
    required this.periodLengths,
    this.avgPain,
    this.avgEnergy,
    this.avgLibido,
    required this.totalSymptoms,
    required this.insights,
  });
}

class _CycleTrendPoint {
  final int index;
  final int length;
  final DateTime startDate;
  _CycleTrendPoint({required this.index, required this.length, required this.startDate});
}

class _PeriodLengthPoint {
  final int index;
  final int days;
  final DateTime startDate;
  _PeriodLengthPoint({required this.index, required this.days, required this.startDate});
}

class _Insight {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  _Insight({required this.icon, required this.title, required this.description, required this.color});
}

// ═══════════════════════════════════════
// STICKY TAB BAR DELEGATE
// ═══════════════════════════════════════

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _StickyTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || backgroundColor != oldDelegate.backgroundColor;
}

// ═══════════════════════════════════════
// MOOD EMOJIS
// ═══════════════════════════════════════

const Map<String, String> _moodEmojis = {
  'Heureuse': '😊',
  'Triste': '😢',
  'Anxieuse': '😰',
  'Irritée': '😤',
  'Calme': '😌',
  'Fatiguée': '😴',
  'Énergique': '⚡',
  'Stressée': '😫',
  'Sensible': '🥺',
  'Normale': '🙂',
};

// ═══════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_StatsData> _statsDataFuture;
  late TabController _tabController;

  static const Map<int, Color> _colorMapping = {
    1: Color(0xFFEF5350),
    2: Color(0xFFFFCA28),
    3: Color(0xFF66BB6A),
    4: Color(0xFF42A5F5),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _statsDataFuture = _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // DATA LOADING (logique existante conservée + extensions)
  // ═══════════════════════════════════════

  Future<_StatsData> _loadAllData() async {
    final cycles = await _dbHelper.getCycles();
    final allSymptoms = await _dbHelper.getAllSymptoms();
    final Map<DateTime, int> heatmapData = {};

    // --- Heatmap (priorités identiques à l'original) ---
    for (final cycle in cycles) {
      if (cycle.ovulationDate != null) {
        final d = cycle.ovulationDate!;
        heatmapData[DateTime(d.year, d.month, d.day)] = 2;
      }
    }
    for (final cycle in cycles) {
      final start = cycle.startDate;
      final end = cycle.periodEndDate ?? start.add(const Duration(days: 4));
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        final d = start.add(Duration(days: i));
        heatmapData.putIfAbsent(DateTime(d.year, d.month, d.day), () => 1);
      }
    }
    for (final cycle in cycles) {
      if (cycle.ovulationDate != null) {
        for (int i = 5; i > 0; i--) {
          final d = cycle.ovulationDate!.subtract(Duration(days: i));
          heatmapData.putIfAbsent(DateTime(d.year, d.month, d.day), () => 3);
        }
      }
    }
    for (final s in allSymptoms) {
      heatmapData.putIfAbsent(DateTime(s.date.year, s.date.month, s.date.day), () => 4);
    }

    // --- Moyennes cycles ---
    final completedCycles = cycles.where((c) => c.cycleLength != null && c.cycleLength! > 0).toList();
    double? avgCycleLength;
    int? shortestCycle, longestCycle;
    if (completedCycles.isNotEmpty) {
      final lengths = completedCycles.map((c) => c.cycleLength!).toList();
      avgCycleLength = lengths.reduce((a, b) => a + b) / lengths.length;
      shortestCycle = lengths.reduce(min);
      longestCycle = lengths.reduce(max);
    }

    // --- Moyennes règles ---
    final periodCycles = cycles.where((c) => c.periodEndDate != null).toList();
    double? avgPeriodLength;
    if (periodCycles.isNotEmpty) {
      avgPeriodLength = periodCycles
              .map((c) => c.periodEndDate!.difference(c.startDate).inDays + 1)
              .reduce((a, b) => a + b) /
          periodCycles.length;
    }

    // --- Humeurs ---
    final Map<String, int> moodFrequency = {};
    for (var s in allSymptoms) {
      if (s.mood != null && s.mood!.isNotEmpty) {
        moodFrequency.update(s.mood!, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // --- NOUVEAU : Tendances cycles (triés par date) ---
    final sorted = completedCycles.toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    final cycleTrends = <_CycleTrendPoint>[];
    for (int i = 0; i < sorted.length; i++) {
      cycleTrends.add(_CycleTrendPoint(index: i, length: sorted[i].cycleLength!, startDate: sorted[i].startDate));
    }

    // --- NOUVEAU : Durées règles ---
    final sortedP = periodCycles.toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    final periodLengths = <_PeriodLengthPoint>[];
    for (int i = 0; i < sortedP.length; i++) {
      final days = sortedP[i].periodEndDate!.difference(sortedP[i].startDate).inDays + 1;
      periodLengths.add(_PeriodLengthPoint(index: i, days: days, startDate: sortedP[i].startDate));
    }

    // --- NOUVEAU : Niveaux moyens ---
    double? avgPain, avgEnergy, avgLibido;
    final withPain = allSymptoms.where((s) => s.painLevel != null).toList();
    final withEnergy = allSymptoms.where((s) => s.energyLevel != null).toList();
    final withLibido = allSymptoms.where((s) => s.libidoLevel != null).toList();
    if (withPain.isNotEmpty) avgPain = withPain.map((s) => s.painLevel!).reduce((a, b) => a + b) / withPain.length;
    if (withEnergy.isNotEmpty) avgEnergy = withEnergy.map((s) => s.energyLevel!).reduce((a, b) => a + b) / withEnergy.length;
    if (withLibido.isNotEmpty) avgLibido = withLibido.map((s) => s.libidoLevel!).reduce((a, b) => a + b) / withLibido.length;

    // --- NOUVEAU : Insights ---
    final insights = _generateInsights(
      avgCycleLength: avgCycleLength,
      shortestCycle: shortestCycle,
      longestCycle: longestCycle,
      completedCount: completedCycles.length,
      avgPeriodLength: avgPeriodLength,
      avgPain: avgPain,
      avgEnergy: avgEnergy,
      moodFrequency: moodFrequency,
      totalSymptoms: allSymptoms.length,
    );

    return _StatsData(
      heatmapData: heatmapData,
      avgCycleLength: avgCycleLength,
      avgPeriodLength: avgPeriodLength,
      moodFrequency: moodFrequency,
      totalCompletedCycles: completedCycles.length,
      shortestCycle: shortestCycle,
      longestCycle: longestCycle,
      cycleTrends: cycleTrends,
      periodLengths: periodLengths,
      avgPain: avgPain,
      avgEnergy: avgEnergy,
      avgLibido: avgLibido,
      totalSymptoms: allSymptoms.length,
      insights: insights,
    );
  }

  // ═══════════════════════════════════════
  // INSIGHTS GENERATION
  // ═══════════════════════════════════════

  List<_Insight> _generateInsights({
    double? avgCycleLength,
    int? shortestCycle,
    int? longestCycle,
    required int completedCount,
    double? avgPeriodLength,
    double? avgPain,
    double? avgEnergy,
    required Map<String, int> moodFrequency,
    required int totalSymptoms,
  }) {
    final list = <_Insight>[];

    if (completedCount >= 3 && shortestCycle != null && longestCycle != null) {
      final v = longestCycle - shortestCycle;
      if (v <= 3) {
        list.add(_Insight(icon: Icons.verified_rounded, title: 'Cycles très réguliers', description: 'Seulement $v jours de variation. Excellent !', color: const Color(0xFF66BB6A)));
      } else if (v <= 7) {
        list.add(_Insight(icon: Icons.trending_flat_rounded, title: 'Cycles assez réguliers', description: 'Variation de $v jours. C\'est dans la normale.', color: const Color(0xFFFFCA28)));
      } else {
        list.add(_Insight(icon: Icons.show_chart_rounded, title: 'Cycles irréguliers', description: 'Variation de $v jours détectée. Consultez si cela persiste.', color: const Color(0xFFEF5350)));
      }
    }

    if (avgPeriodLength != null) {
      if (avgPeriodLength > 7) {
        list.add(_Insight(icon: Icons.water_drop_rounded, title: 'Règles longues', description: 'Moyenne de ${avgPeriodLength.round()} jours (norme: 3-7 jours).', color: const Color(0xFFEF5350)));
      } else {
        list.add(_Insight(icon: Icons.water_drop_rounded, title: 'Durée des règles normale', description: 'Moyenne de ${avgPeriodLength.round()} jours, dans la norme.', color: const Color(0xFF66BB6A)));
      }
    }

    if (avgPain != null && avgPain > 3) {
      list.add(_Insight(icon: Icons.healing_rounded, title: 'Douleur notable', description: 'Niveau moyen ${avgPain.toStringAsFixed(1)}/5. Parlez-en à votre médecin.', color: const Color(0xFFFF7043)));
    }

    if (avgEnergy != null && avgEnergy < 2.5) {
      list.add(_Insight(icon: Icons.battery_2_bar_rounded, title: 'Énergie basse', description: 'Niveau moyen ${avgEnergy.toStringAsFixed(1)}/5. Reposez-vous et hydratez-vous.', color: const Color(0xFF42A5F5)));
    }

    if (moodFrequency.isNotEmpty) {
      final top = moodFrequency.entries.reduce((a, b) => a.value > b.value ? a : b);
      final emoji = _moodEmojis[top.key] ?? '🫥';
      list.add(_Insight(icon: Icons.mood_rounded, title: 'Humeur dominante : $emoji ${top.key}', description: 'Enregistrée ${top.value} fois.', color: const Color(0xFFAB47BC)));
    }

    if (totalSymptoms == 0) {
      list.add(_Insight(icon: Icons.edit_note_rounded, title: 'Commencez votre journal', description: 'Notez vos symptômes pour des stats plus riches.', color: const Color(0xFF78909C)));
    }

    if (completedCount == 0) {
      list.add(_Insight(icon: Icons.hourglass_empty_rounded, title: 'Pas assez de données', description: 'Terminez 2-3 cycles pour des statistiques fiables.', color: const Color(0xFF78909C)));
    }

    return list;
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<_StatsData>(
        future: _statsDataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) return _buildEmpty(cs);
          return _buildBody(snap.data!, cs);
        },
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return CustomScrollView(slivers: [
      _sliverAppBar(cs),
      SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.analytics_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('Pas de données à afficher.', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildBody(_StatsData data, ColorScheme cs) {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        _sliverAppBar(cs),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: _buildSummaryRow(data, cs),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              dividerHeight: 0.5,
              dividerColor: cs.outlineVariant.withAlpha(60),
              tabs: const [Tab(text: 'Aperçu'), Tab(text: 'Graphiques'), Tab(text: 'Tendances')],
            ),
            cs.surface,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _tabOverview(data, cs),
          _tabCharts(data, cs),
          _tabTrends(data, cs),
        ],
      ),
    );
  }

  SliverAppBar _sliverAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      leading: const AppBackButton(),
      title: const Text('Statistiques', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════
  // SUMMARY ROW (3 mini-cartes)
  // ═══════════════════════════════════════

  Widget _buildSummaryRow(_StatsData d, ColorScheme cs) {
    return Row(children: [
      Expanded(child: _miniStat(Icons.sync_rounded, 'Cycle moy.', d.avgCycleLength != null ? '${d.avgCycleLength!.round()}j' : '--', const Color(0xFF42A5F5), cs)),
      const SizedBox(width: 10),
      Expanded(child: _miniStat(Icons.water_drop_rounded, 'Règles moy.', d.avgPeriodLength != null ? '${d.avgPeriodLength!.round()}j' : '--', const Color(0xFFEF5350), cs)),
      const SizedBox(width: 10),
      Expanded(child: _miniStat(Icons.check_circle_outline_rounded, 'Cycles', '${d.totalCompletedCycles}', const Color(0xFF66BB6A), cs)),
    ]);
  }

  Widget _miniStat(IconData icon, String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withAlpha(20), color.withAlpha(8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1 : APERÇU
  // ═══════════════════════════════════════

  Widget _tabOverview(_StatsData d, ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (d.insights.isNotEmpty) ...[
        _section('💡 Insights', cs),
        ...d.insights.map((i) => _insightCard(i, cs)),
        const SizedBox(height: 24),
      ],
      _section('📅 Calendrier', cs),
      _heatmapCard(d, cs),
      const SizedBox(height: 12),
      _legend(cs),
      const SizedBox(height: 24),
      _section('📊 Détails', cs),
      _detailsCard(d, cs),
      const SizedBox(height: 40),
    ]);
  }

  // ═══════════════════════════════════════
  // TAB 2 : GRAPHIQUES
  // ═══════════════════════════════════════

  Widget _tabCharts(_StatsData d, ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (d.cycleTrends.length >= 2) ...[
        _section('📈 Évolution des cycles', cs),
        _cycleTrendChart(d, cs),
        const SizedBox(height: 24),
      ],
      if (d.periodLengths.length >= 2) ...[
        _section('🩸 Durée des règles', cs),
        _periodChart(d, cs),
        const SizedBox(height: 24),
      ],
      _section('😊 Fréquence des humeurs', cs),
      _moodChart(d.moodFrequency, cs),
      const SizedBox(height: 40),
    ]);
  }

  // ═══════════════════════════════════════
  // TAB 3 : TENDANCES
  // ═══════════════════════════════════════

  Widget _tabTrends(_StatsData d, ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _section('🌡️ Niveaux moyens', cs),
      _levelIndicators(d, cs),
      const SizedBox(height: 24),
      if (d.shortestCycle != null && d.longestCycle != null) ...[
        _section('🎯 Régularité', cs),
        _regularityCard(d, cs),
        const SizedBox(height: 24),
      ],
      _section('📋 Résumé global', cs),
      _globalSummary(d, cs),
      const SizedBox(height: 40),
    ]);
  }

  // ═══════════════════════════════════════
  // WIDGETS RÉUTILISABLES
  // ═══════════════════════════════════════

  Widget _section(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
    );
  }

  BoxDecoration _cardDeco(ColorScheme cs) => BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      );

  Widget _placeholder(String text, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDeco(cs),
      child: Column(children: [
        Icon(icon, size: 36, color: cs.outline),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Insight Card ──

  Widget _insightCard(_Insight i, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: i.color.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: i.color.withAlpha(40)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: i.color.withAlpha(26), shape: BoxShape.circle),
          child: Icon(i.icon, color: i.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(i.description, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  // ── Heatmap ──

  Widget _heatmapCard(_StatsData d, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(cs),
      child: d.heatmapData.isNotEmpty
          ? HeatMapCalendar(
              datasets: d.heatmapData,
              colorsets: _colorMapping,
              colorMode: ColorMode.color,
              defaultColor: Colors.transparent,
              textColor: cs.onSurface,
              showColorTip: false,
              monthFontSize: 14,
            )
          : Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.calendar_month_outlined, size: 40, color: cs.outline),
                const SizedBox(height: 12),
                Text('Aucune donnée pour le calendrier.', style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
    );
  }

  // ── Legend ──

  Widget _legend(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _legendDot(const Color(0xFFEF5350), 'Règles', cs),
        _legendDot(const Color(0xFFFFCA28), 'Ovulation', cs),
        _legendDot(const Color(0xFF66BB6A), 'Fertilité', cs),
        _legendDot(const Color(0xFF42A5F5), 'Symptômes', cs),
      ]),
    );
  }

  Widget _legendDot(Color c, String label, ColorScheme cs) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    ]);
  }

  // ── Details Card ──

  Widget _detailsCard(_StatsData d, ColorScheme cs) {
    if (d.totalCompletedCycles == 0) {
      return _placeholder('Pas assez de données pour les moyennes.', Icons.hourglass_empty_rounded, cs);
    }
    return Container(
      decoration: _cardDeco(cs),
      child: Column(children: [
        _statTile(Icons.sync_rounded, 'Cycle moyen', '${d.avgCycleLength?.round() ?? 0} jours', const Color(0xFF42A5F5), cs),
        _divider(cs),
        _statTile(Icons.water_drop_rounded, 'Règles moyennes', '${d.avgPeriodLength?.round() ?? 0} jours', const Color(0xFFEF5350), cs),
        _divider(cs),
        _statTile(Icons.check_circle_outline_rounded, 'Cycles terminés', '${d.totalCompletedCycles}', const Color(0xFF66BB6A), cs),
        if (d.shortestCycle != null) ...[_divider(cs), _statTile(Icons.arrow_downward_rounded, 'Cycle le plus court', '${d.shortestCycle} jours', const Color(0xFFFF7043), cs)],
        if (d.longestCycle != null) ...[_divider(cs), _statTile(Icons.arrow_upward_rounded, 'Cycle le plus long', '${d.longestCycle} jours', const Color(0xFFAB47BC), cs)],
        _divider(cs),
        _statTile(Icons.edit_note_rounded, 'Symptômes enregistrés', '${d.totalSymptoms}', const Color(0xFF78909C), cs),
      ]),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color c, ColorScheme cs) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withAlpha(26), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
    );
  }

  Widget _divider(ColorScheme cs) => Divider(height: 1, indent: 56, color: cs.outlineVariant.withAlpha(60));

  // ═══════════════════════════════════════
  // GRAPHIQUES
  // ═══════════════════════════════════════

  // ── Cycle Trend (LineChart) ──

  Widget _cycleTrendChart(_StatsData d, ColorScheme cs) {
    final pts = d.cycleTrends;
    if (pts.length < 2) return _placeholder('Au moins 2 cycles terminés nécessaires.', Icons.show_chart_rounded, cs);

    final minY = (pts.map((t) => t.length).reduce(min) - 3).toDouble().clamp(0.0, 100.0);
    final maxY = (pts.map((t) => t.length).reduce(max) + 3).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: _cardDeco(cs),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withAlpha(40), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 5,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}j', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('MMM', 'fr_FR').format(pts[i].startDate), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: pts.map((t) => FlSpot(t.index.toDouble(), t.length.toDouble())).toList(),
                isCurved: true,
                curveSmoothness: 0.25,
                color: const Color(0xFF42A5F5),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2.5, strokeColor: const Color(0xFF42A5F5)),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF42A5F5).withAlpha(50), const Color(0xFF42A5F5).withAlpha(5)],
                  ),
                ),
              ),
              if (d.avgCycleLength != null)
                LineChartBarData(
                  spots: [FlSpot(0, d.avgCycleLength!), FlSpot((pts.length - 1).toDouble(), d.avgCycleLength!)],
                  isCurved: false,
                  color: cs.outline.withAlpha(80),
                  barWidth: 1.5,
                  dashArray: [6, 4],
                  dotData: const FlDotData(show: false),
                ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => cs.inverseSurface,
                getTooltipItems: (spots) => spots.map((s) {
                  if (s.barIndex == 1) return null;
                  return LineTooltipItem('${s.y.toInt()} jours', TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.bold, fontSize: 12));
                }).toList(),
              ),
            ),
          )),
        ),
        if (d.avgCycleLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 16, height: 2, color: cs.outline.withAlpha(80)),
              const SizedBox(width: 6),
              Text('Moyenne : ${d.avgCycleLength!.round()} jours', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }

  // ── Period Length (BarChart) ──

  Widget _periodChart(_StatsData d, ColorScheme cs) {
    final pts = d.periodLengths;
    if (pts.length < 2) return _placeholder('Au moins 2 cycles avec fin de règles nécessaires.', Icons.bar_chart_rounded, cs);

    final maxY = pts.map((p) => p.days).reduce(max).toDouble() + 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      decoration: _cardDeco(cs),
      child: SizedBox(
        height: 180,
        child: BarChart(BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withAlpha(40), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 2,
                getTitlesWidget: (v, _) => Text('${v.toInt()}j', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('MMM', 'fr_FR').format(pts[i].startDate), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: pts.map((p) => BarChartGroupData(x: p.index, barRods: [
            BarChartRodData(
              toY: p.days.toDouble(),
              width: pts.length > 8 ? 10 : 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFFEF9A9A), Color(0xFFEF5350)]),
            ),
          ])).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.inverseSurface,
              getTooltipItem: (_, __, rod, ___) => BarTooltipItem('${rod.toY.toInt()} jours', TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        )),
      ),
    );
  }

  // ── Mood Chart (horizontal bars) ──

  Widget _moodChart(Map<String, int> moodFreq, ColorScheme cs) {
    if (moodFreq.isEmpty) return _placeholder('Aucune humeur enregistrée.', Icons.mood_rounded, cs);

    final sorted = moodFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    const colors = [Color(0xFFEF5350), Color(0xFFFF7043), Color(0xFFFFCA28), Color(0xFF66BB6A), Color(0xFF42A5F5), Color(0xFFAB47BC), Color(0xFF78909C), Color(0xFFEC407A)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(cs),
      child: Column(
        children: sorted.asMap().entries.map((e) {
          final idx = e.key;
          final mood = e.value;
          final color = colors[idx % colors.length];
          final emoji = _moodEmojis[mood.key] ?? '🫥';
          final frac = mood.value / maxVal;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 100,
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(mood.key, style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(children: [
                  Container(height: 22, decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(11))),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.08, 1.0),
                    child: Container(height: 22, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withAlpha(180), color]), borderRadius: BorderRadius.circular(11))),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 30, child: Text('${mood.value}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface), textAlign: TextAlign.right)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TENDANCES
  // ═══════════════════════════════════════

  // ── Level Indicators ──

  Widget _levelIndicators(_StatsData d, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(cs),
      child: Column(children: [
        _levelRow(Icons.healing_rounded, 'Douleur moyenne', d.avgPain, 5, const Color(0xFFEF5350), cs),
        const SizedBox(height: 18),
        _levelRow(Icons.bolt_rounded, 'Énergie moyenne', d.avgEnergy, 5, const Color(0xFFFFCA28), cs),
        const SizedBox(height: 18),
        _levelRow(Icons.favorite_rounded, 'Libido moyenne', d.avgLibido, 5, const Color(0xFFEC407A), cs),
      ]),
    );
  }

  Widget _levelRow(IconData icon, String label, double? value, int maxVal, Color color, ColorScheme cs) {
    final frac = ((value ?? 0) / maxVal).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(
          value != null ? '${value.toStringAsFixed(1)} / $maxVal' : 'N/A',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: value != null ? cs.onSurface : cs.outline),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: color.withAlpha(20), valueColor: AlwaysStoppedAnimation(color)),
      ),
    ]);
  }

  // ── Regularity Card ──

  Widget _regularityCard(_StatsData d, ColorScheme cs) {
    final variation = d.longestCycle! - d.shortestCycle!;
    final label = variation <= 3 ? 'Très régulier' : variation <= 7 ? 'Régulier' : 'Irrégulier';
    final color = variation <= 3 ? const Color(0xFF66BB6A) : variation <= 7 ? const Color(0xFFFFCA28) : const Color(0xFFEF5350);
    final pct = ((1.0 - (variation / 20.0)) * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(cs),
      child: Row(children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(value: pct / 100, strokeWidth: 6, backgroundColor: color.withAlpha(30), valueColor: AlwaysStoppedAnimation(color), strokeCap: StrokeCap.round),
            ),
            Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ),
            const SizedBox(height: 10),
            Text('Variation : $variation jours', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            Text('${d.shortestCycle}j – ${d.longestCycle}j', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }

  // ── Global Summary ──

  Widget _globalSummary(_StatsData d, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(cs),
      child: Column(children: [
        _summaryRow('Cycles suivis', '${d.totalCompletedCycles}', Icons.loop_rounded, cs),
        const SizedBox(height: 10),
        _summaryRow('Symptômes notés', '${d.totalSymptoms}', Icons.edit_note_rounded, cs),
        const SizedBox(height: 10),
        _summaryRow('Humeurs distinctes', '${d.moodFrequency.length}', Icons.mood_rounded, cs),
        if (d.avgCycleLength != null) ...[const SizedBox(height: 10), _summaryRow('Durée cycle prévue', '~${d.avgCycleLength!.round()} jours', Icons.calendar_month_rounded, cs)],
        if (d.avgPeriodLength != null) ...[const SizedBox(height: 10), _summaryRow('Durée règles prévue', '~${d.avgPeriodLength!.round()} jours', Icons.water_drop_outlined, cs)],
      ]),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon, ColorScheme cs) {
    return Row(children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
    ]);
  }
}

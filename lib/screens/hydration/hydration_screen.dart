import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════
// HYDRATION SCREEN — SUIVI D'HYDRATATION
// ═══════════════════════════════════════

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_HydrationData> _dataFuture;
  late AnimationController _celebrationController;
  bool _justReachedGoal = false;

  // Objectif journalier en litres
  static const double _dailyGoal = 2.0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<_HydrationData> _fetchData() async {
    final todayTotal = await _dbHelper.getTodayTotalHydration();
    final todayEntries = await _dbHelper.getHydrationForDate(DateTime.now());
    final weekHistory = await _dbHelper.getHydrationHistory(50);

    // Calculer les totaux par jour pour les 7 derniers jours
    final weekTotals = _calculateWeekTotals(weekHistory);

    // Nombre de jours où l'objectif a été atteint cette semaine
    final daysGoalMet =
        weekTotals.where((d) => d.total >= _dailyGoal).length;

    // Série actuelle (jours consécutifs avec objectif atteint)
    int streak = 0;
    for (final day in weekTotals) {
      if (day.total >= _dailyGoal) {
        streak++;
      } else {
        break;
      }
    }

    return _HydrationData(
      todayTotal: todayTotal,
      todayEntries: todayEntries,
      weekTotals: weekTotals,
      daysGoalMet: daysGoalMet,
      streak: streak,
    );
  }

  List<_DayTotal> _calculateWeekTotals(List<Map<String, dynamic>> history) {
    final Map<String, double> grouped = {};
    for (final entry in history) {
      final date = DateTime.parse(entry['date']);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped[key] = (grouped[key] ?? 0) + (entry['amount'] as num).toDouble();
    }

    // 7 derniers jours
    final List<_DayTotal> result = [];
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      result.add(_DayTotal(
        date: day,
        total: grouped[key] ?? 0,
      ));
    }
    return result;
  }

  Future<void> _addWater(double amount) async {
    HapticFeedback.mediumImpact();

    final currentData = await _dataFuture;
    final wasUnderGoal = currentData.todayTotal < _dailyGoal;

    await _dbHelper.insertHydration({
      'date': DateTime.now().toIso8601String(),
      'amount': amount,
      'goal_met': (currentData.todayTotal + amount >= _dailyGoal) ? 1 : 0,
    });

    // Vérifier si on vient d'atteindre l'objectif
    if (wasUnderGoal && (currentData.todayTotal + amount) >= _dailyGoal) {
      _justReachedGoal = true;
      _celebrationController.forward(from: 0);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _justReachedGoal = false);
      });
    }

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<_HydrationData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(cs),
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data ??
              _HydrationData(
                todayTotal: 0,
                todayEntries: [],
                weekTotals: [],
                daysGoalMet: 0,
                streak: 0,
              );

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
      title: const Text('Hydratation',
          style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF29B6F6).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded,
                  size: 14, color: Color(0xFF29B6F6)),
              const SizedBox(width: 4),
              Text(
                '${_dailyGoal.toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29B6F6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════

  Widget _buildContent(_HydrationData data, ColorScheme cs) {
    final progress = (data.todayTotal / _dailyGoal).clamp(0.0, 1.0);
    final remaining = (_dailyGoal - data.todayTotal).clamp(0.0, _dailyGoal);
    final percentage = (progress * 100).round();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(cs),

        // ── Hero Card (progress circulaire) ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildHeroCard(data, progress, percentage, remaining, cs),
          ),
        ),

        // ── Mini Stats Row ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildMiniStats(data, cs),
          ),
        ),

        // ── Boutons d'ajout rapide ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: _sectionTitle('💧 Ajout rapide', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildQuickAddButtons(cs),
          ),
        ),

        // ── Graphique semaine ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _sectionTitle('📊 Cette semaine', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildWeekChart(data, cs),
          ),
        ),

        // ── Historique du jour ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _sectionTitle('🕐 Aujourd\'hui', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _buildTodayHistory(data, cs),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════

  Widget _buildHeroCard(_HydrationData data, double progress, int percentage,
      double remaining, ColorScheme cs) {
    final goalReached = data.todayTotal >= _dailyGoal;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: goalReached
                ? [const Color(0xFF66BB6A), const Color(0xFF43A047)]
                : [const Color(0xFF29B6F6), const Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (goalReached
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF29B6F6))
                  .withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // ── Cercle de progression ──
                SizedBox(
                  width: 120,
                  height: 120,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animValue, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: animValue,
                              strokeWidth: 10,
                              backgroundColor: Colors.white.withAlpha(40),
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.white),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                goalReached
                                    ? Icons.check_circle_rounded
                                    : Icons.water_drop_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(animValue * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 22),
                // ── Informations textuelles ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_justReachedGoal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🎉 Objectif atteint !',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        '${data.todayTotal.toStringAsFixed(2)}L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'sur ${_dailyGoal.toStringAsFixed(1)}L',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          goalReached
                              ? '✅ Bravo, objectif atteint !'
                              : '💧 Encore ${remaining.toStringAsFixed(2)}L',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // MINI STATS
  // ═══════════════════════════════════════

  Widget _buildMiniStats(_HydrationData data, ColorScheme cs) {
    // Moyenne sur la semaine
    final weekAvg = data.weekTotals.isNotEmpty
        ? data.weekTotals
                .map((d) => d.total)
                .reduce((a, b) => a + b) /
            data.weekTotals.length
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _miniStatCard(
            Icons.local_fire_department_rounded,
            'Série',
            '${data.streak} jour${data.streak > 1 ? 's' : ''}',
            const Color(0xFFFF7043),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            Icons.emoji_events_rounded,
            'Objectifs',
            '${data.daysGoalMet}/7 jours',
            const Color(0xFFFFCA28),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            Icons.show_chart_rounded,
            'Moyenne',
            '${weekAvg.toStringAsFixed(1)}L',
            const Color(0xFF42A5F5),
            cs,
          ),
        ),
      ],
    );
  }

  Widget _miniStatCard(
      IconData icon, String label, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(18), color.withAlpha(8)],
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
            decoration:
                BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // QUICK ADD BUTTONS
  // ═══════════════════════════════════════

  Widget _buildQuickAddButtons(ColorScheme cs) {
    final options = [
      _WaterOption('150ml', 0.15, Icons.coffee_rounded, const Color(0xFF8D6E63)),
      _WaterOption('200ml', 0.20, Icons.local_cafe_rounded, const Color(0xFF29B6F6)),
      _WaterOption('330ml', 0.33, Icons.local_drink_rounded, const Color(0xFF42A5F5)),
      _WaterOption('500ml', 0.50, Icons.water_drop_rounded, const Color(0xFF0288D1)),
      _WaterOption('1L', 1.0, Icons.sports_bar_rounded, const Color(0xFF7E57C2)),
    ];

    return Row(
      children: options.map((opt) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: opt == options.last ? 0 : 8,
            ),
            child: _WaterButton(
              option: opt,
              onTap: () => _addWater(opt.amount),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════
  // WEEK CHART
  // ═══════════════════════════════════════

  Widget _buildWeekChart(_HydrationData data, ColorScheme cs) {
    final days = data.weekTotals.reversed.toList(); // Lundi → Dimanche
    final maxVal = days.isNotEmpty
        ? days.map((d) => d.total).reduce((a, b) => a > b ? a : b)
        : _dailyGoal;
    final chartMax = maxVal > _dailyGoal ? maxVal : _dailyGoal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        children: [
          // ── Header ──
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Consommation hebdomadaire',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Bars ──
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.asMap().entries.map((entry) {
                final day = entry.value;
                final isToday = entry.key == days.length - 1;
                final barHeight =
                    chartMax > 0 ? (day.total / chartMax * 100).clamp(4.0, 100.0) : 4.0;
                final goalReached = day.total >= _dailyGoal;
                final color = isToday
                    ? const Color(0xFF29B6F6)
                    : goalReached
                        ? const Color(0xFF66BB6A)
                        : cs.outlineVariant;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Valeur
                        Text(
                          day.total > 0
                              ? '${day.total.toStringAsFixed(1)}'
                              : '-',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isToday ? color : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Barre
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: barHeight),
                          duration: Duration(
                              milliseconds: 600 + entry.key * 100),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Container(
                            height: value,
                            decoration: BoxDecoration(
                              color: day.total > 0
                                  ? color.withAlpha(isToday ? 255 : 160)
                                  : cs.outlineVariant.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                              border: isToday
                                  ? Border.all(
                                      color: color.withAlpha(100), width: 1.5)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Jour
                        Text(
                          DateFormat('E', 'fr_FR')
                              .format(day.date)
                              .substring(0, 2)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color:
                                isToday ? color : cs.onSurfaceVariant,
                          ),
                        ),
                        // Point objectif atteint
                        if (goalReached)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF66BB6A),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 9),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Légende ──
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF66BB6A), 'Objectif atteint', cs),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF29B6F6), 'Aujourd\'hui', cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
      ],
    );
  }

  // ═══════════════════════════════════════
  // TODAY'S HISTORY
  // ═══════════════════════════════════════

  Widget _buildTodayHistory(_HydrationData data, ColorScheme cs) {
    if (data.todayEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withAlpha(60)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.water_drop_outlined,
                  size: 32, color: Color(0xFF29B6F6)),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucune consommation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Appuyez sur un bouton ci-dessus pour commencer à boire !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // Trier les entrées : plus récentes en premier
    final sorted = List<Map<String, dynamic>>.from(data.todayEntries)
      ..sort((a, b) => b['date'].compareTo(a['date']));

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '${sorted.length} enregistrement${sorted.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Entries
          ...sorted.asMap().entries.map((entry) {
            final item = entry.value;
            final date = DateTime.parse(item['date']);
            final amount = (item['amount'] as num).toDouble();
            final isLast = entry.key == sorted.length - 1;

            // Choisir l'icône/couleur selon la quantité
            final info = _getAmountInfo(amount);

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: info.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(info.icon, size: 18, color: info.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+${_formatAmount(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              info.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withAlpha(100),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          DateFormat('HH:mm').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 58,
                    color: cs.outlineVariant.withAlpha(40),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Divider(color: cs.outlineVariant.withAlpha(60), thickness: 1),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1.0) {
      return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 1)}L';
    }
    return '${(amount * 1000).round()}ml';
  }

  _AmountInfo _getAmountInfo(double amount) {
    if (amount >= 1.0) {
      return _AmountInfo(
          Icons.sports_bar_rounded, 'Grande bouteille', const Color(0xFF7E57C2));
    } else if (amount >= 0.5) {
      return _AmountInfo(
          Icons.water_drop_rounded, 'Bouteille', const Color(0xFF0288D1));
    } else if (amount >= 0.3) {
      return _AmountInfo(
          Icons.local_drink_rounded, 'Canette / Grand verre', const Color(0xFF42A5F5));
    } else if (amount >= 0.2) {
      return _AmountInfo(
          Icons.local_cafe_rounded, 'Verre', const Color(0xFF29B6F6));
    } else {
      return _AmountInfo(
          Icons.coffee_rounded, 'Tasse / Petit verre', const Color(0xFF8D6E63));
    }
  }
}

// ═══════════════════════════════════════════════════
// WATER BUTTON (ajout rapide)
// ═══════════════════════════════════════════════════

class _WaterButton extends StatefulWidget {
  final _WaterOption option;
  final VoidCallback onTap;

  const _WaterButton({required this.option, required this.onTap});

  @override
  State<_WaterButton> createState() => _WaterButtonState();
}

class _WaterButtonState extends State<_WaterButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opt = widget.option;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _bounceController.forward(from: 0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: ScaleTransition(
        scale: _bounceAnim,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: opt.color.withAlpha(15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: opt.color.withAlpha(50)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: opt.color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(opt.icon, size: 20, color: opt.color),
                ),
                const SizedBox(height: 8),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: opt.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════

class _HydrationData {
  final double todayTotal;
  final List<Map<String, dynamic>> todayEntries;
  final List<_DayTotal> weekTotals;
  final int daysGoalMet;
  final int streak;

  _HydrationData({
    required this.todayTotal,
    required this.todayEntries,
    required this.weekTotals,
    required this.daysGoalMet,
    required this.streak,
  });
}

class _DayTotal {
  final DateTime date;
  final double total;
  const _DayTotal({required this.date, required this.total});
}

class _WaterOption {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _WaterOption(this.label, this.amount, this.icon, this.color);
}

class _AmountInfo {
  final IconData icon;
  final String label;
  final Color color;
  const _AmountInfo(this.icon, this.label, this.color);
}

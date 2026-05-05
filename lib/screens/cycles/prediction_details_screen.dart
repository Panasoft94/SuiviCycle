import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../models/settings.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════
// PREDICTION DETAILS SCREEN
// ═══════════════════════════════════════

class PredictionDetailsScreen extends StatefulWidget {
  const PredictionDetailsScreen({super.key});

  @override
  State<PredictionDetailsScreen> createState() =>
      _PredictionDetailsScreenState();
}

class _PredictionDetailsScreenState extends State<PredictionDetailsScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_PredictionData> _dataFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _dataFuture = _fetchData();
  }

  Future<_PredictionData> _fetchData() async {
    final settings = await _dbHelper.getSettings();
    final avgCycleLength = await _dbHelper.getAverageCycleLength();
    final cycles = await _dbHelper.getCycles();

    // Cycle actif (en cours)
    final activeCycle = cycles.cast<Cycle?>().firstWhere(
          (c) => c?.endDate == null,
          orElse: () => null,
        );

    // Cycles complétés (pour le comptage)
    final completedCount = cycles.where((c) => c.endDate != null).length;

    // Calculer les durées réelles à partir des dates de début consécutives
    // (normalisées à minuit) pour éviter les décalages d'heure
    final sortedCycles = [...cycles]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final lengths = <int>[];
    for (int i = 1; i < sortedCycles.length; i++) {
      final prev = sortedCycles[i - 1].startDate;
      final curr = sortedCycles[i].startDate;
      final prevNorm = DateTime(prev.year, prev.month, prev.day);
      final currNorm = DateTime(curr.year, curr.month, curr.day);
      final diff = currNorm.difference(prevNorm).inDays;
      if (diff >= 21 && diff <= 45) lengths.add(diff);
    }
    // Fallback : si pas assez de cycles consécutifs, utiliser cycleLength stocké
    if (lengths.isEmpty) {
      for (final c in cycles) {
        if (c.cycleLength != null && c.cycleLength! >= 21 && c.cycleLength! <= 45) {
          lengths.add(c.cycleLength!);
        }
      }
    }

    // Variabilité (écart-type)
    double? stdDeviation;
    if (lengths.length >= 2) {
      final mean = lengths.reduce((a, b) => a + b) / lengths.length;
      final variance =
          lengths.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) /
              lengths.length;
      stdDeviation = _sqrt(variance);
    }

    // Min / Max
    int? minLength, maxLength;
    if (lengths.isNotEmpty) {
      minLength = lengths.reduce((a, b) => a < b ? a : b);
      maxLength = lengths.reduce((a, b) => a > b ? a : b);
    }

    // Score de fiabilité (0–100)
    int reliabilityScore = _calculateReliability(lengths, stdDeviation);

    return _PredictionData(
      settings: settings,
      avgCycleLength: avgCycleLength,
      activeCycle: activeCycle,
      completedCount: completedCount,
      cycleLengths: lengths,
      stdDeviation: stdDeviation,
      minLength: minLength,
      maxLength: maxLength,
      reliabilityScore: reliabilityScore,
    );
  }

  int _calculateReliability(List<int> lengths, double? stdDev) {
    if (lengths.isEmpty) return 0;
    // Base : nombre de cycles (max 50 pts pour 6+ cycles)
    int base = (lengths.length / 6 * 50).clamp(0, 50).round();
    // Bonus régularité (max 50 pts si écart-type < 2)
    int regularity = 0;
    if (stdDev != null) {
      regularity = ((1 - (stdDev / 5).clamp(0, 1)) * 50).round();
    }
    return (base + regularity).clamp(0, 100);
  }

  double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<_PredictionData>(
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
                        Text('Analyse en cours...',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(cs),
                SliverFillRemaining(
                  child: Center(
                    child: Text('Impossible de charger les données.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ),
              ],
            );
          }

          return _buildContent(snapshot.data!, cs);
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
      title: const Text('Intelligence Prédictive',
          style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════

  Widget _buildContent(_PredictionData data, ColorScheme cs) {
    final effectiveLength =
        data.avgCycleLength?.round() ?? data.settings.defaultCycleLength;

    // Calculs de prédiction si cycle actif
    DateTime? nextOvulation;
    DateTime? nextPeriod;
    DateTime? fertileStart;
    DateTime? fertileEnd;
    int? currentDay;

    if (data.activeCycle != null) {
      // Normaliser les dates à minuit pour des calculs de jours exacts (Jour 1, pas Jour 0)
      final start = data.activeCycle!.startDate;
      final startNorm = DateTime(start.year, start.month, start.day);
      final now = DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      currentDay = todayNorm.difference(startNorm).inDays + 1;
      nextOvulation =
          startNorm.add(Duration(days: effectiveLength - 14));
      nextPeriod =
          startNorm.add(Duration(days: effectiveLength));
      fertileStart = nextOvulation!.subtract(const Duration(days: 5));
      fertileEnd = nextOvulation!.add(const Duration(days: 1));
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(cs),

        // ── Hero Card ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildHeroCard(data, cs),
          ),
        ),

        // ── Score de fiabilité ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildReliabilityCard(data, cs),
          ),
        ),

        // ── Prédictions actuelles (si cycle actif) ──
        if (data.activeCycle != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: _sectionTitle('📅 Prédictions actuelles', cs),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _buildCurrentPredictions(
                currentDay: currentDay!,
                nextOvulation: nextOvulation!,
                nextPeriod: nextPeriod!,
                fertileStart: fertileStart!,
                fertileEnd: fertileEnd!,
                effectiveLength: effectiveLength,
                cs: cs,
              ),
            ),
          ),
        ],

        // ── Cycle timeline visuel ──
        if (data.activeCycle != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildCycleTimeline(
                currentDay: currentDay!,
                effectiveLength: effectiveLength,
                ovulationDay: effectiveLength - 14,
                cs: cs,
              ),
            ),
          ),

        // ── Analyse des données ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _sectionTitle('📊 Analyse de vos données', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildDataAnalysis(data, effectiveLength, cs),
          ),
        ),

        // ── Comment ça marche ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: _sectionTitle('🧠 Comment ça marche', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildAlgorithmExplanation(data, cs),
          ),
        ),

        // ── Phases du cycle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: _sectionTitle('🌙 Les 4 phases du cycle', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildPhasesEducation(effectiveLength, cs),
          ),
        ),

        // ── Conseils ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: _sectionTitle('💡 Conseils pour la précision', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _buildTipsSection(data, cs),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════

  Widget _buildHeroCard(_PredictionData data, ColorScheme cs) {
    final hasData = data.avgCycleLength != null;
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withAlpha(200),
              cs.tertiary.withAlpha(180),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasData ? '✨ Données personnalisées' : '🆕 Premiers pas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasData
                        ? 'Cycle moyen\n${data.avgCycleLength!.round()} jours'
                        : 'Cycle par défaut\n${data.settings.defaultCycleLength} jours',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasData
                        ? 'Basé sur ${data.completedCount} cycle${data.completedCount > 1 ? 's' : ''} enregistré${data.completedCount > 1 ? 's' : ''}'
                        : 'Enregistrez vos cycles pour affiner les prédictions',
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // RELIABILITY CARD (score circulaire)
  // ═══════════════════════════════════════

  Widget _buildReliabilityCard(_PredictionData data, ColorScheme cs) {
    final score = data.reliabilityScore;
    final color = score >= 70
        ? const Color(0xFF66BB6A)
        : score >= 40
            ? const Color(0xFFFFCA28)
            : const Color(0xFFEF5350);
    final label = score >= 70
        ? 'Excellente'
        : score >= 40
            ? 'Bonne'
            : 'En construction';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Row(
        children: [
          // Score circulaire
          SizedBox(
            width: 72,
            height: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: color.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(value * 100).round()}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Fiabilité : ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withAlpha(60)),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  score >= 70
                      ? 'Vos prédictions sont très précises grâce à un historique solide.'
                      : score >= 40
                          ? 'Continuez à enregistrer pour améliorer la précision.'
                          : 'Enregistrez au moins 3 cycles pour des prédictions fiables.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PRÉDICTIONS ACTUELLES
  // ═══════════════════════════════════════

  Widget _buildCurrentPredictions({
    required int currentDay,
    required DateTime nextOvulation,
    required DateTime nextPeriod,
    required DateTime fertileStart,
    required DateTime fertileEnd,
    required int effectiveLength,
    required ColorScheme cs,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysToOvulation =
        DateTime(nextOvulation.year, nextOvulation.month, nextOvulation.day)
            .difference(today)
            .inDays;
    final daysToPeriod =
        DateTime(nextPeriod.year, nextPeriod.month, nextPeriod.day)
            .difference(today)
            .inDays;

    return Column(
      children: [
        // Jour du cycle
        _predictionTile(
          icon: Icons.today_rounded,
          color: cs.primary,
          title: 'Jour du cycle',
          value: 'Jour $currentDay / $effectiveLength',
          subtitle: _getCyclePhaseDescription(currentDay, effectiveLength),
          cs: cs,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _predictionMiniCard(
                icon: Icons.egg_rounded,
                color: const Color(0xFFFFCA28),
                title: 'Ovulation',
                value: daysToOvulation > 0
                    ? 'Dans $daysToOvulation j'
                    : daysToOvulation == 0
                        ? 'Aujourd\'hui'
                        : 'Passée',
                date: DateFormat('d MMM', 'fr_FR').format(nextOvulation),
                cs: cs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _predictionMiniCard(
                icon: Icons.water_drop_rounded,
                color: const Color(0xFFEF5350),
                title: 'Prochaines règles',
                value: daysToPeriod > 0
                    ? 'Dans $daysToPeriod j'
                    : daysToPeriod == 0
                        ? 'Aujourd\'hui'
                        : 'En retard',
                date: DateFormat('d MMM', 'fr_FR').format(nextPeriod),
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _predictionTile(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFEC407A),
          title: 'Fenêtre de fertilité',
          value:
              '${DateFormat('d MMM', 'fr_FR').format(fertileStart)} → ${DateFormat('d MMM', 'fr_FR').format(fertileEnd)}',
          subtitle: '6 jours de fertilité maximale',
          cs: cs,
        ),
      ],
    );
  }

  Widget _predictionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionMiniCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String date,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(18), color.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text(date,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // CYCLE TIMELINE VISUEL
  // ═══════════════════════════════════════

  Widget _buildCycleTimeline({
    required int currentDay,
    required int effectiveLength,
    required int ovulationDay,
    required ColorScheme cs,
  }) {
    final progress = (currentDay / effectiveLength).clamp(0.0, 1.0);
    final ovulationProgress = (ovulationDay / effectiveLength).clamp(0.0, 1.0);
    final fertileStart = ((ovulationDay - 5) / effectiveLength).clamp(0.0, 1.0);
    final fertileEnd = ((ovulationDay + 1) / effectiveLength).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Progression du cycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Jour $currentDay/$effectiveLength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barre de timeline
          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Fond
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Zone fertile
                    Positioned(
                      top: 14,
                      left: width * fertileStart,
                      width: width * (fertileEnd - fertileStart),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC407A).withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Progression
                    Positioned(
                      top: 14,
                      left: 0,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Container(
                          height: 12,
                          width: width * value,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.withAlpha(180),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    // Marqueur ovulation
                    Positioned(
                      top: 6,
                      left: width * ovulationProgress - 14,
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCA28).withAlpha(40),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFFFCA28), width: 2),
                            ),
                            child: const Text('🥚',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Légende
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendDot(cs.primary, 'Progression', cs),
              _legendDot(
                  const Color(0xFFEC407A), 'Zone fertile', cs),
              _legendDot(
                  const Color(0xFFFFCA28), 'Ovulation', cs),
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
  // ANALYSE DES DONNÉES
  // ═══════════════════════════════════════

  Widget _buildDataAnalysis(
      _PredictionData data, int effectiveLength, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dataItem(
                  'Durée utilisée',
                  '$effectiveLength jours',
                  Icons.straighten_rounded,
                  const Color(0xFF42A5F5),
                  cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dataItem(
                  'Cycles analysés',
                  '${data.completedCount}',
                  Icons.analytics_rounded,
                  const Color(0xFF7E57C2),
                  cs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dataItem(
                  'Plage',
                  data.minLength != null
                      ? '${data.minLength}–${data.maxLength} j'
                      : '-- j',
                  Icons.swap_horiz_rounded,
                  const Color(0xFFFF7043),
                  cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dataItem(
                  'Variabilité',
                  data.stdDeviation != null
                      ? '± ${data.stdDeviation!.toStringAsFixed(1)} j'
                      : '-- j',
                  Icons.show_chart_rounded,
                  const Color(0xFF26A69A),
                  cs,
                ),
              ),
            ],
          ),
          if (data.cycleLengths.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant.withAlpha(50), height: 1),
            const SizedBox(height: 14),
            // Mini bar chart des durées
            _buildMiniBarChart(data.cycleLengths, cs),
          ],
        ],
      ),
    );
  }

  Widget _dataItem(
      String label, String value, IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMiniBarChart(List<int> lengths, ColorScheme cs) {
    final last = lengths.take(8).toList().reversed.toList();
    if (last.isEmpty) return const SizedBox.shrink();
    final maxVal = last.reduce((a, b) => a > b ? a : b).toDouble();
    final minVal = last.reduce((a, b) => a < b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Derniers cycles enregistrés',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: last.asMap().entries.map((entry) {
              final val = entry.value.toDouble();
              final height = maxVal > 0 ? (val / maxVal * 50).clamp(8.0, 50.0) : 8.0;
              final isMin = val == minVal && last.where((l) => l == minVal.toInt()).length == 1;
              final isMax = val == maxVal && last.where((l) => l == maxVal.toInt()).length == 1;
              final color = isMin
                  ? const Color(0xFFEF5350)
                  : isMax
                      ? const Color(0xFF66BB6A)
                      : cs.primary;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: color.withAlpha(180),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // ALGORITHME — COMMENT ÇA MARCHE
  // ═══════════════════════════════════════

  Widget _buildAlgorithmExplanation(_PredictionData data, ColorScheme cs) {
    return Column(
      children: [
        _AlgoStepCard(
          step: '1',
          icon: Icons.analytics_rounded,
          color: const Color(0xFF42A5F5),
          title: 'Collecte des données',
          description:
              'CycleTrack enregistre la date de début et de fin de chaque cycle pour calculer sa durée exacte.',
          detail: data.completedCount > 0
              ? '${data.completedCount} cycle${data.completedCount > 1 ? 's' : ''} dans votre historique'
              : 'Aucun cycle terminé pour le moment',
        ),
        const SizedBox(height: 10),
        _AlgoStepCard(
          step: '2',
          icon: Icons.filter_alt_rounded,
          color: const Color(0xFFFF7043),
          title: 'Filtrage intelligent',
          description:
              'Les cycles anormalement courts (<21j) ou longs (>35j) sont écartés pour ne pas fausser la moyenne.',
          detail: 'Seuls les cycles fiables sont retenus',
        ),
        const SizedBox(height: 10),
        _AlgoStepCard(
          step: '3',
          icon: Icons.calculate_rounded,
          color: const Color(0xFF7E57C2),
          title: 'Calcul de la moyenne',
          description:
              'La durée moyenne de vos cycles valides détermine la base de toutes les prédictions.',
          detail: data.avgCycleLength != null
              ? 'Votre moyenne : ${data.avgCycleLength!.round()} jours'
              : 'Utilise la valeur par défaut : ${data.settings.defaultCycleLength}j',
        ),
        const SizedBox(height: 10),
        _AlgoStepCard(
          step: '4',
          icon: Icons.egg_rounded,
          color: const Color(0xFFFFCA28),
          title: 'Estimation de l\'ovulation',
          description:
              'L\'ovulation est estimée à 14 jours avant la fin du cycle (phase lutéale standard).',
          detail:
              'Jour d\'ovulation estimé : J${(data.avgCycleLength?.round() ?? data.settings.defaultCycleLength) - 14}',
        ),
        const SizedBox(height: 10),
        _AlgoStepCard(
          step: '5',
          icon: Icons.favorite_rounded,
          color: const Color(0xFFEC407A),
          title: 'Fenêtre de fertilité',
          description:
              'La fenêtre fertile s\'étend de 5 jours avant l\'ovulation à 1 jour après, soit 6 jours au total.',
          detail: 'Pic de fertilité : jour de l\'ovulation',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // PHASES DU CYCLE — ÉDUCATION
  // ═══════════════════════════════════════

  Widget _buildPhasesEducation(int effectiveLength, ColorScheme cs) {
    final ovulationDay = effectiveLength - 14;
    final phases = [
      _PhaseInfo(
        emoji: '🔴',
        name: 'Menstruelle',
        days: 'J1 – J5',
        color: const Color(0xFFEF5350),
        description: 'Début du cycle. L\'utérus élimine sa muqueuse. Période de repos et d\'introspection.',
        tips: 'Reposez-vous, hydratez-vous bien, évitez les efforts intenses.',
      ),
      _PhaseInfo(
        emoji: '🌱',
        name: 'Folliculaire',
        days: 'J6 – J${ovulationDay - 1}',
        color: const Color(0xFF66BB6A),
        description: 'Les hormones augmentent, l\'énergie revient. Phase de renouveau et de créativité.',
        tips: 'Période idéale pour de nouveaux projets et l\'exercice physique.',
      ),
      _PhaseInfo(
        emoji: '🥚',
        name: 'Ovulation',
        days: 'J$ovulationDay – J${ovulationDay + 1}',
        color: const Color(0xFFFFCA28),
        description: 'L\'ovule est libéré. Pic d\'énergie, de confiance et de fertilité maximale.',
        tips: 'Votre pic de fertilité. Énergie et sociabilité au maximum.',
      ),
      _PhaseInfo(
        emoji: '🌙',
        name: 'Lutéale',
        days: 'J${ovulationDay + 2} – J$effectiveLength',
        color: const Color(0xFFAB47BC),
        description: 'Préparation à un nouveau cycle. Le SPM peut apparaître en fin de phase.',
        tips: 'Écoutez votre corps, privilégiez le calme et le sommeil.',
      ),
    ];

    return Column(
      children: phases.map((phase) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PhaseCard(phase: phase),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════
  // CONSEILS
  // ═══════════════════════════════════════

  Widget _buildTipsSection(_PredictionData data, ColorScheme cs) {
    final tips = <_TipItem>[];

    if (data.completedCount < 3) {
      tips.add(_TipItem(
        '📝',
        'Enregistrez régulièrement',
        'Il faut au moins 3 cycles complets pour des prédictions fiables. Continuez !',
        const Color(0xFF42A5F5),
      ));
    }
    if (data.completedCount >= 3 && data.completedCount < 6) {
      tips.add(_TipItem(
        '📈',
        'Vous progressez !',
        'Avec ${data.completedCount} cycles, vos prédictions s\'améliorent. L\'idéal est 6 cycles ou plus.',
        const Color(0xFF66BB6A),
      ));
    }
    if (data.stdDeviation != null && data.stdDeviation! > 4) {
      tips.add(_TipItem(
        '⚡',
        'Cycles irréguliers détectés',
        'Votre variabilité est élevée (±${data.stdDeviation!.toStringAsFixed(1)}j). C\'est normal, mais les prédictions seront moins précises.',
        const Color(0xFFFF7043),
      ));
    }

    tips.addAll([
      _TipItem(
        '💡',
        'Notez les symptômes',
        'Vos symptômes quotidiens aident à mieux comprendre votre corps et valider les prédictions.',
        const Color(0xFF7E57C2),
      ),
      _TipItem(
        '⚕️',
        'Rappel médical',
        'Ces prédictions sont des estimations basées sur vos données. Elles ne remplacent pas un avis médical professionnel.',
        const Color(0xFFEF5350),
      ),
    ]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withAlpha(40),
            cs.tertiaryContainer.withAlpha(20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withAlpha(30)),
      ),
      child: Column(
        children: tips.asMap().entries.map((entry) {
          final tip = entry.value;
          final isLast = entry.key == tips.length - 1;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tip.color.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(tip.emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tip.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Divider(
                    color: cs.outlineVariant.withAlpha(40), height: 20),
            ],
          );
        }).toList(),
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

  String _getCyclePhaseDescription(int day, int length) {
    final ovDay = length - 14;
    if (day <= 5) return 'Phase menstruelle';
    if (day < ovDay - 1) return 'Phase folliculaire';
    if (day <= ovDay + 1) return 'Ovulation';
    return 'Phase lutéale';
  }
}

// ═══════════════════════════════════════════════════
// ALGO STEP CARD (étapes de l'algorithme)
// ═══════════════════════════════════════════════════

class _AlgoStepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String detail;

  const _AlgoStepCard({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withAlpha(30)),
                  ),
                  child: Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PHASE CARD (éducation sur les phases)
// ═══════════════════════════════════════════════════

class _PhaseCard extends StatefulWidget {
  final _PhaseInfo phase;
  const _PhaseCard({required this.phase});

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      _expanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.phase;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _expanded ? p.color.withAlpha(12) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded ? p.color.withAlpha(60) : cs.outlineVariant.withAlpha(60),
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(p.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _expanded ? p.color : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.days,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: _expanded ? p.color : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizeTransition(
                sizeFactor: _animation,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: p.color.withAlpha(30), height: 1),
                      const SizedBox(height: 12),
                      Text(
                        p.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.color.withAlpha(15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.color.withAlpha(30)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 16, color: p.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.tips,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.color,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════

class _PredictionData {
  final AppSettings settings;
  final double? avgCycleLength;
  final Cycle? activeCycle;
  final int completedCount;
  final List<int> cycleLengths;
  final double? stdDeviation;
  final int? minLength;
  final int? maxLength;
  final int reliabilityScore;

  _PredictionData({
    required this.settings,
    this.avgCycleLength,
    this.activeCycle,
    required this.completedCount,
    required this.cycleLengths,
    this.stdDeviation,
    this.minLength,
    this.maxLength,
    required this.reliabilityScore,
  });
}

class _PhaseInfo {
  final String emoji;
  final String name;
  final String days;
  final Color color;
  final String description;
  final String tips;

  const _PhaseInfo({
    required this.emoji,
    required this.name,
    required this.days,
    required this.color,
    required this.description,
    required this.tips,
  });
}

class _TipItem {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  const _TipItem(this.emoji, this.title, this.description, this.color);
}


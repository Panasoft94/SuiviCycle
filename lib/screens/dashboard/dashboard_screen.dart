import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../models/settings.dart';
import '../../models/symptom.dart';
import '../../services/notification_service.dart';
import '../../utils/string_extensions.dart';
import '../symptom/symptom_screen.dart';
import '../cycles/cycle_history_screen.dart';
import '../cycles/prediction_details_screen.dart';
import '../stats/stats_screen.dart';
import '../hydration/hydration_screen.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════════
// DASHBOARD SCREEN — TABLEAU DE BORD PRINCIPAL
// ═══════════════════════════════════════════

class DashboardData {
  final Cycle? currentCycle;
  final AppSettings settings;
  final double? avgCycleLength;
  final double? avgPeriodLength;
  final Symptom? todaysSymptom;
  final double todayHydration;
  final int totalCycles;

  DashboardData(
    this.currentCycle,
    this.settings,
    this.avgCycleLength,
    this.avgPeriodLength,
    this.todaysSymptom,
    this.todayHydration,
    this.totalCycles,
  );
}

class _PhaseConfig {
  final String label;
  final String emoji;
  final Color color;
  final String advice;
  final IconData icon;

  const _PhaseConfig({
    required this.label,
    required this.emoji,
    required this.color,
    required this.advice,
    required this.icon,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  Cycle? _currentCycle;
  int _currentDayOfCycle = 0;
  late Future<DashboardData> _initialDataFuture;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Map<String, _PhaseConfig> _phaseConfigs = {
    'règles': _PhaseConfig(
      label: 'Règles',
      emoji: '🩸',
      color: Color(0xFFE53935),
      advice:
          'Privilégiez le repos et les aliments riches en fer comme les épinards ou les lentilles.',
      icon: Icons.spa_rounded,
    ),
    'folliculaire': _PhaseConfig(
      label: 'Folliculaire',
      emoji: '🌱',
      color: Color(0xFFFB8C00),
      advice:
          'Votre énergie remonte ! C\'est le moment idéal pour de nouveaux projets ou du sport intensif.',
      icon: Icons.bolt_rounded,
    ),
    'ovulation': _PhaseConfig(
      label: 'Ovulation',
      emoji: '🌸',
      color: Color(0xFFE91E63),
      advice:
          'Pic de libido et de confiance en soi. Votre peau est souvent plus éclatante !',
      icon: Icons.auto_awesome_rounded,
    ),
    'lutéale': _PhaseConfig(
      label: 'Lutéale',
      emoji: '🌙',
      color: Color(0xFF7E57C2),
      advice:
          'Réduisez le sel et la caféine pour limiter les ballonnements et l\'irritabilité.',
      icon: Icons.self_improvement_rounded,
    ),
  };

  static const _PhaseConfig _defaultPhaseConfig = _PhaseConfig(
    label: 'En attente',
    emoji: '✨',
    color: Color(0xFF78909C),
    advice:
        'Continuez à noter vos symptômes pour des conseils plus personnalisés.',
    icon: Icons.lightbulb_rounded,
  );

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _initialDataFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════
  // DATA LOADING (logique inchangée)
  // ═══════════════════════════════

  Future<DashboardData> _loadInitialData() async {
    _animationController.reset();

    final cycles = await _dbHelper.getCycles();
    final settings = await _dbHelper.getSettings();
    final avgCycleLength = await _dbHelper.getAverageCycleLength();
    final todayHydration = await _dbHelper.getTodayTotalHydration();

    double? avgPeriodLength;
    final periodCycles =
        cycles.where((c) => c.periodEndDate != null).toList();
    if (periodCycles.isNotEmpty) {
      avgPeriodLength = periodCycles
              .map((c) =>
                  c.periodEndDate!.difference(c.startDate).inDays + 1)
              .reduce((a, b) => a + b) /
          periodCycles.length;
    }

    Symptom? todaysSymptom;
    if (cycles.isNotEmpty && cycles.first.id != null) {
      final symptoms =
          await _dbHelper.getSymptomsForCycle(cycles.first.id!);
      final now = DateTime.now();
      try {
        todaysSymptom = symptoms.firstWhere(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        );
      } catch (_) {
        todaysSymptom = null;
      }
    }

    Cycle? activeCycle;
    activeCycle = cycles.cast<Cycle?>().firstWhere(
          (cycle) => cycle?.endDate == null,
          orElse: () => null,
        );

    _currentCycle = activeCycle;

    if (_currentCycle != null) {
      await _updateCyclePredictions(settings);
      _calculateCycleDay();
    }

    if (mounted) _animationController.forward();
    _checkIfPeriodIsDue();

    return DashboardData(
      _currentCycle,
      settings,
      avgCycleLength,
      avgPeriodLength,
      todaysSymptom,
      todayHydration,
      cycles.length,
    );
  }

  Future<void> _refreshData() async {
    final data = await _loadInitialData();
    if (mounted) {
      setState(() {
        _currentCycle = data.currentCycle;
      });
    }
  }

  void _calculateCycleDay() {
    if (_currentCycle != null) {
      final now = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final startDate = DateTime(_currentCycle!.startDate.year,
          _currentCycle!.startDate.month, _currentCycle!.startDate.day);
      _currentDayOfCycle = now.difference(startDate).inDays + 1;
    }
  }

  // ═══════════════════════════════════════
  // CYCLE PREDICTIONS & NOTIFICATIONS
  // (logique 100% inchangée)
  // ═══════════════════════════════════════

  Future<void> _updateCyclePredictions(AppSettings settings) async {
    final avgCycleLength = await _dbHelper.getAverageCycleLength();

    if (_currentCycle != null && _currentCycle!.endDate == null) {
      // Calcul robuste : on utilise les écarts réels entre dates de début
      // de cycles consécutifs (indépendant des valeurs stockées en DB qui
      // peuvent être incorrectes à cause du bug Jour0).
      int cycleLength = avgCycleLength?.round() ?? settings.defaultCycleLength;
      try {
        final allCycles = await _dbHelper.getCycles();
        // Trier par date de début croissante
        allCycles.sort((a, b) => a.startDate.compareTo(b.startDate));
        if (allCycles.length >= 2) {
          final lengths = <int>[];
          for (int i = 0; i < allCycles.length - 1; i++) {
            final s = DateTime(
              allCycles[i].startDate.year,
              allCycles[i].startDate.month,
              allCycles[i].startDate.day,
            );
            final n = DateTime(
              allCycles[i + 1].startDate.year,
              allCycles[i + 1].startDate.month,
              allCycles[i + 1].startDate.day,
            );
            final diff = n.difference(s).inDays;
            // Filtrer les valeurs aberrantes (< 15 ou > 60 jours)
            if (diff >= 15 && diff <= 60) lengths.add(diff);
          }
          if (lengths.isNotEmpty) {
            final sumLengths = lengths.reduce((a, b) => a + b);
            cycleLength = (sumLengths / lengths.length).round();
          }
        }
      } catch (_) {
        // En cas d'erreur, on garde la valeur déjà calculée
      }

      DateTime? ovulationDate;
      if (cycleLength > 15) {
        ovulationDate =
            _currentCycle!.startDate.add(Duration(days: cycleLength - 14));
      }

      final expectedPeriod =
          _currentCycle!.startDate.add(Duration(days: cycleLength));

      String phase = 'folliculaire';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (_currentCycle!.periodEndDate != null) {
        final periodEnd = DateTime(
          _currentCycle!.periodEndDate!.year,
          _currentCycle!.periodEndDate!.month,
          _currentCycle!.periodEndDate!.day,
        );
        if (today.isAfter(periodEnd)) {
          if (ovulationDate != null) {
            final ovulDay = DateTime(
                ovulationDate.year, ovulationDate.month, ovulationDate.day);
            if (today.isAfter(ovulDay)) {
              phase = 'lutéale';
            } else if (today.isAtSameMomentAs(ovulDay)) {
              phase = 'ovulation';
            } else {
              phase = 'folliculaire';
            }
          } else {
            phase = 'folliculaire';
          }
        } else {
          phase = 'règles';
        }
      } else {
        phase = 'règles';
      }

      final updatedCycle = Cycle(
        id: _currentCycle!.id,
        startDate: _currentCycle!.startDate,
        periodEndDate: _currentCycle!.periodEndDate,
        cycleLength: cycleLength,
        ovulationDate: ovulationDate,
        expectedPeriod: expectedPeriod,
        phase: phase,
      );
      await _dbHelper.updateCycle(updatedCycle);
      _currentCycle = updatedCycle;

      if (_notificationService.isReady) {
        await _notificationService.cancelAllNotifications();

        if (settings.notifyOvulation && ovulationDate != null) {
          await _notificationService.scheduleNotification(
            id: 10,
            title: '🌸 Ovulation dans 3 jours',
            body:
                'Votre ovulation est prévue dans 3 jours. Votre fenêtre de fertilité approche.',
            scheduledDate: ovulationDate.subtract(const Duration(days: 3)),
          );
          await _notificationService.scheduleNotification(
            id: 11,
            title: '🌸 Ovulation dans 2 jours',
            body: 'Votre ovulation est prévue dans 2 jours.',
            scheduledDate: ovulationDate.subtract(const Duration(days: 2)),
          );
          await _notificationService.scheduleNotification(
            id: 12,
            title: '🌸 Ovulation demain',
            body:
                'Votre ovulation est prévue demain. Début de votre pic de fertilité.',
            scheduledDate: ovulationDate.subtract(const Duration(days: 1)),
          );
          await _notificationService.scheduleNotification(
            id: 13,
            title: '🌸 Jour d\'ovulation',
            body:
                'C\'est votre jour d\'ovulation prévu. Votre fertilité est à son maximum.',
            scheduledDate: ovulationDate,
          );
        }

        if (settings.notifyPeriod) {
          await _notificationService.scheduleNotification(
            id: 20,
            title: '🔴 Règles dans 3 jours',
            body:
                'Vos prochaines règles sont prévues dans 3 jours. Pensez à vous préparer.',
            scheduledDate:
                expectedPeriod.subtract(const Duration(days: 3)),
          );
          await _notificationService.scheduleNotification(
            id: 21,
            title: '🔴 Règles dans 2 jours',
            body: 'Vos prochaines règles sont prévues dans 2 jours.',
            scheduledDate:
                expectedPeriod.subtract(const Duration(days: 2)),
          );
          await _notificationService.scheduleNotification(
            id: 22,
            title: '🔴 Règles demain',
            body:
                'Vos prochaines règles sont prévues demain. Préparez-vous.',
            scheduledDate:
                expectedPeriod.subtract(const Duration(days: 1)),
          );
          await _notificationService.scheduleNotification(
            id: 23,
            title: '🔴 Début de cycle prévu',
            body:
                'Vos règles sont prévues pour aujourd\'hui. Un nouveau cycle peut commencer.',
            scheduledDate: expectedPeriod,
          );
        }
      }
    }
  }

  void _checkIfPeriodIsDue() {
    if (_currentCycle != null && _currentCycle!.expectedPeriod != null) {
      final now = DateTime.now();
      final difference =
          _currentCycle!.expectedPeriod!.difference(now).inDays;
      if (difference <= 2 && difference >= -2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPeriodStartPrompt(context);
        });
      }
    }
  }

  _PhaseConfig _getPhaseConfig() {
    final phase = _currentCycle?.phase ?? '';
    return _phaseConfigs[phase] ?? _defaultPhaseConfig;
  }

  String _getMoodEmoji(String? mood) {
    const moods = {
      'Heureuse': '😊',
      'Triste': '😢',
      'En colère': '😡',
      'Anxieuse': '😰',
      'Calme': '😌',
      'Énergique': '⚡',
    };
    return moods[mood] ?? '🙂';
  }

  // ═══════════════════════════════
  // BUILD
  // ═══════════════════════════════

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement...',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(150),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      "Erreur de chargement",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text("Aucune donnée disponible.")),
          );
        }

        final data = snapshot.data!;
        return Scaffold(
          body: _buildDashboardContent(data),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  // ═══════════════════════════════
  // CONTENU PRINCIPAL
  // ═══════════════════════════════

  Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // AppBar avec salutation
          _buildSliverHeader(data),
          // Contenu
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Alerte règles imminentes
                _buildDueDateNotification(),
                // Carte cycle principale
                _buildAnimatedEntry(
                  delay: 0,
                  child: _currentCycle != null
                      ? _buildCycleHeroCard()
                      : _buildNoCycleCard(),
                ),
                const SizedBox(height: 20),
                // Timeline / Phase actuelle
                if (_currentCycle != null)
                  _buildAnimatedEntry(
                    delay: 1,
                    child: _buildPhaseTimeline(),
                  ),
                if (_currentCycle != null) const SizedBox(height: 20),
                // Prochaines étapes
                if (_currentCycle != null)
                  _buildAnimatedEntry(
                    delay: 2,
                    child: _buildUpcomingDatesCard(),
                  ),
                if (_currentCycle != null) const SizedBox(height: 20),
                // Conseil bien-être
                if (_currentCycle != null)
                  _buildAnimatedEntry(
                    delay: 3,
                    child: _buildPhaseAdviceCard(),
                  ),
                if (_currentCycle != null) const SizedBox(height: 20),
                // Résumé aujourd'hui (symptôme + hydratation)
                _buildAnimatedEntry(
                  delay: 4,
                  child: _buildTodaySummaryRow(data),
                ),
                const SizedBox(height: 20),
                // Stats rapides
                if (data.avgCycleLength != null)
                  _buildAnimatedEntry(
                    delay: 5,
                    child: _buildQuickStatsRow(data),
                  ),
                if (data.avgCycleLength != null)
                  const SizedBox(height: 24),
                // Section actions
                _buildAnimatedEntry(
                  delay: 6,
                  child: _buildSectionHeader(
                      'Actions & Outils', Icons.apps_rounded),
                ),
                const SizedBox(height: 12),
                _buildAnimatedEntry(
                  delay: 7,
                  child: _buildFeatureGrid(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  // SLIVER HEADER
  // ═══════════════════════════════

  Widget _buildSliverHeader(DashboardData data) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 16,
            20,
            20,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting 👋',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(now).capitalize(),
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withAlpha(140),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge cycle
              if (_currentCycle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getPhaseConfig().color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getPhaseConfig().color.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getPhaseConfig().emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'J$_currentDayOfCycle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _getPhaseConfig().color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════
  // ANIMATION D'ENTRÉE
  // ═══════════════════════════════

  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (delay * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════
  // HERO CARD – CYCLE ACTIF
  // ═══════════════════════════════

  Widget _buildCycleHeroCard() {
    final cs = Theme.of(context).colorScheme;
    final phaseConfig = _getPhaseConfig();

    if (_currentDayOfCycle < 1) {
      return _buildScheduledCycleCard();
    }

    final cycleLength = _currentCycle?.cycleLength ?? 28;
    final progress = (_currentDayOfCycle / cycleLength).clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: () {
        if (_currentCycle != null) {
          _showDeleteCycleConfirmation(context, _currentCycle!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              phaseConfig.color,
              phaseConfig.color.withAlpha(180),
              cs.primary.withAlpha(200),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: phaseConfig.color.withAlpha(60),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Cercle de progression
              SizedBox(
                width: 140,
                height: 140,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _CycleProgressPainter(
                        progress: value,
                        bgColor: Colors.white.withAlpha(40),
                        progressColor: Colors.white,
                        strokeWidth: 8,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'JOUR',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              '$_currentDayOfCycle',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'sur $cycleLength',
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Badge phase
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(phaseConfig.emoji,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'Phase ${phaseConfig.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Infos rapides
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHeroInfoItem(
                        Icons.calendar_today_rounded,
                        'Début',
                        DateFormat('dd MMM', 'fr_FR')
                            .format(_currentCycle!.startDate),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withAlpha(30),
                    ),
                    Expanded(
                      child: _buildHeroInfoItem(
                        Icons.favorite_rounded,
                        'Ovulation',
                        _currentCycle!.ovulationDate != null
                            ? DateFormat('dd MMM', 'fr_FR')
                                .format(_currentCycle!.ovulationDate!)
                            : '—',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withAlpha(30),
                    ),
                    Expanded(
                      child: _buildHeroInfoItem(
                        Icons.event_rounded,
                        'Fin prévue',
                        _currentCycle!.expectedPeriod != null
                            ? DateFormat('dd MMM', 'fr_FR')
                                .format(_currentCycle!.expectedPeriod!)
                            : '—',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(180), size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(160),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // Carte cycle programmé (futur)
  Widget _buildScheduledCycleCard() {
    final cs = Theme.of(context).colorScheme;
    final daysUntilStart = -_currentDayOfCycle + 1;
    final countdownText = daysUntilStart == 1
        ? 'Commence demain'
        : 'Commence dans $daysUntilStart jours';

    return GestureDetector(
      onLongPress: () =>
          _showDeleteCycleConfirmation(context, _currentCycle!),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withAlpha(80),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.primary.withAlpha(40)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.schedule_rounded,
                  color: cs.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Cycle Programmé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                countdownText,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Début le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_currentCycle!.startDate)}',
              style: TextStyle(
                color: cs.onSurface.withAlpha(160),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════
  // PHASE TIMELINE
  // ═══════════════════════════════

  Widget _buildPhaseTimeline() {
    final cs = Theme.of(context).colorScheme;
    final phases = ['règles', 'folliculaire', 'ovulation', 'lutéale'];
    final currentPhase = _currentCycle?.phase ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Progression du cycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: phases.asMap().entries.map((entry) {
              final index = entry.key;
              final phase = entry.value;
              final config = _phaseConfigs[phase]!;
              final isActive = phase == currentPhase;
              final isPast =
                  phases.indexOf(currentPhase) > index;

              return Expanded(
                child: Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isPast || isActive
                                ? config.color.withAlpha(150)
                                : cs.outlineVariant.withAlpha(60),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: isActive ? 40 : 32,
                          height: isActive ? 40 : 32,
                          decoration: BoxDecoration(
                            color: isActive
                                ? config.color
                                : isPast
                                    ? config.color.withAlpha(40)
                                    : cs.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: isActive
                                ? Border.all(
                                    color: config.color.withAlpha(60),
                                    width: 3,
                                  )
                                : null,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          config.color.withAlpha(50),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              config.emoji,
                              style: TextStyle(
                                fontSize: isActive ? 18 : 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          config.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? config.color
                                : cs.onSurface.withAlpha(100),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  // NOTIFICATION ALERTE
  // ═══════════════════════════════

  Widget _buildDueDateNotification() {
    if (_currentCycle != null &&
        _currentCycle!.expectedPeriod != null) {
      final now = DateTime.now();
      final difference =
          _currentCycle!.expectedPeriod!.difference(now).inDays;

      if (difference >= -2 && difference <= 2) {
        final cs = Theme.of(context).colorScheme;
        String dayString = "imminentes";
        if (difference == 0) {
          dayString = "aujourd'hui";
        } else if (difference == 1) {
          dayString = "demain";
        } else if (difference > 1) {
          dayString = "dans $difference jours";
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.errorContainer.withAlpha(200),
                  cs.errorContainer.withAlpha(120),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.error.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.error.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      color: cs.error, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerte cycle',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Prochaines règles attendues $dayString.",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: cs.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════
  // PROCHAINES ÉTAPES
  // ═══════════════════════════════

  Widget _buildUpcomingDatesCard() {
    final cs = Theme.of(context).colorScheme;
    if (_currentCycle == null) return const SizedBox.shrink();

    final items = <Widget>[];

    if (_currentCycle!.ovulationDate != null) {
      final daysUntil = _currentCycle!.ovulationDate!
          .difference(DateTime.now())
          .inDays;
      items.add(_buildUpcomingRow(
        '🌸',
        'Ovulation',
        DateFormat('dd MMM', 'fr_FR')
            .format(_currentCycle!.ovulationDate!),
        daysUntil >= 0 ? 'dans $daysUntil j' : 'passée',
        const Color(0xFFE91E63),
      ));
    }
    if (_currentCycle!.expectedPeriod != null) {
      final daysUntil = _currentCycle!.expectedPeriod!
          .difference(DateTime.now())
          .inDays;
      if (items.isNotEmpty) items.add(const SizedBox(height: 12));
      items.add(_buildUpcomingRow(
        '📅',
        'Prochain cycle',
        DateFormat('dd MMM', 'fr_FR')
            .format(_currentCycle!.expectedPeriod!),
        daysUntil >= 0 ? 'dans $daysUntil j' : 'en retard',
        const Color(0xFFE53935),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Prochaines étapes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildUpcomingRow(
    String emoji,
    String title,
    String date,
    String countdown,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              countdown,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  // CONSEIL BIEN-ÊTRE
  // ═══════════════════════════════

  Widget _buildPhaseAdviceCard() {
    final cs = Theme.of(context).colorScheme;
    final config = _getPhaseConfig();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withAlpha(18),
            config.color.withAlpha(8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: config.color.withAlpha(35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config.color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(config.icon, color: config.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conseil bien-être',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: config.color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  config.advice,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withAlpha(200),
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

  // ═══════════════════════════════
  // RÉSUMÉ AUJOURD'HUI
  // ═══════════════════════════════

  Widget _buildTodaySummaryRow(DashboardData data) {
    return Row(
      children: [
        Expanded(child: _buildTodaySymptomCard(data.todaysSymptom)),
        const SizedBox(width: 12),
        Expanded(child: _buildTodayHydrationCard(data.todayHydration)),
      ],
    );
  }

  Widget _buildTodaySymptomCard(Symptom? symptom) {
    final cs = Theme.of(context).colorScheme;
    final hasMood = symptom?.mood != null;

    return GestureDetector(
      onTap: () {
        if (_currentCycle != null && _currentCycle!.id != null) {
          Navigator.push(
            context,
            slideTransition(
                SymptomScreen(cycleId: _currentCycle!.id!)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          color: hasMood
              ? cs.primaryContainer.withAlpha(50)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasMood
                ? cs.primary.withAlpha(40)
                : cs.outlineVariant.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  hasMood ? _getMoodEmoji(symptom!.mood) : '📝',
                  style: const TextStyle(fontSize: 22),
                ),
                const Spacer(),
                if (hasMood)
                  Icon(Icons.check_circle_rounded,
                      color: cs.primary, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              hasMood ? symptom!.mood! : 'Humeur',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              hasMood ? "Aujourd'hui" : 'Non renseignée',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHydrationCard(double todayHydration) {
    final cs = Theme.of(context).colorScheme;
    final goalReached = todayHydration >= 2.0;
    final progress = (todayHydration / 2.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        slideTransition(const HydrationScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          color: goalReached
              ? const Color(0xFF4CAF50).withAlpha(20)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: goalReached
                ? const Color(0xFF4CAF50).withAlpha(40)
                : cs.outlineVariant.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  goalReached ? '✅' : '💧',
                  style: const TextStyle(fontSize: 22),
                ),
                const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: cs.outlineVariant.withAlpha(50),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goalReached
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${todayHydration.toStringAsFixed(1)} L',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              goalReached ? 'Objectif atteint !' : 'sur 2.0 L',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════
  // QUICK STATS
  // ═══════════════════════════════

  Widget _buildQuickStatsRow(DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            '🔄',
            'Cycle moyen',
            '${data.avgCycleLength?.round() ?? "--"} j',
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            '🩸',
            'Règles moy.',
            '${data.avgPeriodLength?.round() ?? "--"} j',
            const Color(0xFFE53935),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            '📊',
            'Total cycles',
            '${data.totalCycles}',
            const Color(0xFF7E57C2),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(
      String emoji, String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withAlpha(120),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════

  Widget _buildSectionHeader(String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════
  // FEATURE GRID
  // ═══════════════════════════════

  Widget _buildFeatureGrid() {
    final features = [
      _FeatureItem(
        icon: Icons.history_rounded,
        title: 'Historique',
        subtitle: 'Cycles précédents',
        color: const Color(0xFF5C6BC0),
        onTap: () => Navigator.push(
            context, slideTransition(const CycleHistoryScreen())),
      ),
      _FeatureItem(
        icon: Icons.edit_note_rounded,
        title: 'Symptômes',
        subtitle: 'Journal quotidien',
        color: const Color(0xFFEC407A),
        onTap: () {
          if (_currentCycle != null && _currentCycle!.id != null) {
            Navigator.push(
              context,
              slideTransition(
                  SymptomScreen(cycleId: _currentCycle!.id!)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    "Veuillez d'abord démarrer un cycle."),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
      _FeatureItem(
        icon: Icons.water_drop_rounded,
        title: 'Hydratation',
        subtitle: 'Suivi de l\'eau',
        color: const Color(0xFF29B6F6),
        onTap: () => Navigator.push(
            context, slideTransition(const HydrationScreen())),
      ),
      _FeatureItem(
        icon: Icons.bar_chart_rounded,
        title: 'Statistiques',
        subtitle: 'Graphiques',
        color: const Color(0xFF66BB6A),
        onTap: () => Navigator.push(
            context, slideTransition(const StatsScreen())),
      ),
      _FeatureItem(
        icon: Icons.smart_toy_rounded,
        title: 'Prédictions',
        subtitle: 'IA adaptative',
        color: const Color(0xFFAB47BC),
        onTap: () => Navigator.push(
            context,
            slideTransition(const PredictionDetailsScreen())),
      ),
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 80)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _buildFeatureTile(feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureTile(_FeatureItem feature) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: feature.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: cs.outlineVariant.withAlpha(50)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(feature.icon,
                      color: feature.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        feature.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: feature.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════
  // NO CYCLE CARD
  // ═══════════════════════════════

  Widget _buildNoCycleCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withAlpha(60),
            cs.secondaryContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withAlpha(30)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded,
                size: 40, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun cycle en cours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur le bouton ci-dessous\npour commencer votre suivi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withAlpha(140),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Démarrer un cycle',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════
  // FLOATING ACTION BUTTON
  // ═══════════════════════════════

  Widget? _buildFloatingActionButton() {
    final cs = Theme.of(context).colorScheme;
    bool isCycleActive =
        _currentCycle != null && _currentCycle!.endDate == null;

    if (!isCycleActive) {
      return FloatingActionButton.extended(
        onPressed: () async {
          final newStartDate = await _showStartCycleDialog(context);
          if (newStartDate != null) {
            await _startNewCycle(startDate: newStartDate);
          }
        },
        label: const Text(
          'Démarrer un cycle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      );
    }

    bool canEndPeriod = _currentCycle!.periodEndDate == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (canEndPeriod)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: FloatingActionButton.extended(
              onPressed: _endPeriod,
              label: const Text(
                'Fin des règles',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.check_rounded),
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              heroTag: 'endPeriod',
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        FloatingActionButton(
          onPressed: () => _showEndCycleConfirmation(context),
          backgroundColor: cs.errorContainer,
          foregroundColor: cs.onErrorContainer,
          elevation: 2,
          tooltip: 'Terminer le cycle actuel',
          heroTag: 'endCycle',
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.stop_rounded),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // DIALOGS (logique 100% inchangée)
  // ═══════════════════════════════════════

  Future<DateTime?> _showStartCycleDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();
    final cs = Theme.of(context).colorScheme;

    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: cs.primary, size: 24),
              const SizedBox(width: 10),
              const Text('Nouveau cycle',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    "Quelle est la date de début de vos règles ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(180),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime(DateTime.now().year - 5),
                        lastDate:
                            DateTime(DateTime.now().year + 5),
                      );
                      if (picked != null &&
                          picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMMM yyyy', 'fr_FR')
                                  .format(selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded,
                              color: cs.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler',
                  style: TextStyle(color: cs.onSurface.withAlpha(160))),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enregistrer'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selectedDate),
            ),
          ],
        );
      },
    );
  }

  void _showPeriodStartPrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Text('🩸', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text('Nouveau cycle ?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Vos règles ont-elles commencé ?',
            style: TextStyle(color: cs.onSurface.withAlpha(180)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Pas encore',
                  style: TextStyle(color: cs.onSurface.withAlpha(160))),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Choisir une date'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final newStartDate =
                    await _showStartCycleDialog(context);
                if (newStartDate != null) {
                  await _startNewCycle(startDate: newStartDate);
                }
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Oui, aujourd\'hui'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final now = DateTime.now();
                await _startNewCycle(
                    startDate: DateTime(now.year, now.month, now.day));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNewCycle({required DateTime startDate}) async {
    // Normaliser à minuit pour éviter les décalages d'heure (bug Jour0)
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);

    if (_currentCycle != null && _currentCycle!.endDate == null) {
      await _endCycle(
          isNewCycleStarting: true, newCycleStartDate: normalizedStart);
    }

    final settings = await _dbHelper.getSettings();
    final cycleLength = settings.defaultCycleLength;

    DateTime? ovulationDate;
    if (cycleLength > 15) {
      ovulationDate =
          normalizedStart.add(Duration(days: cycleLength - 14));
    }

    final expectedPeriod =
        normalizedStart.add(Duration(days: cycleLength));

    final newCycle = Cycle(
      startDate: normalizedStart,
      phase: 'règles',
      cycleLength: cycleLength,
      ovulationDate: ovulationDate,
      expectedPeriod: expectedPeriod,
    );
    await _dbHelper.insertCycle(newCycle);

    await _refreshData();
  }

  Future<void> _endCycle(
      {bool isNewCycleStarting = false,
      DateTime? newCycleStartDate}) async {
    if (_currentCycle != null) {
      // Normaliser les deux dates à minuit pour un calcul de durée exact (Jour1, pas Jour0)
      final startDateNorm = DateTime(
        _currentCycle!.startDate.year,
        _currentCycle!.startDate.month,
        _currentCycle!.startDate.day,
      );
      final now = DateTime.now();
      final DateTime cycleEndDate;
      if (newCycleStartDate != null) {
        final normNew = DateTime(
            newCycleStartDate.year,
            newCycleStartDate.month,
            newCycleStartDate.day);
        cycleEndDate = normNew.subtract(const Duration(days: 1));
      } else {
        cycleEndDate = DateTime(now.year, now.month, now.day);
      }
      final cycleLength =
          cycleEndDate.difference(startDateNorm).inDays + 1;

      final endedCycle = Cycle(
        id: _currentCycle!.id,
        startDate: _currentCycle!.startDate,
        endDate: cycleEndDate,
        periodEndDate: _currentCycle!.periodEndDate ?? cycleEndDate,
        cycleLength: cycleLength > 0 ? cycleLength : 1,
        phase: 'terminé',
        ovulationDate: _currentCycle!.ovulationDate,
        expectedPeriod: _currentCycle!.expectedPeriod,
      );
      await _dbHelper.updateCycle(endedCycle);

      if (!isNewCycleStarting) {
        await _refreshData();
      }
    }
  }

  void _endPeriod() async {
    if (_currentCycle != null) {
      final updatedCycle = Cycle.fromMap(_currentCycle!.toMap());
      final now = DateTime.now();
      // Normaliser à minuit
      final periodEnd = DateTime(now.year, now.month, now.day);
      final newCycle = Cycle(
        id: updatedCycle.id,
        startDate: updatedCycle.startDate,
        periodEndDate: periodEnd,
        endDate: updatedCycle.endDate,
        cycleLength: updatedCycle.cycleLength,
        ovulationDate: updatedCycle.ovulationDate,
        expectedPeriod: updatedCycle.expectedPeriod,
        phase: 'folliculaire',
      );
      await _dbHelper.updateCycle(newCycle);
      await _refreshData();
    }
  }

  void _showDeleteCycleConfirmation(
      BuildContext context, Cycle cycle) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: cs.error, size: 24),
              const SizedBox(width: 10),
              const Text('Supprimer ce cycle ?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Cette action est irréversible et supprimera toutes les données associées.',
            style: TextStyle(color: cs.onSurface.withAlpha(180)),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Supprimer'),
              onPressed: () async {
                await _dbHelper.deleteCycle(cycle.id!);
                Navigator.of(dialogContext).pop();
                await _refreshData();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEndCycleConfirmation(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.stop_circle_rounded,
                  color: cs.error, size: 24),
              const SizedBox(width: 10),
              const Text('Terminer le cycle',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Voulez-vous vraiment terminer le cycle actuel ?',
            style: TextStyle(color: cs.onSurface.withAlpha(180)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _endCycle();
              },
              child: const Text('Terminer'),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════
// CYCLE PROGRESS PAINTER
// ═══════════════════════════════

class _CycleProgressPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color progressColor;
  final double strokeWidth;

  _CycleProgressPainter({
    required this.progress,
    required this.bgColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // Small dot at the end
    if (progress > 0.02) {
      final dotAngle = -math.pi / 2 + 2 * math.pi * progress;
      final dotCenter = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle),
      );
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, strokeWidth * 0.7, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════
// FEATURE ITEM MODEL
// ═══════════════════════════════

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

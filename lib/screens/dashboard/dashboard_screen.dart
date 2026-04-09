import 'package:flutter/material.dart';
import 'dart:async';
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

// Classe de données pour le FutureBuilder
class DashboardData {
  final Cycle? currentCycle;
  final AppSettings settings;
  final double? avgCycleLength;
  final double? avgPeriodLength;
  final Symptom? todaysSymptom;
  DashboardData(this.currentCycle, this.settings, this.avgCycleLength, this.avgPeriodLength, this.todaysSymptom);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  Cycle? _currentCycle;
  int _currentDayOfCycle = 0;
  late Future<DashboardData> _initialDataFuture;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _initialDataFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

    Future<DashboardData> _loadInitialData() async {
    _animationController.reset();

    final cycles = await _dbHelper.getCycles();
    final settings = await _dbHelper.getSettings();
    final avgCycleLength = await _dbHelper.getAverageCycleLength();

    // Calculer la durée moyenne des règles manuellement car non dispo directement dans dbHelper pour dashboard
    double? avgPeriodLength;
    final periodCycles = cycles.where((c) => c.periodEndDate != null).toList();
    if (periodCycles.isNotEmpty) {
      avgPeriodLength = periodCycles.map((c) => c.periodEndDate!.difference(c.startDate).inDays + 1).reduce((a, b) => a + b) / periodCycles.length;
    }

    // Récupérer le symptôme d'aujourd'hui
    Symptom? todaysSymptom;
    if (cycles.isNotEmpty && cycles.first.id != null) {
      final symptoms = await _dbHelper.getSymptomsForCycle(cycles.first.id!);
      final now = DateTime.now();
      try {
        todaysSymptom = symptoms.firstWhere(
          (s) => s.date.year == now.year && s.date.month == now.month && s.date.day == now.day,
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

    return DashboardData(_currentCycle, settings, avgCycleLength, avgPeriodLength, todaysSymptom);
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
      final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final startDate = DateTime(_currentCycle!.startDate.year, _currentCycle!.startDate.month, _currentCycle!.startDate.day);
      _currentDayOfCycle = now.difference(startDate).inDays + 1;
    }
  }

  // MODIFICATION CRITIQUE ICI: Ajout de la vérification isReady
  Future<void> _updateCyclePredictions(AppSettings settings) async {
    final avgCycleLength = await _dbHelper.getAverageCycleLength();

    if (_currentCycle != null && _currentCycle!.endDate == null) {
      final cycleLength = avgCycleLength?.round() ?? settings.defaultCycleLength;

      DateTime? ovulationDate;
      if (cycleLength > 15) {
        ovulationDate = _currentCycle!.startDate.add(Duration(days: cycleLength - 14));
      }

      final expectedPeriod = _currentCycle!.startDate.add(Duration(days: cycleLength));

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
            final ovulDay = DateTime(ovulationDate.year, ovulationDate.month, ovulationDate.day);
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

      // Planification des notifications récursives
      // VÉRIFICATION DE SÉCURITÉ: Appel uniquement si le service est prêt
      if (_notificationService.isReady) {
        await _notificationService.cancelAllNotifications();

        // --- Notifications Ovulation (J-3, J-2, J-1, Jour J) ---
        if (settings.notifyOvulation && ovulationDate != null) {
          await _notificationService.scheduleNotification(
            id: 10,
            title: '🌸 Ovulation dans 3 jours',
            body: 'Votre ovulation est prévue dans 3 jours. Votre fenêtre de fertilité approche.',
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
            body: 'Votre ovulation est prévue demain. Début de votre pic de fertilité.',
            scheduledDate: ovulationDate.subtract(const Duration(days: 1)),
          );
          await _notificationService.scheduleNotification(
            id: 13,
            title: '🌸 Jour d\'ovulation',
            body: 'C\'est votre jour d\'ovulation prévu. Votre fertilité est à son maximum.',
            scheduledDate: ovulationDate,
          );
        }

        // --- Notifications Règles / Nouveau cycle (J-3, J-2, J-1, Jour J) ---
        if (settings.notifyPeriod) {
          await _notificationService.scheduleNotification(
            id: 20,
            title: '🔴 Règles dans 3 jours',
            body: 'Vos prochaines règles sont prévues dans 3 jours. Pensez à vous préparer.',
            scheduledDate: expectedPeriod.subtract(const Duration(days: 3)),
          );
          await _notificationService.scheduleNotification(
            id: 21,
            title: '🔴 Règles dans 2 jours',
            body: 'Vos prochaines règles sont prévues dans 2 jours.',
            scheduledDate: expectedPeriod.subtract(const Duration(days: 2)),
          );
          await _notificationService.scheduleNotification(
            id: 22,
            title: '🔴 Règles demain',
            body: 'Vos prochaines règles sont prévues demain. Préparez-vous.',
            scheduledDate: expectedPeriod.subtract(const Duration(days: 1)),
          );
          await _notificationService.scheduleNotification(
            id: 23,
            title: '🔴 Début de cycle prévu',
            body: 'Vos règles sont prévues pour aujourd\'hui. Un nouveau cycle peut commencer.',
            scheduledDate: expectedPeriod,
          );
        }
      }
    }
  }

  void _checkIfPeriodIsDue() {
    if (_currentCycle != null && _currentCycle!.expectedPeriod != null) {
      final now = DateTime.now();
      final difference = _currentCycle!.expectedPeriod!.difference(now).inDays;
      if (difference <= 2 && difference >= -2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPeriodStartPrompt(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Erreur de chargement: ${snapshot.error}")),
          );
        } else if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text("Aucune donnée disponible.")),
          );
        } else {
          final data = snapshot.data!;
          return Scaffold(
            body: _buildDashboardContent(data),
            floatingActionButton: _buildFloatingActionButton(),
          );
        }
      },
    );
  }

    Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        children: [
          _buildDueDateNotification(),
          if (_currentCycle != null) _buildCycleInfoCard() else _buildNoCycleCard(),
          const SizedBox(height: 24),
          if (_currentCycle != null) _buildUpcomingDatesCard(),
          const SizedBox(height: 24),
          if (_currentCycle != null) _buildPhaseAdviceCard(),
          const SizedBox(height: 24),
          if (data.todaysSymptom != null) _buildTodaySymptomSummary(data.todaysSymptom!),
          const SizedBox(height: 24),
          if (data.avgCycleLength != null) _buildQuickStatsRow(data),
          const SizedBox(height: 24),
          _buildSectionHeader('Actions & Outils'),
          const SizedBox(height: 12),
          _buildFeatureTiles(),
        ],
      ),
    );
    }

    Widget _buildUpcomingDatesCard() {
      final colorScheme = Theme.of(context).colorScheme;
      if (_currentCycle == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Prochaines étapes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            if (_currentCycle!.ovulationDate != null)
              _buildUpcomingRow(
                Icons.favorite_rounded,
                "Ovulation prévue",
                DateFormat('dd MMM', 'fr_FR').format(_currentCycle!.ovulationDate!),
                Colors.pink,
              ),
            if (_currentCycle!.ovulationDate != null && _currentCycle!.expectedPeriod != null)
              const Divider(height: 24, indent: 40),
            if (_currentCycle!.expectedPeriod != null)
              _buildUpcomingRow(
                Icons.calendar_today_rounded,
                "Prochain cycle",
                DateFormat('dd MMM', 'fr_FR').format(_currentCycle!.expectedPeriod!),
                Colors.red,
              ),
          ],
        ),
      );
    }

    Widget _buildUpcomingRow(IconData icon, String title, String date, Color color) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      );
    }

    Widget _buildTodaySymptomSummary(Symptom symptom) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withAlpha(40),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.primary.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Aujourd'hui", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Humeur : ${symptom.mood ?? 'Non précisée'}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (symptom.notes != null && symptom.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                symptom.notes!,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
    }

    Widget _buildQuickStatsRow(DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallStatCard(
            'Cycle moyen',
            '${data.avgCycleLength?.round() ?? "--"} j',
            Icons.sync_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallStatCard(
            'Règles moyennes',
            '${data.avgPeriodLength?.round() ?? "--"} j',
            Icons.water_drop_rounded,
            Colors.red,
          ),
        ),
      ],
    );
    }

    Widget _buildSmallStatCard(String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
    }

    Widget _buildPhaseAdviceCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final phase = _currentCycle?.phase ?? 'inconnu';
    String advice = "";
    IconData icon = Icons.lightbulb_rounded;
    Color color = Colors.amber;

    switch (phase) {
      case 'règles':
        advice = "Privilégiez le repos et les aliments riches en fer comme les épinards ou les lentilles.";
        icon = Icons.spa_rounded;
        color = Colors.red;
        break;
      case 'folliculaire':
        advice = "Votre énergie remonte ! C'est le moment idéal pour de nouveaux projets ou du sport intensif.";
        icon = Icons.bolt_rounded;
        color = Colors.orange;
        break;
      case 'ovulation':
        advice = "Pic de libido et de confiance en soi. Votre peau est souvent plus éclatante aujourd'hui !";
        icon = Icons.auto_awesome_rounded;
        color = Colors.pink;
        break;
      case 'lutéale':
        advice = "Réduisez le sel et la caféine pour limiter les ballonnements et l'irritabilité.";
        icon = Icons.self_improvement_rounded;
        color = Colors.purple;
        break;
      default:
        advice = "Continuez à noter vos symptômes pour des conseils plus personnalisés.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Conseil bien-être",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  advice,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    }

  Widget _buildDueDateNotification() {
    if (_currentCycle != null && _currentCycle!.expectedPeriod != null) {
      final now = DateTime.now();
      final difference = _currentCycle!.expectedPeriod!.difference(now).inDays;

      if (difference >= -2 && difference <= 2) {
        String dayString = "imminentes";
        if (difference == 0) {
          dayString = "aujourd'hui";
        } else if (difference == 1) {
          dayString = "demain";
        } else if (difference > 1) {
          dayString = "dans $difference jours";
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer.withAlpha(179),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha(51)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Prochaines règles attendues $dayString.",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildCycleInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    String phaseInfo = _currentCycle?.phase?.capitalize() ?? 'N/A';
    String ovulationDateInfo = _currentCycle?.ovulationDate != null
        ? 'Ovulation estimée: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(_currentCycle!.ovulationDate!)}'
        : 'Cycle trop court pour estimer.';

    if (_currentDayOfCycle < 1) {
      final daysUntilStart = -_currentDayOfCycle + 1;
      String countdownText = "Commence dans $daysUntilStart jours";
      if (daysUntilStart == 1) {
        countdownText = "Commence demain";
      }

      String expectedPeriodDate = _currentCycle?.expectedPeriod != null
          ? DateFormat('d MMM yyyy', 'fr_FR').format(_currentCycle!.expectedPeriod!)
          : 'N/A';

      return FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onLongPress: () => _showDeleteCycleConfirmation(context, _currentCycle!),
          child: Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withAlpha(77),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text('Cycle Programmé', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(countdownText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text('Début le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_currentCycle!.startDate)}', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoSmall(Icons.calendar_today_rounded, 'Fin estimée', expectedPeriodDate),
                      _buildInfoSmall(Icons.favorite_rounded, 'Fertilité', ovulationDateInfo.split(':').last.trim()),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    double progress = (_currentDayOfCycle / (_currentCycle?.cycleLength ?? 28)).clamp(0.0, 1.0);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onLongPress: () {
          if (_currentCycle != null) {
            _showDeleteCycleConfirmation(context, _currentCycle!);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withAlpha(77),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      children: [
                        const Text('JOUR', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                        Text('$_currentDayOfCycle', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text('du cycle', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Phase: $phaseInfo',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ovulationDateInfo,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      );
  }

  Widget _buildInfoSmall(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNoCycleCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.calendar_today_rounded, size: 48, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Aucun cycle en cours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Appuyez sur le bouton + pour commencer votre suivi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTiles() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildFeatureTile(
            icon: Icons.history_rounded,
            title: 'Historique des cycles',
            subtitle: 'Consultez vos cycles précédents.',
            onTap: () => Navigator.push(context, slideTransition(const CycleHistoryScreen())),
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.edit_note_rounded,
            title: 'Journal de symptômes',
            subtitle: 'Douleurs, humeur, énergie...',
            onTap: () {
              if (_currentCycle != null && _currentCycle!.id != null) {
                Navigator.push(context, slideTransition(SymptomScreen(cycleId: _currentCycle!.id!)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez d'abord démarrer un cycle.")));
              }
            },
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.water_drop_rounded,
            title: 'Analyse de l\'hydratation',
            subtitle: 'Suivez votre consommation d\'eau.',
            onTap: () => Navigator.push(context, slideTransition(const HydrationScreen())),
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.bar_chart_rounded,
            title: 'Statistiques et visualisations',
            subtitle: 'Graphiques, heatmap et calendrier.',
            onTap: () => Navigator.push(context, slideTransition(const StatsScreen())),
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.smart_toy_rounded,
            title: 'Prédictions intelligentes',
            subtitle: 'Algorithme adaptatif et ajustements.',
            onTap: () => Navigator.push(context, slideTransition(const PredictionDetailsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    bool isCycleActive = _currentCycle != null && _currentCycle!.endDate == null;
    final colorScheme = Theme.of(context).colorScheme;

    if (!isCycleActive) {
      return FloatingActionButton.extended(
        onPressed: () async {
          final newStartDate = await _showStartCycleDialog(context);
          if (newStartDate != null) {
            await _startNewCycle(startDate: newStartDate);
          }
        },
        label: const Text('Démarrer un cycle'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
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
              label: const Text('Fin des règles'),
              icon: const Icon(Icons.check_rounded),
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              heroTag: 'endPeriod',
            ),
          ),
        FloatingActionButton(
          onPressed: () => _showEndCycleConfirmation(context),
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
          elevation: 2,
          child: const Icon(Icons.stop_rounded),
          tooltip: 'Terminer le cycle actuel',
          heroTag: 'endCycle',
        ),
      ],
    );
  }

  Future<DateTime?> _showStartCycleDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();

    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Démarrer un nouveau cycle'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text("Quelle est la date de début de vos règles ?", textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(DateTime.now().year - 5),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked != null && picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date de début',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              child: const Text('Enregistrer'),
              onPressed: () => Navigator.of(dialogContext).pop(selectedDate),
            ),
          ],
        );
      },
    );
  }

  void _showPeriodStartPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nouveau cycle ?'),
          content: const Text('Vos règles ont-elles commencé ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Pas encore'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Choisir une date'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final newStartDate = await _showStartCycleDialog(context);
                if (newStartDate != null) {
                  await _startNewCycle(startDate: newStartDate);
                }
              },
            ),
            ElevatedButton(
              child: const Text('Oui, aujourd\'hui'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _startNewCycle(startDate: DateTime.now());
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNewCycle({required DateTime startDate}) async {
    if (_currentCycle != null && _currentCycle!.endDate == null) {
      await _endCycle(isNewCycleStarting: true, newCycleStartDate: startDate);
    }

    final settings = await _dbHelper.getSettings();
    final cycleLength = settings.defaultCycleLength;

    DateTime? ovulationDate;
    if (cycleLength > 15) {
      ovulationDate = startDate.add(Duration(days: cycleLength - 14));
    }

    final expectedPeriod = startDate.add(Duration(days: cycleLength));

    final newCycle = Cycle(
      startDate: startDate,
      phase: 'règles',
      cycleLength: cycleLength,
      ovulationDate: ovulationDate,
      expectedPeriod: expectedPeriod,
    );
    await _dbHelper.insertCycle(newCycle);

    await _refreshData();
  }

  Future<void> _endCycle({bool isNewCycleStarting = false, DateTime? newCycleStartDate}) async {
    if (_currentCycle != null) {
      final cycleEndDate = newCycleStartDate != null ? newCycleStartDate.subtract(const Duration(days: 1)) : DateTime.now();
      final cycleLength = cycleEndDate.difference(_currentCycle!.startDate).inDays + 1;

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
      final newCycle = Cycle(
        id: updatedCycle.id,
        startDate: updatedCycle.startDate,
        periodEndDate: DateTime.now(),
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

  void _showDeleteCycleConfirmation(BuildContext context, Cycle cycle) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce cycle ?'),
          content: const Text('Cette action est irréversible et supprimera toutes les données associées.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terminer le cycle'),
          content: const Text('Voulez-vous vraiment terminer le cycle actuel ?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _endCycle();
              },
              child: const Text('Terminer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}


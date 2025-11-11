import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../database/database_helper.dart';
import '../models/cycle.dart';
import '../models/settings.dart';
import '../services/notification_service.dart';
import 'symptom_screen.dart';
import 'cycle_history_screen.dart';
import 'prediction_details_screen.dart';
import 'stats_screen.dart';

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Classe de données pour le FutureBuilder
class DashboardData {
  final Cycle? currentCycle;
  final AppSettings settings;
  DashboardData(this.currentCycle, this.settings);
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

    // Utilisation de .firstWhereOrNull (si importé, sinon la solution orElse: () => null)
    // En se basant sur la version précédente, nous utilisons l'orElse corrigé pour éviter l'erreur de type :
    Cycle? activeCycle;
    try {
      activeCycle = cycles.firstWhere(
            (cycle) => cycle.endDate == null,
        orElse: () => cycles.isNotEmpty && cycles.first.endDate == null ? cycles.first : throw Exception('No active cycle or list is empty'),
      );
    } catch (_) {
      activeCycle = null;
    }
    // Simplification pour éviter l'erreur de type précédente :
    if (activeCycle == null) {
      activeCycle = cycles.cast<Cycle?>().firstWhere((cycle) => cycle?.endDate == null, orElse: () => null);
    }


    _currentCycle = activeCycle;

    if (_currentCycle != null) {
      await _updateCyclePredictions(settings);
      _calculateCycleDay();
    }

    if (mounted) _animationController.forward();

    _checkIfPeriodIsDue();

    return DashboardData(_currentCycle, settings);
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
      if (_currentCycle!.periodEndDate != null && now.isAfter(_currentCycle!.periodEndDate!)) {
        if (ovulationDate != null && now.isAfter(ovulationDate.add(const Duration(days: 1)))) {
          phase = 'lutéale';
        } else if (ovulationDate != null && now.isAfter(ovulationDate.subtract(const Duration(days: 5)))) {
          phase = 'ovulation';
        } else {
          phase = 'folliculaire';
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

      // Planification des notifications
      // VÉRIFICATION DE SÉCURITÉ: Appel uniquement si le service est prêt
      if (_notificationService.isReady) {
        await _notificationService.cancelAllNotifications();
        if (settings.notifyOvulation && ovulationDate != null) {
          _notificationService.scheduleNotification(
            id: 0,
            title: 'Ovulation Bientôt',
            body: 'Votre ovulation est prévue pour aujourd\'hui. C\'est le début de votre fenêtre de fertilité.',
            scheduledDate: ovulationDate,
          );
        }
        if (settings.notifyPeriod && expectedPeriod != null) {
          _notificationService.scheduleNotification(
            id: 1,
            title: 'Règles en Approche',
            body: 'Vos règles sont prévues dans 2 jours.',
            scheduledDate: expectedPeriod.subtract(const Duration(days: 2)),
            repeatDaily: true,
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
        } else {
          return Scaffold(
            body: _buildDashboardContent(),
            floatingActionButton: _buildFloatingActionButton(),
          );
        }
      },
    );
  }

  PageRouteBuilder _slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
          child: child,
        );
      },
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        children: [
          _buildDueDateNotification(),
          if (_currentCycle != null) _buildCycleInfoCard() else _buildNoCycleCard(),
          const SizedBox(height: 16),
          _buildFeatureTiles(),
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
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.pinkAccent),
              const SizedBox(width: 10),
              Expanded(child: Text("Vos prochaines règles sont attendues $dayString.", style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.black))),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildCycleInfoCard() {
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
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: Column(
                children: [
                  Text('Cycle Programmé', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(countdownText, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.brown, fontWeight: FontWeight.bold)),
                  Text('Début le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_currentCycle!.startDate)}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined, color: Colors.brown, size: 30),
                    title: Text('Fin de cycle estimée', style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(expectedPeriodDate),
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30),
                    title: Text('Fenêtre de Fertilité Prévue', style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(ovulationDateInfo.replaceFirst('Ovulation estimée: ', '')),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onLongPress: () {
          if (_currentCycle != null) {
            _showDeleteCycleConfirmation(context, _currentCycle!);
          }
        },
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(
              children: [
                Text('Jour', style: Theme.of(context).textTheme.titleLarge),
                Text('$_currentDayOfCycle', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.brown, fontWeight: FontWeight.bold)),
                Text('de votre cycle', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined, color: Colors.brown, size: 30),
                  title: Text('Phase: $phaseInfo', style: Theme.of(context).textTheme.titleMedium),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30),
                  title: Text('Fenêtre de Fertilité', style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(ovulationDateInfo),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoCycleCard() {
    return Card(
      color: Colors.brown[50],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.brown),
            const SizedBox(height: 10),
            const Text('Aucun cycle en cours.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.black)),
            const SizedBox(height: 5),
            const Text('Appuyez sur le bouton + pour démarrer le suivi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black)),
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
            icon: Icons.history,
            title: 'Historique des cycles',
            subtitle: 'Consultez vos cycles précédents.',
            onTap: () => Navigator.push(context, _slideTransition(const CycleHistoryScreen())),
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.edit_note,
            title: 'Journal de symptômes',
            subtitle: 'Douleurs, humeur, énergie...',
            onTap: () {
              if (_currentCycle != null && _currentCycle!.id != null) {
                Navigator.push(context, _slideTransition(SymptomScreen(cycleId: _currentCycle!.id!)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez d'abord démarrer un cycle.")));
              }
            },
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.bar_chart,
            title: 'Statistiques et visualisations',
            subtitle: 'Graphiques, heatmap et calendrier.',
            onTap: () => Navigator.push(context, _slideTransition(const StatsScreen())),
          ),
          const SizedBox(height: 12),
          _buildFeatureTile(
            icon: Icons.smart_toy_outlined,
            title: 'Prédictions intelligentes',
            subtitle: 'Algorithme adaptatif et ajustements.',
            onTap: () => Navigator.push(context, _slideTransition(const PredictionDetailsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.brown, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    bool isCycleActive = _currentCycle != null && _currentCycle!.endDate == null;

    if (isCycleActive) {
      bool isPeriodOverdue = _currentCycle!.expectedPeriod != null && DateTime.now().isAfter(_currentCycle!.expectedPeriod!);
      bool canEndPeriod = _currentCycle!.periodEndDate == null;

      if (isPeriodOverdue) {
        return FloatingActionButton.extended(
          onPressed: () async {
            final newStartDate = await _showStartCycleDialog(context);
            if (newStartDate != null) {
              await _startNewCycle(startDate: newStartDate);
            }
          },
          label: const Text('Démarrer un cycle'),
          icon: const Icon(Icons.add),
          heroTag: 'startCyclePostDue',
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canEndPeriod)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.extended(
                onPressed: _endPeriod,
                label: const Text('Fin des règles'),
                icon: const Icon(Icons.check),
                heroTag: 'endPeriod',
              ),
            ),
          FloatingActionButton(
            onPressed: () => _showEndCycleConfirmation(context),
            backgroundColor: Colors.red[300],
            child: const Icon(Icons.stop),
            tooltip: 'Terminer le cycle actuel',
            heroTag: 'endCycle',
          ),
        ],
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: () async {
          final newStartDate = await _showStartCycleDialog(context);
          if (newStartDate != null) {
            await _startNewCycle(startDate: newStartDate);
          }
        },
        label: const Text('Démarrer un cycle'),
        icon: const Icon(Icons.add),
        heroTag: 'startCycle',
      );
    }
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
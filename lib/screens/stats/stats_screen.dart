import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../models/symptom.dart';
import '../../utils/widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<Map<String, dynamic>> _statsDataFuture;

  static const Map<int, Color> _colorMapping = {
    1: Colors.red,       // Règles
    2: Colors.yellow,    // Ovulation
    3: Colors.green,     // Fertilité
    4: Colors.blue,      // Symptômes
  };

  @override
  void initState() {
    super.initState();
    _statsDataFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    final cycles = await _dbHelper.getCycles();
    final allSymptoms = await _dbHelper.getAllSymptoms();
    final Map<DateTime, int> datasets = {};

    // --- Heatmap Data Preparation ---
    // Priorité 1 : Ovulation
    for (final cycle in cycles) {
      if (cycle.ovulationDate != null) {
        final ovulationDay = DateTime(cycle.ovulationDate!.year, cycle.ovulationDate!.month, cycle.ovulationDate!.day);
        datasets[ovulationDay] = 2;
      }
    }
    // Priorité 2 : Règles
    for (final cycle in cycles) {
      final startDate = cycle.startDate;
      final periodEndDate = cycle.periodEndDate ?? startDate.add(const Duration(days: 4));
      for (int i = 0; i <= periodEndDate.difference(startDate).inDays; i++) {
        final date = startDate.add(Duration(days: i));
        final cleanDate = DateTime(date.year, date.month, date.day);
        datasets.putIfAbsent(cleanDate, () => 1);
      }
    }
    // Priorité 3 : Fertilité
    for (final cycle in cycles) {
      if (cycle.ovulationDate != null) {
        for (int i = 5; i > 0; i--) {
          final date = cycle.ovulationDate!.subtract(Duration(days: i));
          final cleanDate = DateTime(date.year, date.month, date.day);
          datasets.putIfAbsent(cleanDate, () => 3);
        }
      }
    }
    // Priorité 4 : Symptômes
    for (final symptom in allSymptoms) {
      final date = DateTime(symptom.date.year, symptom.date.month, symptom.date.day);
      datasets.putIfAbsent(date, () => 4);
    }

    // --- Stats Calculation ---
    final completedCycles = cycles.where((c) => c.cycleLength != null && c.cycleLength! > 0).toList();
    double? avgCycleLength;
    if (completedCycles.isNotEmpty) {
      avgCycleLength = completedCycles.map((c) => c.cycleLength!).reduce((a, b) => a + b) / completedCycles.length;
    }

    final periodCycles = cycles.where((c) => c.periodEndDate != null).toList();
    double? avgPeriodLength;
    if (periodCycles.isNotEmpty) {
      avgPeriodLength = periodCycles.map((c) => c.periodEndDate!.difference(c.startDate).inDays + 1).reduce((a, b) => a + b) / periodCycles.length;
    }

    final Map<String, int> moodFrequency = {};
    for (var symptom in allSymptoms) {
      if (symptom.mood != null && symptom.mood!.isNotEmpty) {
        moodFrequency.update(symptom.mood!, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    return {
      'heatmapData': datasets,
      'avgCycleLength': avgCycleLength,
      'avgPeriodLength': avgPeriodLength,
      'moodFrequency': moodFrequency,
      'totalCompletedCycles': completedCycles.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: const AppBackButton(),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Pas de données à afficher.'));
          }

          final data = snapshot.data!;
          final heatmapData = data['heatmapData'] as Map<DateTime, int>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Calendrier'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: heatmapData.isNotEmpty
                      ? HeatMapCalendar(
                          datasets: heatmapData,
                          colorsets: _colorMapping,
                          colorMode: ColorMode.color,
                          defaultColor: Colors.transparent,
                          textColor: colorScheme.onSurface,
                          showColorTip: false,
                          monthFontSize: 16,
                        )
                      : const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('Aucune donnée pour le calendrier.')),
                        ),
                ),
                const SizedBox(height: 16),
                _buildLegend(),
                const SizedBox(height: 32),

                _buildSectionHeader('Général'),
                _buildStatsCard(data),
                const SizedBox(height: 32),

                _buildSectionHeader('Fréquence des Humeurs'),
                _buildMoodCard(data['moodFrequency'] as Map<String, int>),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> data) {
    final colorScheme = Theme.of(context).colorScheme;
    final avgCycleLength = data['avgCycleLength'] as double?;
    final avgPeriodLength = data['avgPeriodLength'] as double?;
    final totalCompletedCycles = data['totalCompletedCycles'] as int;

    if (totalCompletedCycles == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Pas assez de données pour les moyennes.')),
      );
    }

    final cycleLengthDisplay = avgCycleLength?.round() ?? 0;
    final periodLengthDisplay = avgPeriodLength?.round() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildStatRow(Icons.sync_rounded, 'Cycle moyen', '$cycleLengthDisplay jours', Colors.blue),
          const Divider(height: 1, indent: 50),
          _buildStatRow(Icons.water_drop_rounded, 'Règles moyennes', '$periodLengthDisplay jours', Colors.red),
          const Divider(height: 1, indent: 50),
          _buildStatRow(Icons.check_circle_outline_rounded, 'Cycles terminés', '$totalCompletedCycles', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildMoodCard(Map<String, int> moodFreq) {
    final colorScheme = Theme.of(context).colorScheme;
    if (moodFreq.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Aucune humeur enregistrée.')),
      );
    }

    final sortedMoods = moodFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: sortedMoods.map((entry) {
          return ListTile(
            title: Text(entry.key),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: colorScheme.primary.withAlpha(26), borderRadius: BorderRadius.circular(12)),
              child: Text('${entry.value}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(Colors.red, 'Règles'),
        _buildLegendItem(Colors.yellow, 'Ovulation'),
        _buildLegendItem(Colors.green, 'Fertilité'),
        _buildLegendItem(Colors.blue, 'Symptômes'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

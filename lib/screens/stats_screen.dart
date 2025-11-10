import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../database/database_helper.dart';
import '../models/cycle.dart';
import '../models/symptom.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques et Heatmap'),
        centerTitle: true,
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text('Calendrier du Cycle', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                if (heatmapData.isNotEmpty)
                  HeatMapCalendar(
                    datasets: heatmapData,
                    colorsets: _colorMapping,
                    colorMode: ColorMode.color,
                    defaultColor: Colors.transparent,
                    textColor: Colors.black,
                    showColorTip: false,
                    monthFontSize: 18,
                  )
                else
                  const Center(child: Text('Aucune donnée pour le calendrier.')),
                const SizedBox(height: 24),
                _buildLegend(),
                const SizedBox(height: 24),
                Center(
                  child: Text('Statistiques Générales', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                _buildStatsCard(data),
                 const SizedBox(height: 24),
                Center(
                  child: Text('Fréquence des Humeurs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                _buildMoodCard(data['moodFrequency'] as Map<String, int>),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> data) {
    final avgCycleLength = data['avgCycleLength'] as double?;
    final avgPeriodLength = data['avgPeriodLength'] as double?;
    final totalCompletedCycles = data['totalCompletedCycles'] as int;

    if (totalCompletedCycles == 0) {
      return const Card(child: ListTile(title: Text('Aucun cycle complet pour calculer les statistiques.')));
    }

    final cycleLengthDisplay = avgCycleLength?.round() ?? 0;
    final periodLengthDisplay = avgPeriodLength?.round() ?? 0;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.sync, color: Colors.blueAccent),
            title: const Text('Durée moyenne du cycle'),
            trailing: Text(
              '$cycleLengthDisplay jour${cycleLengthDisplay != 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined, color: Colors.redAccent),
            title: const Text('Durée moyenne des règles'),
            trailing: Text(
              '$periodLengthDisplay jour${periodLengthDisplay != 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard(Map<String, int> moodFrequency) {
    if (moodFrequency.isEmpty) {
      return const Card(child: ListTile(title: Text('Aucune humeur enregistrée.')));
    }

    var sortedMoods = moodFrequency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Column(
        children: sortedMoods.map((entry) {
          return ListTile(
            title: Text(entry.key),
            trailing: Text('${entry.value} fois', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          children: _colorMapping.entries.map((entry) {
            return _buildLegendItem(entry.value, _getLegendLabel(entry.key));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  String _getLegendLabel(int key) {
    switch (key) {
      case 1: return 'Règles';
      case 2: return 'Ovulation';
      case 3: return 'Fertilité';
      case 4: return 'Symptômes';
      default: return '';
    }
  }
}

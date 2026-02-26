import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/symptom.dart';
import 'add_symptom_screen.dart';

class SymptomScreen extends StatefulWidget {
  final int cycleId;

  const SymptomScreen({super.key, required this.cycleId});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

enum ChartFilter { pain, energy, libido }

class _SymptomScreenState extends State<SymptomScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Symptom>> _symptomsFuture;
  ChartFilter _selectedFilter = ChartFilter.pain;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadSymptoms();
  }

  void _loadSymptoms() {
    setState(() {
      _symptomsFuture = _dbHelper.getSymptomsForCycle(widget.cycleId);
    });
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des Symptômes', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<Symptom>>(
        future: _symptomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_rounded, size: 64, color: colorScheme.outline.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Aucune entrée pour ce cycle', style: TextStyle(color: colorScheme.outline)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddSymptom,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une note'),
                  )
                ],
              ),
            );
          }

          final symptoms = snapshot.data!;
          symptoms.sort((a, b) => a.date.compareTo(b.date)); // Sort for chart

          return Column(
            children: [
              _buildChart(symptoms),
              _buildFilterButtons(),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: symptoms.length,
                  itemBuilder: (context, index) {
                    // Display newest first in the list
                    return _buildSymptomCard(symptoms[symptoms.length - 1 - index]);
                  },
                ),
              ),
            ], 
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddSymptom,
        label: const Text('Nouvelle entrée'),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _navigateToAddSymptom() async {
    final result = await Navigator.push(context, _slideTransition(AddSymptomScreen(cycleId: widget.cycleId)));
    if (result == true) {
      _loadSymptoms();
    }
  }

  Widget _buildChart(List<Symptom> symptoms) {
    final spots = _getChartSpots(symptoms);
    if (spots.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Ajoutez au moins deux entrées pour voir le graphique.'),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: (value, meta) => Text(value.toInt().toString()))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.brown,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.brown.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getChartSpots(List<Symptom> symptoms) {
    List<FlSpot> spots = [];
    for (int i = 0; i < symptoms.length; i++) {
      double yValue;
      switch (_selectedFilter) {
        case ChartFilter.pain:
          yValue = symptoms[i].painLevel?.toDouble() ?? 0;
          break;
        case ChartFilter.energy:
          yValue = symptoms[i].energyLevel?.toDouble() ?? 0;
          break;
        case ChartFilter.libido:
          yValue = symptoms[i].libidoLevel?.toDouble() ?? 0;
          break;
      }
      spots.add(FlSpot(i.toDouble(), yValue));
    }
    return spots;
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFilterChip(ChartFilter.pain, 'Douleur', Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _buildFilterChip(ChartFilter.energy, 'Énergie', Icons.bolt_rounded),
            const SizedBox(width: 8),
            _buildFilterChip(ChartFilter.libido, 'Libido', Icons.favorite_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(ChartFilter filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(icon, size: 18, color: isSelected ? colorScheme.onPrimary : colorScheme.primary),
      onSelected: (bool selected) {
        if (selected) setState(() => _selectedFilter = filter);
      },
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSymptomCard(Symptom symptom) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat('EEEE d MMMM', 'fr_FR').format(symptom.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSmallIndicator(Icons.warning_amber_rounded, 'D:${symptom.painLevel}', Colors.red),
                const SizedBox(width: 8),
                _buildSmallIndicator(Icons.bolt_rounded, 'E:${symptom.energyLevel}', Colors.orange),
                const SizedBox(width: 8),
                _buildSmallIndicator(Icons.favorite_rounded, 'L:${symptom.libidoLevel}', Colors.pink),
              ],
            ),
            if (symptom.notes != null && symptom.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                symptom.notes!,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
          onPressed: () => _confirmDelete(symptom),
        ),
        onTap: () {
          // Edit symptom?
        },
      ),
    );
  }

  Widget _buildSmallIndicator(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _confirmDelete(Symptom symptom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Voulez-vous supprimer cette entrée du journal ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              await _dbHelper.deleteSymptom(symptom.id!);
              Navigator.pop(context);
              _loadSymptoms();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

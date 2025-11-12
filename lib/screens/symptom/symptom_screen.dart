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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des Symptômes'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(6),
          ),
        ),
      ),
      body: FutureBuilder<List<Symptom>>(
        future: _symptomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Aucun symptôme à afficher.\nAjoutez une entrée pour commencer.', textAlign: TextAlign.center),
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
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
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
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSymptomScreen(cycleId: widget.cycleId)),
          );
          if (result == true) _loadSymptoms();
        },
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un journal', style: TextStyle(color: Colors.white)),
        tooltip: 'Ajouter une entrée',
      ),
    );
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          FilterChip(label: const Text('Douleur'), selected: _selectedFilter == ChartFilter.pain, onSelected: (selected) {if (selected) setState(() => _selectedFilter = ChartFilter.pain);}, selectedColor: Colors.brown.withOpacity(0.3)),
          FilterChip(label: const Text('Énergie'), selected: _selectedFilter == ChartFilter.energy, onSelected: (selected) {if (selected) setState(() => _selectedFilter = ChartFilter.energy);}, selectedColor: Colors.brown.withOpacity(0.3)),
          FilterChip(label: const Text('Libido'), selected: _selectedFilter == ChartFilter.libido, onSelected: (selected) {if (selected) setState(() => _selectedFilter = ChartFilter.libido);}, selectedColor: Colors.brown.withOpacity(0.3)),
        ], 
      ),
    );
  }

  Widget _buildSymptomCard(Symptom symptom) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(DateFormat('EEEE, d MMMM yyyy', 'fr_FR').format(symptom.date), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (symptom.mood != null) Text('Humeur: ${symptom.mood}'),
            if (symptom.painLevel != null) Text('Douleur: ${symptom.painLevel}/5'),
            if (symptom.energyLevel != null) Text('Énergie: ${symptom.energyLevel}/5'),
            if (symptom.notes?.isNotEmpty ?? false) ...[const SizedBox(height: 4), Text('Notes: ${symptom.notes}', maxLines: 2, overflow: TextOverflow.ellipsis)],
          ],
        ),
        trailing: PopupMenuButton<int>(
          onSelected: (item) => _onCardMenuSelection(item, symptom),
          itemBuilder: (context) => [const PopupMenuItem<int>(value: 0, child: Text('Modifier')), const PopupMenuItem<int>(value: 1, child: Text('Supprimer'))],
        ),
      ),
    );
  }

  void _onCardMenuSelection(int item, Symptom symptom) async {
    if (item == 0) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddSymptomScreen(cycleId: widget.cycleId, symptomToEdit: symptom)));
      if (result == true) _loadSymptoms();
    } else if (item == 1) {
      _showDeleteConfirmation(symptom);
    }
  }

  void _showDeleteConfirmation(Symptom symptom) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer cette entrée ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await _dbHelper.deleteSymptom(symptom.id!);
                if (mounted) Navigator.of(context).pop();
                _loadSymptoms();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrée supprimée.')));
              },
            ),
          ],
        );
      },
    );
  }
}

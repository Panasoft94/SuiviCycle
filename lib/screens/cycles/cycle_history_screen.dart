import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../stats/stats_screen.dart'; // Import the stats screen

class CycleHistoryScreen extends StatefulWidget {
  const CycleHistoryScreen({super.key});

  @override
  State<CycleHistoryScreen> createState() => _CycleHistoryScreenState();
}

class _CycleHistoryScreenState extends State<CycleHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Cycle>> _cyclesFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadCycles();
  }

  void _loadCycles() {
    setState(() {
      _cyclesFuture = _dbHelper.getCycles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Cycles'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
      ),
      body: FutureBuilder<List<Cycle>>(
        future: _cyclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun cycle enregistré.'));
          }

          final cycles = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0), // Add padding for FAB
            itemCount: cycles.length,
            itemBuilder: (context, index) {
              return _buildCycleCard(cycles[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const StatsScreen()));
        },
        label: const Text('Voir les Stats'),
        icon: const Icon(Icons.bar_chart),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCycleCard(Cycle cycle) {
    final isOngoing = cycle.endDate == null;
    final startDate = DateFormat('d MMM yyyy', 'fr_FR').format(cycle.startDate);
    
    String endDateText;
    if (isOngoing) {
      endDateText = cycle.expectedPeriod != null 
          ? '~ ${DateFormat('d MMM yyyy', 'fr_FR').format(cycle.expectedPeriod!)}'
          : 'En cours';
    } else {
      endDateText = DateFormat('d MMM yyyy', 'fr_FR').format(cycle.endDate!);
    }

    final cycleLength = cycle.cycleLength ?? 0;
    final cycleLengthText = cycle.cycleLength != null ? '$cycleLength jours' : 'N/A';

    int? periodLength;
    if (cycle.periodEndDate != null) {
      periodLength = cycle.periodEndDate!.difference(cycle.startDate).inDays + 1;
    }
    
    bool isIrregular = !isOngoing && (cycleLength < 21 || cycleLength > 35);

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(cycle),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ExpansionTile(
          leading: Icon(
            isIrregular ? Icons.warning_amber_rounded : (isOngoing ? Icons.sync : Icons.check_circle_outline),
            color: isIrregular ? Colors.orangeAccent : (isOngoing ? Colors.blueAccent : Colors.green),
          ),
          title: Text(
            '$startDate - $endDateText',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text('Durée : $cycleLengthText'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  const Divider(),
                  if(isIrregular)
                    _buildDetailRow(Icons.info_outline, 'Cycle irrégulier', 'La durée est en dehors de la plage typique (21-35 jours).'),
                  if (periodLength != null)
                    _buildDetailRow(Icons.water_drop_outlined, 'Durée des règles', '$periodLength jours'),
                  if (cycle.ovulationDate != null)
                    _buildDetailRow(
                      Icons.favorite_border,
                      'Date d\'ovulation',
                      DateFormat('d MMMM yyyy', 'fr_FR').format(cycle.ovulationDate!),
                    ),
                  if (cycle.ovulationDate == null && cycle.cycleLength != null && cycle.cycleLength! <= 15)
                     _buildDetailRow(Icons.help_outline, 'Ovulation', 'Non estimée (cycle trop court).'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$title:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Cycle cycle) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le cycle ?'),
          content: const Text('Cette action est irréversible et supprimera toutes les données associées à ce cycle.'),
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
                _loadCycles(); // Refresh the list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cycle supprimé.')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

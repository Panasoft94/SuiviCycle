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
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: FutureBuilder<List<Cycle>>(
        future: _cyclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: colorScheme.outline.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Aucun cycle enregistré', style: TextStyle(color: colorScheme.outline)),
                ],
              ),
            );
          }

          final cycles = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: cycles.length,
            itemBuilder: (context, index) {
              return _buildCycleCard(cycles[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, _slideTransition(const StatsScreen()));
        },
        label: const Text('Statistiques'),
        icon: const Icon(Icons.bar_chart_rounded),
      ),
    );
  }

  Widget _buildCycleCard(Cycle cycle) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOngoing = cycle.endDate == null;
    final startDate = DateFormat('d MMM yyyy', 'fr_FR').format(cycle.startDate);
    
    String endDateText;
    if (isOngoing) {
      endDateText = cycle.expectedPeriod != null 
          ? 'Prévu: ${DateFormat('d MMM yyyy', 'fr_FR').format(cycle.expectedPeriod!)}'
          : 'En cours';
    } else {
      endDateText = DateFormat('d MMM yyyy', 'fr_FR').format(cycle.endDate!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isOngoing ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOngoing ? colorScheme.primary.withOpacity(0.5) : colorScheme.outlineVariant.withOpacity(0.5),
          width: isOngoing ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOngoing ? colorScheme.primary : colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOngoing ? Icons.play_arrow_rounded : Icons.calendar_today_rounded,
            color: isOngoing ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          isOngoing ? 'Cycle Actuel' : 'Cycle terminé',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isOngoing ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$startDate - $endDateText'),
            if (cycle.cycleLength != null) ...[
              const SizedBox(height: 2),
              Text('Durée: ${cycle.cycleLength} jours', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ]
          ],
        ),
        trailing: isOngoing
            ? Icon(Icons.hourglass_bottom_rounded, color: colorScheme.primary)
            : const Icon(Icons.chevron_right_rounded),
        onTap: () {
          // Action lors du clic sur un cycle (ex: voir détails)
        },
        onLongPress: () => _showDeleteConfirmation(cycle),
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

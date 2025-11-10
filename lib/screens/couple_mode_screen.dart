import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../database/database_helper.dart';
import '../models/cycle.dart';
import 'dart:async';

// Helper extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class CoupleModeScreen extends StatefulWidget {
  const CoupleModeScreen({super.key});

  @override
  State<CoupleModeScreen> createState() => _CoupleModeScreenState();
}

class _CoupleModeScreenState extends State<CoupleModeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<Cycle?> _currentCycleFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _currentCycleFuture = _loadCurrentCycle();
  }

  Future<Cycle?> _loadCurrentCycle() async {
    final cycles = await _dbHelper.getCycles();
    if (cycles.isNotEmpty && cycles.first.endDate == null) {
      return cycles.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Cycle?>(
        future: _currentCycleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _buildEmptyState();
          }

          final cycle = snapshot.data!;
          return _buildPartnerDashboard(cycle);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Mode Couple non actif',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Activez le mode couple depuis les paramètres pour partager des informations sur le cycle.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerDashboard(Cycle cycle) {
    final phaseInfo = cycle.phase?.capitalize() ?? 'N/A';
    final advice = _getPartnerAdvice(cycle.phase);
    int daysUntilPeriod = 0;
    if (cycle.expectedPeriod != null) {
        daysUntilPeriod = cycle.expectedPeriod!.difference(DateTime.now()).inDays;
    }


    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildInfoCard(
          context,
          icon: Icons.favorite,
          iconColor: Colors.pinkAccent,
          title: 'Phase Actuelle',
          content: phaseInfo,
          isLarge: true,
        ),
        const SizedBox(height: 16),
        if (cycle.ovulationDate != null)
        _buildInfoCard(
          context,
          icon: Icons.brightness_high_outlined,
          iconColor: Colors.deepOrangeAccent,
          title: 'Date d\'Ovulation Prévue',
          content: DateFormat('EEEE, d MMMM yyyy', 'fr_FR').format(cycle.ovulationDate!),
        ),
        const SizedBox(height: 16),
        if (daysUntilPeriod > 0)
        _buildInfoCard(
          context,
          icon: Icons.hourglass_bottom,
          iconColor: Colors.blueAccent,
          title: 'Prochaines Règles Dans',
          content: '$daysUntilPeriod jour${daysUntilPeriod > 1 ? 's' : ''}',
        ),
        const SizedBox(height: 16),
        if (cycle.expectedPeriod != null)
        _buildInfoCard(
          context,
          icon: Icons.calendar_today_outlined,
          iconColor: Colors.purple,
          title: 'Date Prévue des Règles',
          content: DateFormat('EEEE, d MMMM yyyy', 'fr_FR').format(cycle.expectedPeriod!),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          icon: Icons.lightbulb_outline,
          iconColor: Colors.amber,
          title: 'Conseil du Jour',
          content: advice,
        ),
      ],
    );
  }

  String _getPartnerAdvice(String? phase) {
    switch (phase) {
      case 'folliculaire':
        return 'C\'est une période de renouveau et d\'énergie. Le moment idéal pour planifier des activités ensemble !';
      case 'ovulation':
        return 'La fertilité est à son maximum. C\'est un bon moment pour l\'intimité et la connexion.';
      case 'lutéale':
        return 'L\'énergie peut commencer à baisser. Un peu plus de patience, de soutien et des soirées tranquilles peuvent être appréciés.';
      default:
        return 'Chaque jour est une nouvelle opportunité de se soutenir mutuellement.';
    }
  }

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required Color iconColor, required String title, required String content, bool isLarge = false}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: isLarge ? 32 : 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              textAlign: TextAlign.center,
              style: isLarge
                  ? Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.brown)
                  : Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

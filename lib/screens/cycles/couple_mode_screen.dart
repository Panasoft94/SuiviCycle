import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
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
    return FutureBuilder<Cycle?>(
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
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_rounded, size: 64, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mode Couple',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Partagez les étapes de votre cycle avec votre partenaire pour une meilleure compréhension mutuelle.',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Redirection vers aide ou paramètres
            },
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('En savoir plus'),
          ),
        ],
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
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildInfoCard(
          icon: Icons.auto_awesome_rounded,
          iconColor: Colors.pink,
          title: 'Phase Actuelle',
          content: phaseInfo,
          isLarge: true,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.lightbulb_rounded,
          iconColor: Colors.amber,
          title: 'Conseil bienveillant',
          content: advice,
        ),
        const SizedBox(height: 32),
        _buildSectionHeader('Dates Clés'),
        if (cycle.ovulationDate != null)
          _buildCompactDateRow(Icons.brightness_7_rounded, 'Ovulation prévue', cycle.ovulationDate!, Colors.orange),
        const SizedBox(height: 12),
        if (cycle.expectedPeriod != null)
          _buildCompactDateRow(Icons.water_drop_rounded, 'Flux prévu', cycle.expectedPeriod!, Colors.red),
        const SizedBox(height: 12),
        if (daysUntilPeriod > 0)
          _buildCompactInfoRow(Icons.timer_rounded, 'Temps restant', '$daysUntilPeriod jours avant le cycle', Colors.blue),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCompactDateRow(IconData icon, String label, DateTime date, Color color) {
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
    return _buildCompactInfoRow(icon, label, dateStr, color);
  }

  Widget _buildCompactInfoRow(IconData icon, String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String title, required String content, bool isLarge = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isLarge ? colorScheme.primaryContainer.withAlpha(77) : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: isLarge ? Border.all(color: colorScheme.primary.withAlpha(51)) : Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: isLarge ? 28 : 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: isLarge ? 18 : 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isLarge ? 24 : 15,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
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
}

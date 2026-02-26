import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/settings.dart';

class PredictionDetailsScreen extends StatefulWidget {
  const PredictionDetailsScreen({super.key});

  @override
  State<PredictionDetailsScreen> createState() => _PredictionDetailsScreenState();
}

class _PredictionDetailsScreenState extends State<PredictionDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final settings = await _dbHelper.getSettings();
    final avgCycleLength = await _dbHelper.getAverageCycleLength();
    return {
      'settings': settings,
      'avgCycleLength': avgCycleLength,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Algorithme', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Impossible de charger les informations.'));
          }

          final AppSettings settings = snapshot.data!['settings'];
          final double? avgCycleLength = snapshot.data!['avgCycleLength'];
          final defaultCycleLength = settings.defaultCycleLength;

          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              Text(
                'Intelligence Prédictive',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Découvrez comment CycleTrack calcule vos prochaines dates importantes.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _buildExplanationCard(
                icon: Icons.analytics_rounded,
                iconColor: Colors.blue,
                title: 'Votre Tendance Personnelle',
                content: avgCycleLength != null
                    ? 'Actuellement, vos prédictions sont basées sur une durée de cycle moyenne de ${avgCycleLength.round()} jours, calculée à partir de votre historique personnel.'
                    : 'Encore aucun cycle terminé ! Vos prédictions utilisent la durée par défaut de $defaultCycleLength jours en attendant vos premières données.',
              ),
              const SizedBox(height: 16),
              _buildExplanationCard(
                icon: Icons.filter_alt_rounded,
                iconColor: Colors.orange,
                title: 'Filtrage des Irrégularités',
                content: 'L\'algorithme ignore automatiquement les cycles trop courts (<21j) ou trop longs (>35j) pour ne pas fausser la précision de vos moyennes habituelles.',
              ),
              const SizedBox(height: 16),
              _buildExplanationCard(
                icon: Icons.favorite_rounded,
                iconColor: Colors.pink,
                title: 'Estimation de l\'Ovulation',
                content: 'L\'ovulation est calculée en soustrayant 14 jours (phase lutéale standard) de votre durée de cycle moyenne estimée.',
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExplanationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

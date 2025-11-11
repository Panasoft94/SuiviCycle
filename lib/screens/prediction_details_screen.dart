import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/settings.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prédictions Intelligentes'),
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
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Comment fonctionnent nos prédictions ?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.brown, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildExplanationCard(
                context,
                icon: Icons.all_inclusive,
                title: 'Votre Tendance Personnelle',
                content: avgCycleLength != null
                    ? 'Actuellement, vos prédictions sont basées sur une durée de cycle moyenne de ${avgCycleLength.round()} jours, calculée à partir de votre historique. Continuez à enregistrer vos cycles pour améliorer la précision !'
                    : 'Encore aucun cycle terminé ! Vos prédictions sont pour l\'instant basées sur la durée par défaut de $defaultCycleLength jours. La précision augmentera dès votre premier cycle complet.',
              ),
              const SizedBox(height: 16),
              _buildExplanationCard(
                context,
                icon: Icons.warning_amber_rounded,
                title: 'Gestion des Irrégularités',
                content: 'Pour garantir des prédictions fiables, l\'algorithme identifie et met de côté les cycles dont la durée est inhabituelle (généralement moins de 21 jours ou plus de 35 jours). Cela empêche un cycle exceptionnel de fausser la moyenne.',
              ),
              const SizedBox(height: 16),
              _buildExplanationCard(
                context,
                icon: Icons.favorite_border,
                title: 'Estimation de l\'ovulation',
                content: 'L\'ovulation est estimée en se basant sur une phase lutéale de 14 jours (la période après l\'ovulation). Cette durée est soustraite de la durée totale estimée de votre cycle.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExplanationCard(BuildContext context, {required IconData icon, required String title, required String content}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.brown, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

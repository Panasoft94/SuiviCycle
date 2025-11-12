import 'package:flutter/material.dart';

class AideScreen extends StatelessWidget {
  const AideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('À Propos de CycleTrack'),
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Icon(Icons.water_drop_outlined, size: 60, color: Colors.brown[300]),
          ),
          const SizedBox(height: 16),
          Text(
            'CycleTrack',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre compagnon personnel pour un suivi simple et intelligent de votre cycle menstruel.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            context,
            icon: Icons.track_changes,
            title: 'Suivi de Cycle Intelligent',
            content: 'Enregistrez vos règles et laissez CycleTrack calculer automatiquement la durée de votre cycle, estimer vos prochaines règles et prédire votre date d\'ovulation. Notre algorithme s\'adapte à vous pour des prédictions de plus en plus précises.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.edit_note,
            title: 'Journal Quotidien',
            content: 'Notez chaque jour vos symptômes, votre humeur, votre niveau d\'énergie et plus encore. Visualisez ensuite vos tendances grâce à des graphiques clairs pour mieux comprendre votre corps.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.insights,
            title: 'Statistiques et Calendrier Visuel',
            content: 'Consultez votre historique complet sur un calendrier visuel (heatmap) et accédez à des statistiques clés, comme la durée moyenne de vos cycles et de vos règles.',
          ),
           const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.people_outline,
            title: 'Mode Couple',
            content: 'Partagez des informations clés avec votre partenaire de manière simple et respectueuse, pour l\'aider à mieux vous comprendre et vous soutenir tout au long de votre cycle.',
          ),
          const SizedBox(height: 24),
          _buildDeveloperCard(context),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Version 1.0.6',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String title, required String content}) {
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

  Widget _buildDeveloperCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Développeur', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Anicet DJIMTOLOUMA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Analyste & Programmeur', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('webmasterdjim@gmail.com'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('236 72 39 59 35'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

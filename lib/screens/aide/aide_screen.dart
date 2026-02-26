import 'package:flutter/material.dart';

class AideScreen extends StatelessWidget {
  const AideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('À Propos', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_drop_rounded, size: 48, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'CycleTrack',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre compagnon personnel pour un suivi simple et intelligent de votre cycle menstruel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 40),
          _buildFeatureCard(
            icon: Icons.track_changes_rounded,
            title: 'Suivi Intelligent',
            content: 'Enregistrez vos règles et laissez CycleTrack calculer automatiquement la durée de votre cycle et estimer vos prochaines dates importantes.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.edit_note_rounded,
            title: 'Journal Quotidien',
            content: 'Notez chaque jour vos symptômes et humeurs pour visualiser vos tendances grâce à des graphiques clairs.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.insights_rounded,
            title: 'Statistiques Clés',
            content: 'Consultez votre historique complet sur un calendrier visuel et accédez à des analyses précises de vos cycles.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.people_rounded,
            title: 'Mode Couple',
            content: 'Partagez des informations clés avec votre partenaire pour une meilleure compréhension mutuelle.',
          ),
          const SizedBox(height: 32),
          _buildDeveloperSection(colorScheme),
          const SizedBox(height: 48),
          Center(
            child: Text(
              'Version 1.0.6',
              style: TextStyle(color: colorScheme.outline, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String content}) {
    return Builder(
      builder: (context) {
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
                      color: colorScheme.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDeveloperSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Développeur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          const Text('Anicet DJIMTOLOUMA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Analyste & Programmeur', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          _buildDevContactRow(Icons.email_rounded, 'webmasterdjim@gmail.com', colorScheme),
          const SizedBox(height: 8),
          _buildDevContactRow(Icons.phone_rounded, '+236 72 39 59 35', colorScheme),
        ],
      ),
    );
  }

  Widget _buildDevContactRow(IconData icon, String text, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

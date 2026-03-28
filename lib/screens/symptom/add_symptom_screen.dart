import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/symptom.dart';
import '../../utils/widgets.dart';

class AddSymptomScreen extends StatefulWidget {
  final int cycleId;
  final Symptom? symptomToEdit;

  const AddSymptomScreen({super.key, required this.cycleId, this.symptomToEdit});

  @override
  State<AddSymptomScreen> createState() => _AddSymptomScreenState();
}

class _AddSymptomScreenState extends State<AddSymptomScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _notesController = TextEditingController();

  String? _selectedMood;
  double _painLevel = 0;
  double _energyLevel = 3;
  double _libidoLevel = 3;

  @override
  void initState() {
    super.initState();
    if (widget.symptomToEdit != null) {
      final symptom = widget.symptomToEdit!;
      _selectedMood = symptom.mood;
      _painLevel = symptom.painLevel?.toDouble() ?? 0;
      _energyLevel = symptom.energyLevel?.toDouble() ?? 3;
      _libidoLevel = symptom.libidoLevel?.toDouble() ?? 3;
      _notesController.text = symptom.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symptomToEdit == null ? 'Nouveau Journal' : 'Modifier le Journal', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        leading: const AppBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildSectionHeader('Humeur'),
          _buildMoodGrid(),
          const SizedBox(height: 24),

          _buildSectionHeader('Indicateurs'),
          _buildSliderCard(
            label: 'Niveau de douleur',
            value: _painLevel,
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            onChanged: (value) => setState(() => _painLevel = value),
          ),
          const SizedBox(height: 12),
          _buildSliderCard(
            label: "Niveau d'énergie",
            value: _energyLevel,
            icon: Icons.bolt_rounded,
            color: Colors.orange,
            onChanged: (value) => setState(() => _energyLevel = value),
          ),
          const SizedBox(height: 12),
          _buildSliderCard(
            label: 'Niveau de libido',
            value: _libidoLevel,
            icon: Icons.favorite_rounded,
            color: Colors.pink,
            onChanged: (value) => setState(() => _libidoLevel = value),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Notes'),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Comment vous sentez-vous aujourd\'hui ?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSymptom,
        label: const Text('Enregistrer'),
        icon: const Icon(Icons.check_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMoodGrid() {
    final List<String> moods = ['Heureuse', 'Triste', 'En colère', 'Anxieuse', 'Calme', 'Énergique'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: moods.map((mood) {
        final isSelected = _selectedMood == mood;
        final colorScheme = Theme.of(context).colorScheme;
        return ChoiceChip(
          label: Text(mood),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedMood = selected ? mood : null);
          },
          selectedColor: colorScheme.primaryContainer,
          labelStyle: TextStyle(color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      }).toList(),
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${value.toInt()}/5', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 5,
            divisions: 5,
            activeColor: color,
            inactiveColor: color.withAlpha(51),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _saveSymptom() async {
    if (widget.symptomToEdit == null) {
      // Create new symptom
      final newSymptom = Symptom(
        cycleId: widget.cycleId,
        date: DateTime.now(),
        mood: _selectedMood,
        painLevel: _painLevel.toInt(),
        energyLevel: _energyLevel.toInt(),
        libidoLevel: _libidoLevel.toInt(),
        notes: _notesController.text,
      );
      await _dbHelper.insertSymptom(newSymptom);
    } else {
      // Update existing symptom
      final updatedSymptom = Symptom(
        id: widget.symptomToEdit!.id,
        cycleId: widget.symptomToEdit!.cycleId,
        date: widget.symptomToEdit!.date, // Keep original date
        mood: _selectedMood,
        painLevel: _painLevel.toInt(),
        energyLevel: _energyLevel.toInt(),
        libidoLevel: _libidoLevel.toInt(),
        notes: _notesController.text,
      );
      await _dbHelper.updateSymptom(updatedSymptom);
    }

    if (mounted) {
      Navigator.of(context).pop(true); // Return true to indicate success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal enregistré avec succès !')),
      );
    }
  }
}

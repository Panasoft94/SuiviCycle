import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/symptom.dart';

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

  final List<String> _moods = ['Heureuse', 'Triste', 'En colère', 'Anxieuse', 'Calme', 'Énergique'];

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symptomToEdit == null ? 'Nouveau Journal' : 'Modifier le Journal'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        children: [
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: _buildMoodSelector())),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: _buildLevelSlider(label: 'Niveau de douleur', value: _painLevel, onChanged: (value) => setState(() => _painLevel = value)))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: _buildLevelSlider(label: "Niveau d'énergie", value: _energyLevel, onChanged: (value) => setState(() => _energyLevel = value)))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: _buildLevelSlider(label: 'Niveau de libido', value: _libidoLevel, onChanged: (value) => setState(() => _libidoLevel = value)))),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes supplémentaires', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSymptom,
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMoodSelector() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Humeur du jour', border: InputBorder.none, contentPadding: EdgeInsets.zero),
      value: _selectedMood,
      items: _moods.map((mood) => DropdownMenuItem<String>(value: mood, child: Text(mood))).toList(),
      onChanged: (newValue) => setState(() => _selectedMood = newValue),
    );
  }

  Widget _buildLevelSlider({required String label, required double value, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}', style: Theme.of(context).textTheme.titleMedium),
        Slider(value: value, min: 0, max: 5, divisions: 5, label: value.round().toString(), onChanged: onChanged),
      ],
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

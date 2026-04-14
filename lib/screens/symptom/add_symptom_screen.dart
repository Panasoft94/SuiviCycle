import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/symptom.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════════════════
// ADD / EDIT SYMPTOM SCREEN
// ═══════════════════════════════════════════════════

class AddSymptomScreen extends StatefulWidget {
  final int cycleId;
  final Symptom? symptomToEdit;

  const AddSymptomScreen({
    super.key,
    required this.cycleId,
    this.symptomToEdit,
  });

  @override
  State<AddSymptomScreen> createState() => _AddSymptomScreenState();
}

class _AddSymptomScreenState extends State<AddSymptomScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();

  String? _selectedMood;
  double _painLevel = 0;
  double _energyLevel = 3;
  double _libidoLevel = 3;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  late final AnimationController _animController;

  bool get _isEditing => widget.symptomToEdit != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    if (_isEditing) {
      final s = widget.symptomToEdit!;
      _selectedMood = s.mood;
      _painLevel = s.painLevel?.toDouble() ?? 0;
      _energyLevel = s.energyLevel?.toDouble() ?? 3;
      _libidoLevel = s.libidoLevel?.toDouble() ?? 3;
      _notesController.text = s.notes ?? '';
      _selectedDate = s.date;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier l\'entrée' : 'Nouvelle entrée',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: true,
        leading: const AppBackButton(),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            // ── Date selector ──
            _buildAnimatedSection(
              delay: 0,
              child: _buildDateCard(cs),
            ),
            const SizedBox(height: 20),

            // ── Mood selector ──
            _buildAnimatedSection(
              delay: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('😊', 'Humeur', cs),
                  const SizedBox(height: 12),
                  _buildMoodGrid(cs),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Indicators ──
            _buildAnimatedSection(
              delay: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('📊', 'Indicateurs', cs),
                  const SizedBox(height: 12),
                  _buildSliderCard(
                    label: 'Niveau de douleur',
                    value: _painLevel,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFEF5350),
                    emoji: _painEmoji(_painLevel),
                    onChanged: (v) => setState(() => _painLevel = v),
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _buildSliderCard(
                    label: "Niveau d'énergie",
                    value: _energyLevel,
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFF9800),
                    emoji: _energyEmoji(_energyLevel),
                    onChanged: (v) => setState(() => _energyLevel = v),
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _buildSliderCard(
                    label: 'Niveau de libido',
                    value: _libidoLevel,
                    icon: Icons.favorite_rounded,
                    color: const Color(0xFFEC407A),
                    emoji: _libidoEmoji(_libidoLevel),
                    onChanged: (v) => setState(() => _libidoLevel = v),
                    cs: cs,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Notes ──
            _buildAnimatedSection(
              delay: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('📝', 'Notes', cs),
                  const SizedBox(height: 12),
                  _buildNotesField(cs),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(cs),
    );
  }

  // ═══════════════════════════════════════
  // ANIMATED SECTION WRAPPER
  // ═══════════════════════════════════════

  Widget _buildAnimatedSection({
    required int delay,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        final adjusted = ((value - delay / 1000) * (1000 / 500)).clamp(0.0, 1.0);
        return Opacity(
          opacity: adjusted,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - adjusted)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  // ═══════════════════════════════════════
  // DATE CARD
  // ═══════════════════════════════════════

  Widget _buildDateCard(ColorScheme cs) {
    final dateFormatted =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return GestureDetector(
      onTap: _isEditing ? null : () => _pickDate(cs),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withAlpha(80),
              cs.primaryContainer.withAlpha(40),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.calendar_today_rounded,
                  color: cs.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(dateFormatted),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday ? "Aujourd'hui" : 'Appuyez pour changer',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isEditing)
              Icon(Icons.edit_calendar_rounded,
                  color: cs.primary.withAlpha(150), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(ColorScheme cs) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _selectedDate = picked);
    }
  }

  // ═══════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════

  Widget _buildSectionHeader(String emoji, String title, ColorScheme cs) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(color: cs.outlineVariant.withAlpha(60), thickness: 1),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // MOOD GRID
  // ═══════════════════════════════════════

  Widget _buildMoodGrid(ColorScheme cs) {
    const moods = [
      _MoodOption('Heureuse', '😊', Color(0xFFFFC107)),
      _MoodOption('Triste', '😢', Color(0xFF42A5F5)),
      _MoodOption('En colère', '😡', Color(0xFFEF5350)),
      _MoodOption('Anxieuse', '😰', Color(0xFFAB47BC)),
      _MoodOption('Calme', '😌', Color(0xFF66BB6A)),
      _MoodOption('Énergique', '⚡', Color(0xFFFF9800)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: moods.map((mood) {
        final isSelected = _selectedMood == mood.label;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() =>
                _selectedMood = isSelected ? null : mood.label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? mood.color.withAlpha(30)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? mood.color.withAlpha(120)
                    : cs.outlineVariant.withAlpha(60),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: mood.color.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  mood.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? mood.color : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════
  // SLIDER CARD
  // ═══════════════════════════════════════

  Widget _buildSliderCard({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    required String emoji,
    required ValueChanged<double> onChanged,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Text(
                  '${value.toInt()}/5',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(6, (i) {
              final filled = i <= value.toInt();
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                  decoration: BoxDecoration(
                    color:
                        filled ? color.withAlpha(180) : color.withAlpha(30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: color,
              inactiveTrackColor: color.withAlpha(35),
              thumbColor: color,
              overlayColor: color.withAlpha(25),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 5,
              divisions: 5,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // NOTES FIELD
  // ═══════════════════════════════════════

  Widget _buildNotesField(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(50)),
      ),
      child: TextField(
        controller: _notesController,
        focusNode: _notesFocus,
        decoration: InputDecoration(
          hintText: 'Comment vous sentez-vous aujourd\'hui ?',
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withAlpha(120),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Icon(Icons.notes_rounded,
                color: cs.onSurfaceVariant.withAlpha(120), size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        maxLines: 4,
        minLines: 3,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface,
          height: 1.5,
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  // ═══════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════

  Widget _buildBottomBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(40)),
        ),
      ),
      child: Row(
        children: [
          // Quick summary
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Modification' : 'Nouvelle entrée',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_selectedMood != null) ...[
                      Text(
                        _getMoodEmoji(_selectedMood),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _miniIndicator(Icons.warning_amber_rounded,
                        _painLevel.toInt(), const Color(0xFFEF5350)),
                    const SizedBox(width: 4),
                    _miniIndicator(Icons.bolt_rounded,
                        _energyLevel.toInt(), const Color(0xFFFF9800)),
                    const SizedBox(width: 4),
                    _miniIndicator(Icons.favorite_rounded,
                        _libidoLevel.toInt(), const Color(0xFFEC407A)),
                  ],
                ),
              ],
            ),
          ),

          // Save button
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveSymptom,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              _isSaving ? 'Enregistrement...' : 'Enregistrer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniIndicator(IconData icon, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // SAVE
  // ═══════════════════════════════════════

  void _saveSymptom() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (!_isEditing) {
        final newSymptom = Symptom(
          cycleId: widget.cycleId,
          date: _selectedDate,
          mood: _selectedMood,
          painLevel: _painLevel.toInt(),
          energyLevel: _energyLevel.toInt(),
          libidoLevel: _libidoLevel.toInt(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await _dbHelper.insertSymptom(newSymptom);
      } else {
        final updatedSymptom = Symptom(
          id: widget.symptomToEdit!.id,
          cycleId: widget.symptomToEdit!.cycleId,
          date: widget.symptomToEdit!.date,
          mood: _selectedMood,
          painLevel: _painLevel.toInt(),
          energyLevel: _energyLevel.toInt(),
          libidoLevel: _libidoLevel.toInt(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await _dbHelper.updateSymptom(updatedSymptom);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(_isEditing
                    ? 'Entrée modifiée avec succès'
                    : 'Entrée enregistrée avec succès'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Erreur lors de l\'enregistrement')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // EMOJI HELPERS
  // ═══════════════════════════════════════

  String _painEmoji(double level) {
    if (level <= 0) return '😌';
    if (level <= 1) return '🙂';
    if (level <= 2) return '😐';
    if (level <= 3) return '😣';
    if (level <= 4) return '😖';
    return '😫';
  }

  String _energyEmoji(double level) {
    if (level <= 0) return '😴';
    if (level <= 1) return '🥱';
    if (level <= 2) return '😐';
    if (level <= 3) return '🙂';
    if (level <= 4) return '😊';
    return '⚡';
  }

  String _libidoEmoji(double level) {
    if (level <= 0) return '😶';
    if (level <= 1) return '🙂';
    if (level <= 2) return '😊';
    if (level <= 3) return '😏';
    if (level <= 4) return '🥰';
    return '🔥';
  }

  String _getMoodEmoji(String? mood) {
    switch (mood) {
      case 'Heureuse':
        return '😊';
      case 'Triste':
        return '😢';
      case 'En colère':
        return '😡';
      case 'Anxieuse':
        return '😰';
      case 'Calme':
        return '😌';
      case 'Énergique':
        return '⚡';
      default:
        return '📝';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ═══════════════════════════════════════════════════
// MOOD OPTION MODEL
// ═══════════════════════════════════════════════════

class _MoodOption {
  final String label;
  final String emoji;
  final Color color;
  const _MoodOption(this.label, this.emoji, this.color);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database_helper.dart';
import '../../models/symptom.dart';
import '../../utils/widgets.dart';
import 'add_symptom_screen.dart';

// ═══════════════════════════════════════
// SYMPTOM SCREEN — JOURNAL DES SYMPTÔMES
// ═══════════════════════════════════════

class SymptomScreen extends StatefulWidget {
  final int cycleId;
  const SymptomScreen({super.key, required this.cycleId});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

enum _ChartFilter { pain, energy, libido }

class _SymptomScreenState extends State<SymptomScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_SymptomData> _dataFuture;
  _ChartFilter _selectedFilter = _ChartFilter.pain;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<_SymptomData> _fetchData() async {
    final symptoms = await _dbHelper.getSymptomsForCycle(widget.cycleId);
    symptoms.sort((a, b) => a.date.compareTo(b.date));

    // Calculer les moyennes
    double avgPain = 0, avgEnergy = 0, avgLibido = 0;
    int painCount = 0, energyCount = 0, libidoCount = 0;
    final Map<String, int> moodCounts = {};

    for (final s in symptoms) {
      if (s.painLevel != null) {
        avgPain += s.painLevel!;
        painCount++;
      }
      if (s.energyLevel != null) {
        avgEnergy += s.energyLevel!;
        energyCount++;
      }
      if (s.libidoLevel != null) {
        avgLibido += s.libidoLevel!;
        libidoCount++;
      }
      if (s.mood != null && s.mood!.isNotEmpty) {
        moodCounts[s.mood!] = (moodCounts[s.mood!] ?? 0) + 1;
      }
    }

    // Humeur dominante
    String? dominantMood;
    if (moodCounts.isNotEmpty) {
      dominantMood = moodCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return _SymptomData(
      symptoms: symptoms,
      avgPain: painCount > 0 ? avgPain / painCount : 0,
      avgEnergy: energyCount > 0 ? avgEnergy / energyCount : 0,
      avgLibido: libidoCount > 0 ? avgLibido / libidoCount : 0,
      dominantMood: dominantMood,
      totalEntries: symptoms.length,
    );
  }

  void _navigateToAdd({Symptom? symptomToEdit}) async {
    final result = await Navigator.push(
      context,
      slideTransition(AddSymptomScreen(
        cycleId: widget.cycleId,
        symptomToEdit: symptomToEdit,
      )),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<_SymptomData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(cs),
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data;
          if (data == null || data.symptoms.isEmpty) {
            return _buildEmptyState(cs);
          }

          return _buildContent(data, cs);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle entrée',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
    );
  }

  // ═══════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════

  SliverAppBar _buildAppBar(ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      leading: const AppBackButton(),
      title: const Text('Journal des Symptômes',
          style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════

  Widget _buildEmptyState(ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(cs),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primaryContainer.withAlpha(60),
                            cs.primaryContainer.withAlpha(30),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withAlpha(20),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(Icons.edit_note_rounded,
                          size: 52, color: cs.primary.withAlpha(180)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Aucune entrée',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Commencez à enregistrer vos symptômes quotidiens pour ce cycle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => _navigateToAdd(),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Ajouter une entrée'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════

  Widget _buildContent(_SymptomData data, ColorScheme cs) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(cs),

        // ── Résumé du cycle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSummaryCard(data, cs),
          ),
        ),

        // ── Mini stats ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildAveragesRow(data, cs),
          ),
        ),

        // ── Graphique ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: _sectionTitle('📈 Évolution', cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _buildFilterChips(cs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildChart(data, cs),
          ),
        ),

        // ── Liste des entrées ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: _sectionTitle(
                '📝 Entrées (${data.totalEntries})', cs),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final symptom =
                    data.symptoms[data.symptoms.length - 1 - index];
                return _SymptomCard(
                  symptom: symptom,
                  index: index,
                  onTap: () => _navigateToAdd(symptomToEdit: symptom),
                  onDelete: () => _confirmDelete(symptom),
                );
              },
              childCount: data.symptoms.length,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // SUMMARY CARD
  // ═══════════════════════════════════════

  Widget _buildSummaryCard(_SymptomData data, ColorScheme cs) {
    final moodEmoji = _getMoodEmoji(data.dominantMood);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withAlpha(200),
              cs.tertiary.withAlpha(180),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${data.totalEntries} entrée${data.totalEntries > 1 ? 's' : ''} enregistrée${data.totalEntries > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Résumé du cycle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.dominantMood != null
                        ? 'Humeur dominante : ${data.dominantMood}'
                        : 'Aucune humeur enregistrée',
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Text(
                moodEmoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // AVERAGES ROW
  // ═══════════════════════════════════════

  Widget _buildAveragesRow(_SymptomData data, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _avgCard(
            Icons.warning_amber_rounded,
            'Douleur',
            data.avgPain,
            const Color(0xFFEF5350),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _avgCard(
            Icons.bolt_rounded,
            'Énergie',
            data.avgEnergy,
            const Color(0xFFFF9800),
            cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _avgCard(
            Icons.favorite_rounded,
            'Libido',
            data.avgLibido,
            const Color(0xFFEC407A),
            cs,
          ),
        ),
      ],
    );
  }

  Widget _avgCard(IconData icon, String label, double value, Color color,
      ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(18), color.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text('${value.toStringAsFixed(1)}/5',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════

  Widget _buildFilterChips(ColorScheme cs) {
    final filters = [
      _FilterInfo(_ChartFilter.pain, 'Douleur', Icons.warning_amber_rounded,
          const Color(0xFFEF5350)),
      _FilterInfo(_ChartFilter.energy, 'Énergie', Icons.bolt_rounded,
          const Color(0xFFFF9800)),
      _FilterInfo(_ChartFilter.libido, 'Libido', Icons.favorite_rounded,
          const Color(0xFFEC407A)),
    ];

    return Row(
      children: filters.map((f) {
        final selected = _selectedFilter == f.filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = f.filter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? f.color.withAlpha(25) : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? f.color.withAlpha(100)
                      : cs.outlineVariant.withAlpha(60),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.icon,
                      size: 14,
                      color: selected ? f.color : cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? f.color : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════
  // CHART
  // ═══════════════════════════════════════

  Widget _buildChart(_SymptomData data, ColorScheme cs) {
    final spots = _getSpots(data.symptoms);
    final filterColor = _getFilterColor();

    if (spots.length < 2) {
      return Container(
        height: 120,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withAlpha(60)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 28, color: cs.outline.withAlpha(120)),
              const SizedBox(height: 8),
              Text(
                'Ajoutez au moins 2 entrées\npour voir l\'évolution',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outlineVariant.withAlpha(40),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (spots.length / 5).ceilToDouble().clamp(1, 10),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.symptoms.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    DateFormat('d/M').format(data.symptoms[idx].date),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final idx = spot.x.toInt();
                final symptom = data.symptoms[idx];
                return LineTooltipItem(
                  '${DateFormat('d MMM', 'fr_FR').format(symptom.date)}\n${spot.y.toInt()}/5',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: filterColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: filterColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    filterColor.withAlpha(60),
                    filterColor.withAlpha(10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  List<FlSpot> _getSpots(List<Symptom> symptoms) {
    return symptoms.asMap().entries.map((entry) {
      final s = entry.value;
      double y;
      switch (_selectedFilter) {
        case _ChartFilter.pain:
          y = s.painLevel?.toDouble() ?? 0;
        case _ChartFilter.energy:
          y = s.energyLevel?.toDouble() ?? 0;
        case _ChartFilter.libido:
          y = s.libidoLevel?.toDouble() ?? 0;
      }
      return FlSpot(entry.key.toDouble(), y);
    }).toList();
  }

  Color _getFilterColor() {
    switch (_selectedFilter) {
      case _ChartFilter.pain:
        return const Color(0xFFEF5350);
      case _ChartFilter.energy:
        return const Color(0xFFFF9800);
      case _ChartFilter.libido:
        return const Color(0xFFEC407A);
    }
  }

  // ═══════════════════════════════════════
  // DELETE
  // ═══════════════════════════════════════

  void _confirmDelete(Symptom symptom) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_forever_rounded,
              color: Colors.red, size: 28),
        ),
        title: const Text('Supprimer cette entrée ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'L\'entrée du ${DateFormat('d MMMM', 'fr_FR').format(symptom.date)} sera définitivement supprimée.',
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await _dbHelper.deleteSymptom(symptom.id!);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface)),
        const SizedBox(width: 10),
        Expanded(
          child:
              Divider(color: cs.outlineVariant.withAlpha(60), thickness: 1),
        ),
      ],
    );
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
}

// ═══════════════════════════════════════════════════
// SYMPTOM CARD (avec animation d'entrée)
// ═══════════════════════════════════════════════════

class _SymptomCard extends StatefulWidget {
  final Symptom symptom;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SymptomCard({
    required this.symptom,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_SymptomCard> createState() => _SymptomCardState();
}

class _SymptomCardState extends State<_SymptomCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 60 * widget.index.clamp(0, 8)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.symptom;
    final dateStr =
        DateFormat('EEEE d MMMM', 'fr_FR').format(s.date);
    final moodEmoji = _getMoodEmoji(s.mood);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: ValueKey(s.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            widget.onDelete();
            return false;
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withAlpha(5),
                  Colors.red.withAlpha(25),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded,
                color: Colors.red, size: 22),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      if (moodEmoji.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(moodEmoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _capitalize(dateStr),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                            ),
                            if (s.mood != null)
                              Text(
                                s.mood!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant.withAlpha(120),
                          size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Indicators ──
                  Row(
                    children: [
                      _indicatorTag(
                        Icons.warning_amber_rounded,
                        '${s.painLevel ?? 0}',
                        const Color(0xFFEF5350),
                        cs,
                      ),
                      const SizedBox(width: 8),
                      _indicatorTag(
                        Icons.bolt_rounded,
                        '${s.energyLevel ?? 0}',
                        const Color(0xFFFF9800),
                        cs,
                      ),
                      const SizedBox(width: 8),
                      _indicatorTag(
                        Icons.favorite_rounded,
                        '${s.libidoLevel ?? 0}',
                        const Color(0xFFEC407A),
                        cs,
                      ),
                      const Spacer(),
                      // Visual dots
                      ...List.generate(5, (i) {
                        final val = s.painLevel ?? 0;
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            color: i < val
                                ? const Color(0xFFEF5350)
                                : cs.outlineVariant.withAlpha(50),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ],
                  ),

                  // ── Notes ──
                  if (s.notes != null && s.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withAlpha(80),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded,
                              size: 14,
                              color: cs.onSurfaceVariant.withAlpha(150)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.notes!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicatorTag(
      IconData icon, String value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$value/5',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ═══════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════

class _SymptomData {
  final List<Symptom> symptoms;
  final double avgPain;
  final double avgEnergy;
  final double avgLibido;
  final String? dominantMood;
  final int totalEntries;

  _SymptomData({
    required this.symptoms,
    required this.avgPain,
    required this.avgEnergy,
    required this.avgLibido,
    this.dominantMood,
    required this.totalEntries,
  });
}

class _FilterInfo {
  final _ChartFilter filter;
  final String label;
  final IconData icon;
  final Color color;
  const _FilterInfo(this.filter, this.label, this.icon, this.color);
}

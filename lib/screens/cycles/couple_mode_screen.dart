import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../database/database_helper.dart';
import '../../models/cycle.dart';
import '../../models/symptom.dart';
import '../../utils/string_extensions.dart';

// ═══════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════

class _CoupleData {
  final Cycle cycle;
  final int dayOfCycle;
  final int daysUntilPeriod;
  final int daysUntilOvulation;
  final bool isFertileWindow;
  final Symptom? todaySymptom;
  final double cycleProgress;
  final _PhaseInfo phaseInfo;

  _CoupleData({
    required this.cycle,
    required this.dayOfCycle,
    required this.daysUntilPeriod,
    required this.daysUntilOvulation,
    required this.isFertileWindow,
    this.todaySymptom,
    required this.cycleProgress,
    required this.phaseInfo,
  });
}

class _PhaseInfo {
  final String name;
  final String emoji;
  final Color color;
  final IconData icon;
  final String feeling;
  final String advice;
  final String whatToDo;

  const _PhaseInfo({
    required this.name,
    required this.emoji,
    required this.color,
    required this.icon,
    required this.feeling,
    required this.advice,
    required this.whatToDo,
  });
}

// ═══════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════

class CoupleModeScreen extends StatefulWidget {
  const CoupleModeScreen({super.key});

  @override
  State<CoupleModeScreen> createState() => _CoupleModeScreenState();
}

class _CoupleModeScreenState extends State<CoupleModeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<_CoupleData?> _dataFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _dataFuture = _loadData();
  }

  Future<_CoupleData?> _loadData() async {
    final cycles = await _dbHelper.getCycles();
    if (cycles.isEmpty || cycles.first.endDate != null) return null;

    final cycle = cycles.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final dayOfCycle = today.difference(start).inDays + 1;

    int daysUntilPeriod = 0;
    if (cycle.expectedPeriod != null) {
      daysUntilPeriod = cycle.expectedPeriod!.difference(today).inDays;
    }

    int daysUntilOvulation = 0;
    bool isFertile = false;
    if (cycle.ovulationDate != null) {
      final ovDay = DateTime(cycle.ovulationDate!.year, cycle.ovulationDate!.month, cycle.ovulationDate!.day);
      daysUntilOvulation = ovDay.difference(today).inDays;
      // Fenêtre fertile : 5 jours avant ovulation jusqu'au jour de l'ovulation
      isFertile = daysUntilOvulation >= 0 && daysUntilOvulation <= 5;
    }

    final totalLength = cycle.cycleLength ?? 28;
    final progress = (dayOfCycle / totalLength).clamp(0.0, 1.0);

    // Symptôme du jour
    Symptom? todaySymptom;
    if (cycle.id != null) {
      final symptoms = await _dbHelper.getSymptomsForCycle(cycle.id!);
      try {
        todaySymptom = symptoms.firstWhere(
          (s) => s.date.year == now.year && s.date.month == now.month && s.date.day == now.day,
        );
      } catch (_) {}
    }

    final phaseInfo = _getPhaseInfo(cycle.phase);

    return _CoupleData(
      cycle: cycle,
      dayOfCycle: dayOfCycle,
      daysUntilPeriod: daysUntilPeriod,
      daysUntilOvulation: daysUntilOvulation,
      isFertileWindow: isFertile,
      todaySymptom: todaySymptom,
      cycleProgress: progress,
      phaseInfo: phaseInfo,
    );
  }

  _PhaseInfo _getPhaseInfo(String? phase) {
    switch (phase) {
      case 'règles':
        return const _PhaseInfo(
          name: 'Règles',
          emoji: '🩸',
          color: Color(0xFFEF5350),
          icon: Icons.water_drop_rounded,
          feeling: 'Fatigue, crampes possibles, sensibilité accrue. Le corps se renouvelle.',
          advice: 'C\'est le moment de faire preuve de douceur et de patience.',
          whatToDo: 'Préparez une boisson chaude, proposez un film cocooning, évitez les sujets stressants.',
        );
      case 'folliculaire':
        return const _PhaseInfo(
          name: 'Folliculaire',
          emoji: '🌱',
          color: Color(0xFF66BB6A),
          icon: Icons.eco_rounded,
          feeling: 'L\'énergie remonte progressivement. Humeur positive, créativité en hausse.',
          advice: 'Profitez de cette période d\'énergie pour des activités ensemble !',
          whatToDo: 'Planifiez des sorties, essayez une nouvelle activité à deux, cuisinez ensemble.',
        );
      case 'ovulation':
        return const _PhaseInfo(
          name: 'Ovulation',
          emoji: '✨',
          color: Color(0xFFFF7043),
          icon: Icons.auto_awesome_rounded,
          feeling: 'Pic d\'énergie, confiance en soi, libido élevée. Peau souvent plus éclatante.',
          advice: 'C\'est le pic de connexion. L\'intimité et la complicité sont à leur maximum.',
          whatToDo: 'Organisez un dîner romantique, soyez attentionné, profitez de la connexion.',
        );
      case 'lutéale':
        return const _PhaseInfo(
          name: 'Lutéale',
          emoji: '🌙',
          color: Color(0xFFAB47BC),
          icon: Icons.nightlight_round,
          feeling: 'L\'énergie baisse, irritabilité possible, envies alimentaires, ballonnements.',
          advice: 'Un peu plus de patience, d\'écoute et de réconfort feront toute la différence.',
          whatToDo: 'Offrez un massage, évitez les conflits, proposez des soirées calmes à la maison.',
        );
      default:
        return const _PhaseInfo(
          name: 'En cours',
          emoji: '💕',
          color: Color(0xFFEC407A),
          icon: Icons.favorite_rounded,
          feeling: 'Chaque jour est différent. Soyez attentif aux signes.',
          advice: 'Restez à l\'écoute et soutenez-vous mutuellement.',
          whatToDo: 'Demandez-lui comment elle se sent, soyez présent et à l\'écoute.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CoupleData?>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data == null) {
          return _buildEmptyState();
        }
        return _buildDashboard(snap.data!);
      },
    );
  }

  // ═══════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary.withAlpha(20), cs.secondary.withAlpha(15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_rounded, size: 56, color: cs.primary),
            ),
            const SizedBox(height: 28),
            const Text('Mode Couple', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Comprenez mieux le cycle de votre partenaire pour une relation plus harmonieuse et bienveillante.',
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _emptyFeature(Icons.timeline_rounded, 'Suivi des phases en temps réel', cs),
                  const SizedBox(height: 12),
                  _emptyFeature(Icons.lightbulb_outline_rounded, 'Conseils personnalisés pour chaque phase', cs),
                  const SizedBox(height: 12),
                  _emptyFeature(Icons.mood_rounded, 'Baromètre d\'humeur quotidien', cs),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Démarrez un cycle dans l\'onglet Suivi pour activer le Mode Couple.',
              style: TextStyle(fontSize: 13, color: cs.outline, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFeature(IconData icon, String text, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))),
      ],
    );
  }

  // ═══════════════════════════════════════
  // MAIN DASHBOARD
  // ═══════════════════════════════════════

  Widget _buildDashboard(_CoupleData d) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // ── Hero Card ──
        _buildHeroCard(d, cs),
        const SizedBox(height: 20),

        // ── Phase Timeline ──
        _buildPhaseTimeline(d, cs),
        const SizedBox(height: 20),

        // ── Countdowns ──
        _buildCountdownRow(d, cs),
        const SizedBox(height: 20),

        // ── Fenêtre fertile ──
        if (d.cycle.ovulationDate != null) ...[
          _buildFertileIndicator(d, cs),
          const SizedBox(height: 20),
        ],

        // ── Baromètre humeur ──
        _buildMoodBarometer(d, cs),
        const SizedBox(height: 20),

        // ── Ce qu'elle ressent ──
        _buildSection('🫶 Ce qu\'elle peut ressentir', cs),
        _buildInfoBox(d.phaseInfo.feeling, d.phaseInfo.color, Icons.psychology_rounded, cs),
        const SizedBox(height: 16),

        // ── Conseil bienveillant ──
        _buildSection('💡 Conseil bienveillant', cs),
        _buildInfoBox(d.phaseInfo.advice, const Color(0xFFFFCA28), Icons.lightbulb_rounded, cs),
        const SizedBox(height: 16),

        // ── Que faire ──
        _buildSection('🎯 Ce que vous pouvez faire', cs),
        _buildInfoBox(d.phaseInfo.whatToDo, const Color(0xFF42A5F5), Icons.volunteer_activism_rounded, cs),
        const SizedBox(height: 20),

        // ── Dates clés ──
        _buildSection('📅 Dates clés', cs),
        _buildKeyDates(d, cs),
      ],
    );
  }

  // ═══════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════

  Widget _buildHeroCard(_CoupleData d, ColorScheme cs) {
    final pi = d.phaseInfo;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pi.color, pi.color.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: pi.color.withAlpha(60), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Indicateur circulaire
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: d.cycleProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('J${d.dayOfCycle}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('/ ${d.cycle.cycleLength ?? 28}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pi.emoji}  Phase ${pi.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Jour ${ d.dayOfCycle} du cycle',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Début : ${DateFormat('d MMM', 'fr_FR').format(d.cycle.startDate)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // PHASE TIMELINE
  // ═══════════════════════════════════════

  Widget _buildPhaseTimeline(_CoupleData d, ColorScheme cs) {
    final phases = [
      ('Règles', '🩸', const Color(0xFFEF5350), 'règles'),
      ('Folliculaire', '🌱', const Color(0xFF66BB6A), 'folliculaire'),
      ('Ovulation', '✨', const Color(0xFFFF7043), 'ovulation'),
      ('Lutéale', '🌙', const Color(0xFFAB47BC), 'lutéale'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Row(
        children: phases.asMap().entries.map((e) {
          final idx = e.key;
          final p = e.value;
          final isActive = d.cycle.phase == p.$4;
          final isPast = _isPhasePast(d.cycle.phase, p.$4);

          return Expanded(
            child: Column(
              children: [
                // Dot + Connector
                Row(
                  children: [
                    if (idx > 0)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isPast || isActive ? p.$3.withAlpha(180) : cs.outlineVariant.withAlpha(60),
                        ),
                      ),
                    Container(
                      width: isActive ? 32 : 22,
                      height: isActive ? 32 : 22,
                      decoration: BoxDecoration(
                        color: isActive ? p.$3 : isPast ? p.$3.withAlpha(100) : cs.outlineVariant.withAlpha(40),
                        shape: BoxShape.circle,
                        border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: isActive ? [BoxShadow(color: p.$3.withAlpha(80), blurRadius: 8)] : null,
                      ),
                      child: Center(
                        child: Text(p.$2, style: TextStyle(fontSize: isActive ? 14 : 10)),
                      ),
                    ),
                    if (idx < phases.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isPast ? p.$3.withAlpha(180) : cs.outlineVariant.withAlpha(60),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p.$1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? p.$3 : cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isPhasePast(String? current, String phaseKey) {
    const order = ['règles', 'folliculaire', 'ovulation', 'lutéale'];
    final ci = order.indexOf(current ?? '');
    final pi = order.indexOf(phaseKey);
    if (ci < 0 || pi < 0) return false;
    return pi < ci;
  }

  // ═══════════════════════════════════════
  // COUNTDOWN ROW
  // ═══════════════════════════════════════

  Widget _buildCountdownRow(_CoupleData d, ColorScheme cs) {
    return Row(
      children: [
        if (d.daysUntilOvulation > 0 && d.cycle.ovulationDate != null)
          Expanded(
            child: _countdownCard(
              '✨ Ovulation',
              d.daysUntilOvulation,
              const Color(0xFFFF7043),
              cs,
            ),
          ),
        if (d.daysUntilOvulation > 0 && d.cycle.ovulationDate != null && d.daysUntilPeriod > 0)
          const SizedBox(width: 12),
        if (d.daysUntilPeriod > 0)
          Expanded(
            child: _countdownCard(
              '🩸 Règles',
              d.daysUntilPeriod,
              const Color(0xFFEF5350),
              cs,
            ),
          ),
        if (d.daysUntilPeriod <= 0 && (d.daysUntilOvulation <= 0 || d.cycle.ovulationDate == null))
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text('Les dates approchent…', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _countdownCard(String label, int days, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withAlpha(18), color.withAlpha(8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text('$days', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.onSurface)),
          Text('jours', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // FERTILE WINDOW INDICATOR
  // ═══════════════════════════════════════

  Widget _buildFertileIndicator(_CoupleData d, ColorScheme cs) {
    final isFertile = d.isFertileWindow;
    final color = isFertile ? const Color(0xFFFF7043) : const Color(0xFF66BB6A);
    final icon = isFertile ? Icons.local_fire_department_rounded : Icons.shield_rounded;
    final title = isFertile ? 'Fenêtre fertile active' : 'Hors fenêtre fertile';
    final subtitle = isFertile
        ? 'La fertilité est élevée en ce moment. Période propice à la conception.'
        : 'La période fertile est passée ou n\'a pas encore commencé.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // MOOD BAROMETER
  // ═══════════════════════════════════════

  Widget _buildMoodBarometer(_CoupleData d, ColorScheme cs) {
    final s = d.todaySymptom;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mood_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Baromètre du jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          if (s == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun symptôme enregistré aujourd\'hui.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ),
            )
          else ...[
            if (s.mood != null && s.mood!.isNotEmpty)
              _barometerRow('Humeur', _moodEmoji(s.mood!), s.mood!, cs),
            if (s.painLevel != null) ...[
              const SizedBox(height: 12),
              _levelBar('Douleur', s.painLevel!, 5, const Color(0xFFEF5350), cs),
            ],
            if (s.energyLevel != null) ...[
              const SizedBox(height: 12),
              _levelBar('Énergie', s.energyLevel!, 5, const Color(0xFFFFCA28), cs),
            ],
            if (s.libidoLevel != null) ...[
              const SizedBox(height: 12),
              _levelBar('Libido', s.libidoLevel!, 5, const Color(0xFFEC407A), cs),
            ],
            if (s.notes != null && s.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.notes!,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _moodEmoji(String mood) {
    const map = {
      'Heureuse': '😊', 'Triste': '😢', 'Anxieuse': '😰', 'Irritée': '😤',
      'Calme': '😌', 'Fatiguée': '😴', 'Énergique': '⚡', 'Stressée': '😫',
      'Sensible': '🥺', 'Normale': '🙂',
    };
    return map[mood] ?? '🫥';
  }

  Widget _barometerRow(String label, String emoji, String value, ColorScheme cs) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
          ],
        ),
      ],
    );
  }

  Widget _levelBar(String label, int value, int max, Color color, ColorScheme cs) {
    final frac = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('$value/$max', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // INFO BOX
  // ═══════════════════════════════════════

  Widget _buildInfoBox(String text, Color color, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // KEY DATES
  // ═══════════════════════════════════════

  Widget _buildKeyDates(_CoupleData d, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        children: [
          _dateTile(Icons.play_arrow_rounded, 'Début du cycle', d.cycle.startDate, const Color(0xFF66BB6A), cs),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withAlpha(60)),
          if (d.cycle.periodEndDate != null) ...[
            _dateTile(Icons.stop_rounded, 'Fin des règles', d.cycle.periodEndDate!, const Color(0xFFEF5350), cs),
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withAlpha(60)),
          ],
          if (d.cycle.ovulationDate != null) ...[
            _dateTile(Icons.brightness_7_rounded, 'Ovulation prévue', d.cycle.ovulationDate!, const Color(0xFFFF7043), cs),
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withAlpha(60)),
          ],
          if (d.cycle.expectedPeriod != null)
            _dateTile(Icons.event_rounded, 'Prochaines règles', d.cycle.expectedPeriod!, const Color(0xFFEF5350), cs),
        ],
      ),
    );
  }

  Widget _dateTile(IconData icon, String label, DateTime date, Color color, ColorScheme cs) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        DateFormat('d MMM', 'fr_FR').format(date),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
      ),
    );
  }

  // ═══════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════

  Widget _buildSection(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
    );
  }
}

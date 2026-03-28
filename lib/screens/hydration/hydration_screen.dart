import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../utils/widgets.dart';
import 'package:intl/intl.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  double _currentAmount = 0.0;
  final double _goal = 2.0; // Daily goal in Liters
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final amount = await _dbHelper.getTodayTotalHydration();
    final history = await _dbHelper.getHydrationHistory(10);
    setState(() {
      _currentAmount = amount;
      _history = history;
    });
  }

  Future<void> _addWater(double amount) async {
    await _dbHelper.insertHydration({
      'date': DateTime.now().toIso8601String(),
      'amount': amount,
      'goal_met': (_currentAmount + amount >= _goal) ? 1 : 0,
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double progress = (_currentAmount / _goal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydratation', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildProgressCard(colorScheme, progress),
            const SizedBox(height: 32),
            _buildQuickAddButtons(colorScheme),
            const SizedBox(height: 32),
            _buildHistorySection(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ColorScheme colorScheme, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.water_drop_rounded, color: Colors.white, size: 32),
                  Text(
                    '${_currentAmount.toStringAsFixed(1)}L',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Objectif: ${_goal}L',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            progress >= 1.0 ? "Objectif atteint ! Félicitations !" : "Encore un petit effort !",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ajout rapide", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildWaterButton(0.2, "200ml", Icons.local_drink_rounded, colorScheme),
            _buildWaterButton(0.33, "330ml", Icons.local_drink_rounded, colorScheme),
            _buildWaterButton(0.5, "500ml", Icons.local_drink_rounded, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterButton(double amount, String label, IconData icon, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _addWater(amount),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.primary.withAlpha(40)),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Historique récent", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_history.isEmpty)
          const Center(child: Text("Aucun enregistrement aujourd'hui.", style: TextStyle(color: Colors.grey)))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final date = DateTime.parse(item['date']);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop_outlined, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('+${item['amount']}L', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<AppSettings> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _dbHelper.getSettings();
  }

  void _updateSettings(AppSettings settings) {
    _dbHelper.updateSettings(settings);
    setState(() {
      _settingsFuture = Future.value(settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Aucun paramètre trouvé.'));
        }

        final settings = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('Cycle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: _buildCycleLengthTile(settings),
            ),
            const SizedBox(height: 24),

            Text('Notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Column(
                children: [
                  _buildNotificationTile('Notifications des règles', settings.notifyPeriod, (value) {
                    _updateSettings(AppSettings(
                      id: settings.id,
                      defaultCycleLength: settings.defaultCycleLength,
                      notifyPeriod: value,
                      notifyOvulation: settings.notifyOvulation,
                      theme: settings.theme,
                    ));
                  }),
                  const Divider(indent: 16, endIndent: 16),
                  _buildNotificationTile('Notifications d\'ovulation', settings.notifyOvulation, (value) {
                    _updateSettings(AppSettings(
                      id: settings.id,
                      defaultCycleLength: settings.defaultCycleLength,
                      notifyPeriod: settings.notifyPeriod,
                      notifyOvulation: value,
                      theme: settings.theme,
                    ));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Apparence', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: _buildThemeTile(settings),
            ),
          ],
        );
      },
    );
  }

  ListTile _buildCycleLengthTile(AppSettings settings) {
    return ListTile(
      leading: const Icon(Icons.sync_alt),
      title: const Text('Durée du cycle par défaut'),
      subtitle: Text('${settings.defaultCycleLength} jours'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () async {
        final newLength = await _showCycleLengthPicker(context, settings.defaultCycleLength);
        if (newLength != null && newLength != settings.defaultCycleLength) {
          _updateSettings(AppSettings(
            id: settings.id,
            defaultCycleLength: newLength,
            notifyPeriod: settings.notifyPeriod,
            notifyOvulation: settings.notifyOvulation,
            theme: settings.theme,
          ));
        }
      },
    );
  }

  SwitchListTile _buildNotificationTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  ListTile _buildThemeTile(AppSettings settings) {
    return ListTile(
      leading: const Icon(Icons.color_lens_outlined),
      title: const Text("Thème de l'application"),
      subtitle: Text(settings.theme == 'light' ? 'Clair' : 'Sombre'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        final newTheme = settings.theme == 'light' ? 'dark' : 'light';
        _updateSettings(AppSettings(
          id: settings.id,
          defaultCycleLength: settings.defaultCycleLength,
          notifyPeriod: settings.notifyPeriod,
          notifyOvulation: settings.notifyOvulation,
          theme: newTheme,
        ));
        // TODO: Implement theme switching logic in main.dart
      },
    );
  }

  Future<int?> _showCycleLengthPicker(BuildContext context, int initialValue) {
    return showDialog<int>(
      context: context,
      builder: (context) {
        int selectedValue = initialValue;
        return AlertDialog(
          title: const Text('Choisir la durée du cycle'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButton<int>(
                value: selectedValue,
                items: List.generate(40, (index) => index + 15).map((int value) {
                  return DropdownMenuItem<int>(value: value, child: Text('$value jours'));
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() => selectedValue = newValue);
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(context).pop(selectedValue), child: const Text('OK')),
          ],
        );
      },
    );
  }
}

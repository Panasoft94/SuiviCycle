import '../user_account/create_pin.dart';
import '../user_account/user_account_screen.dart';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/settings.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../main.dart'; // Import main.dart to access MyAppState

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BackupService _backupService = BackupService(); 
  final NotificationService _notificationService = NotificationService();
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

    // Update notifications based on new settings
    if (!settings.notifyPeriod) _notificationService.cancelNotification(1);
    if (!settings.notifyOvulation) _notificationService.cancelNotification(0);

    // You might want to re-schedule notifications here if they are enabled
    // but the logic is currently in the dashboard screen.
  }

  PageRouteBuilder _slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildSectionHeader('Cycle & Prédictions'),
            _buildSettingsCard([
              _buildCycleLengthTile(settings),
            ]),
            const SizedBox(height: 24),

            _buildSectionHeader('Notifications'),
            _buildSettingsCard([
              _buildNotificationTile('Notifications des règles', settings.notifyPeriod, (value) {
                _updateSettings(AppSettings(
                  id: settings.id,
                  defaultCycleLength: settings.defaultCycleLength,
                  notifyPeriod: value,
                  notifyOvulation: settings.notifyOvulation,
                  theme: settings.theme,
                ));
              }),
              const Divider(indent: 70, height: 1),
              _buildNotificationTile('Notifications d\'ovulation', settings.notifyOvulation, (value) {
                _updateSettings(AppSettings(
                  id: settings.id,
                  defaultCycleLength: settings.defaultCycleLength,
                  notifyPeriod: settings.notifyPeriod,
                  notifyOvulation: value,
                  theme: settings.theme,
                ));
              }),
            ]),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Sécurité'),
            _buildSettingsCard([
              ListTile(
                leading: _buildIconContainer(Icons.security_rounded, Colors.green),
                title: const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('PIN & Biométrie'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final bool userExists = await _dbHelper.hasUser();
                  if (!mounted) return;
                  if (userExists) {
                    Navigator.push(context, _slideTransition(const UserAccountScreen()));
                  } else {
                    Navigator.push(context, _slideTransition(const CreatePinPage()));
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),

            _buildSectionHeader('Personnalisation'),
            _buildSettingsCard([
              _buildThemeTile(settings),
            ]),
            const SizedBox(height: 24),

            _buildSectionHeader('Maintenance des données'),
            _buildSettingsCard([
              _buildActionTile(Icons.backup_rounded, 'Sauvegarder', Colors.blue, () => _backupService.backupDatabase(context)),
              const Divider(indent: 70, height: 1),
              _buildActionTile(Icons.restore_page_rounded, 'Restaurer', Colors.orange, () => _showRestoreConfirmation(context)),
              const Divider(indent: 70, height: 1),
              _buildActionTile(Icons.delete_forever_rounded, 'Réinitialiser', Colors.red, () => _showResetConfirmation(context), isDestructive: true),
            ]),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: _buildIconContainer(icon, color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDestructive ? Colors.red : null)),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary.withAlpha(180),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showRestoreConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restaurer les données ?'),
          content: const Text(
              'Attention ! Cela remplacera toutes les données actuelles par celles de la sauvegarde. Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Restaurer', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _backupService.restoreDatabase(context);
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Réinitialiser l\'application ?'),
          content: const Text(
              'Attention ! Toutes vos données (cycles, symptômes, notes) seront définitivement effacées. Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Réinitialiser', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _dbHelper.deleteDatabase();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application réinitialisée. Veuillez redémarrer.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  ListTile _buildCycleLengthTile(AppSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _buildIconContainer(Icons.sync_alt_rounded, colorScheme.primary),
      title: const Text('Durée du cycle', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('${settings.defaultCycleLength} jours'),
      trailing: const Icon(Icons.chevron_right_rounded),
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
      secondary: _buildIconContainer(Icons.notifications_active_rounded, Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      value: value,
      onChanged: onChanged,
    );
  }

  ListTile _buildThemeTile(AppSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _buildIconContainer(Icons.palette_rounded, colorScheme.primary),
      title: const Text("Thème visuel", style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(settings.theme == 'light' ? 'Mode Clair' : 'Mode Sombre'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        final newTheme = settings.theme == 'light' ? 'dark' : 'light';
        _updateSettings(AppSettings(
          id: settings.id,
          defaultCycleLength: settings.defaultCycleLength,
          notifyPeriod: settings.notifyPeriod,
          notifyOvulation: settings.notifyOvulation,
          theme: newTheme,
        ));
        MyApp.of(context).changeTheme(newTheme == 'dark' ? ThemeMode.dark : ThemeMode.light);
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

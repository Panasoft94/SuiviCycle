import 'package:cycles/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:cycles/database/database_helper.dart';

class CreatePinPage extends StatefulWidget {
  const CreatePinPage({super.key});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  final TextEditingController _pinController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _allowBiometricAccess = false; // State for the switch

  void _saveUserAndNavigate() async {
    if (_pinController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code PIN de 4 chiffres.'), backgroundColor: Colors.red),
      );
      return;
    }

    final newUser = {
      'user_pin': _pinController.text,
      'user_name': 'Utilisateur', // Default name
      'user_email': '',
      'user_phone': '',
      'user_status': 1,
      'access_empreinte': _allowBiometricAccess ? 1 : 0, // Use the new field
    };

    await _dbHelper.insertUser(newUser);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Votre code PIN a été créé avec succès !'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE91E63),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sécurité", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_person_rounded, size: 64, color: colorScheme.primary),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Configurez votre PIN",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  "Choisissez un code à 4 chiffres pour protéger vos données personnelles.",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Pinput(
                  length: 4, 
                  obscureText: true,
                  autofocus: true,
                  controller: _pinController,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 60,
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 60,
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    title: const Text("Accès biométrique"),
                    subtitle: const Text("Utiliser l'empreinte ou le visage"),
                    value: _allowBiometricAccess,
                    onChanged: (bool value) {
                      setState(() {
                        _allowBiometricAccess = value;
                      });
                    },
                    secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _saveUserAndNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Continuer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

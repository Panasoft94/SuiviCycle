import 'package:cycles/database/database_helper.dart';
import 'package:flutter/material.dart';
import '../../utils/widgets.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isSaving = false;
  bool _oldPinVisible = false;
  bool _newPinVisible = false;
  bool _confirmPinVisible = false;
  bool _biometricAccessEnabled = false;
  bool _isLoadingBiometricStatus = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final user = await _dbHelper.getUser();
    if (mounted && user != null) {
      setState(() {
        _biometricAccessEnabled = user['access_empreinte'] == 1;
        _isLoadingBiometricStatus = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingBiometricStatus = false;
      });
    }
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final user = await _dbHelper.getUser();
      bool success = false;

      if (user != null && user['user_pin'] == _oldPinController.text) {
        await _dbHelper.updateUserPin(_newPinController.text);
        success = true;
      }

      if (!mounted) return;

      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Code PIN modifié avec succès !'),
            backgroundColor: Colors.brown[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('L\'ancien code PIN est incorrect.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _onBiometricToggle(bool value) async {
    setState(() {
      _biometricAccessEnabled = value;
    });
    await _dbHelper.updateUser({'access_empreinte': value ? 1 : 0});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Accès par empreinte ${value ? "activé" : "désactivé"}.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            ), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité du compte', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, size: 48, color: colorScheme.primary),
              ),
              const SizedBox(height: 32),
              const Text(
                "Changer votre code PIN",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                "Entrez votre ancien code pour définir un nouveau code de sécurité.",
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              _buildPinField(
                controller: _oldPinController,
                label: 'Ancien code PIN',
                visible: _oldPinVisible,
                onToggleVisibility: () => setState(() => _oldPinVisible = !_oldPinVisible),
                icon: Icons.lock_open_rounded,
              ),
              const SizedBox(height: 16),
              _buildPinField(
                controller: _newPinController,
                label: 'Nouveau code PIN',
                visible: _newPinVisible,
                onToggleVisibility: () => setState(() => _newPinVisible = !_newPinVisible),
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 16),
              _buildPinField(
                controller: _confirmPinController,
                label: 'Confirmer le nouveau PIN',
                visible: _confirmPinVisible,
                onToggleVisibility: () => setState(() => _confirmPinVisible = !_confirmPinVisible),
                icon: Icons.lock_person_rounded,
              ),
              const SizedBox(height: 40),
              if (!_isLoadingBiometricStatus)
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SwitchListTile(
                    title: const Text("Accès biométrique"),
                    subtitle: const Text("Empreinte ou visage"),
                    secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
                    value: _biometricAccessEnabled,
                    onChanged: _onBiometricToggle,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              const SizedBox(height: 48),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _changePin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text("Sauvegarder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggleVisibility,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: const TextStyle(letterSpacing: 8, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.length != 4) return 'PIN de 4 chiffres requis.';
        return null;
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'package:another_flushbar/flushbar.dart';
import '../../database/database_helper.dart';

/// Écran de verrouillage automatique (affiché quand l'app revient du background).
/// Reprend le design de LoginPage mais ne navigue pas — il se ferme par-dessus.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _biometricAvailable = false;
  bool _isLoading = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = await _dbHelper.getUser();
    if (mounted) {
      setState(() => _user = user);
    }
    await _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _auth.canCheckBiometrics;
      if (mounted) {
        setState(() => _biometricAvailable = available);
        if (_biometricAvailable && _user != null && _user!['access_empreinte'] == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _biometricAuth();
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusPin();
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  void _onPinCompleted(String enteredPin) {
    if (_user == null) {
      _showFlushbar("Erreur : utilisateur introuvable.", Colors.orangeAccent);
      return;
    }
    if (enteredPin == _user!['user_pin'].toString()) {
      _unlock();
    } else {
      _showFlushbar("Code PIN incorrect !", Colors.red);
      _pinController.clear();
      Future.delayed(const Duration(milliseconds: 50), () => _focusPin());
    }
  }

  void _unlock() {
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _biometricAuth() async {
    if (!_biometricAvailable || _user == null || _isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Déverrouiller CycleTrack',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (authenticated) {
          _unlock();
        } else {
          _pinController.clear();
          Future.delayed(const Duration(milliseconds: 50), () => _focusPin());
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _pinController.clear();
        Future.delayed(const Duration(milliseconds: 50), () => _focusPin());
      }
    }
  }

  Future<void> _focusPin() async {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_pinFocusNode);
    await Future.delayed(const Duration(milliseconds: 50));
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _showFlushbar(String message, Color color) {
    if (!mounted) return;
    Flushbar(
      message: message,
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
      animationDuration: const Duration(milliseconds: 500),
      icon: const Icon(Icons.info_outline, color: Colors.white),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // ignore: deprecated_member_use
    return PopScope(
      canPop: false, // Empêcher le retour arrière
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ── Icône cadenas ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 48, color: colorScheme.primary),
                ),
                const SizedBox(height: 32),

                // ── Titre ──
                const Text(
                  "Application verrouillée",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  "Entrez votre PIN pour continuer",
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                ),
                const SizedBox(height: 48),

                // ── Champ PIN ──
                Pinput(
                  focusNode: _pinFocusNode,
                  controller: _pinController,
                  length: 4,
                  onCompleted: _onPinCompleted,
                  obscureText: true,
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

                const Spacer(),

                // ── Bouton biométrique ──
                if (_biometricAvailable && _user != null && _user!['access_empreinte'] == 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: InkWell(
                      onTap: _biometricAuth,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withAlpha(102),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint_rounded, size: 28, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              "Identification biométrique",
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


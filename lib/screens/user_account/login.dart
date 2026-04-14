import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:cycles/screens/home/home_screen.dart';
import 'package:cycles/database/database_helper.dart';
import 'package:flutter/services.dart';
import '../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController controller = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool biometricAvailable = false;
  bool isLoading = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    controller.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUser();
    await _checkBiometricAvailability();
  }

  Future<void> _loadUser() async {
    final user = await _dbHelper.getUser();
    if (mounted) {
      setState(() {
        _user = user;
      });
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      bool available = await auth.canCheckBiometrics;
      if (mounted) {
        setState(() {
          biometricAvailable = available;
        });
        if (biometricAvailable &&
            _user != null &&
            _user!['access_empreinte'] == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _biometricAuthentication();
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusPinField();
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur _checkBiometricAvailability: ${e.toString()}");
      if (mounted) {
        setState(() {
          biometricAvailable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 48, color: colorScheme.primary),
              ),
              const SizedBox(height: 32),
              const Text(
                "Bon retour !",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                "Entrez votre PIN pour déverrouiller",
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 48),
              Pinput(
                focusNode: _pinFocusNode,
                controller: controller,
                length: 4,
                onCompleted: _onCompleted,
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
              if (biometricAvailable &&
                  _user != null &&
                  _user!['access_empreinte'] == 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: InkWell(
                    onTap: _biometricAuthentication,
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
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
    );
  }

  void _onCompleted(String enteredPin) {
    if (_user == null) {
      _showFlushbar("Veuillez d'abord créer un code PIN.", Colors.orangeAccent);
      return;
    }
    if (enteredPin == _user!['user_pin'].toString()) {
      _redirectionHome();
    } else {
      _showFlushbar("Votre code pin de 4 chiffres est incorrect !", Colors.red);
      controller.clear();
      // ⚡ Correction : refocus + clavier automatique
      Future.delayed(const Duration(milliseconds: 50), () {
        _focusPinField();
      });
    }
  }

  void _redirectionHome() {
    if (!mounted) return;
    // Signaler à MyApp que le login initial est terminé
    // pour que le verrouillage auto puisse fonctionner normalement
    MyApp.of(context).markLoginCompleted();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) {
      return const HomeScreen();
    }));
  }

  Future<void> _biometricAuthentication() async {
    if (!biometricAvailable || _user == null) return;
    if (isLoading) return;

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Déverrouillage par empreinte biométrique !',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        if (authenticated) {
          _redirectionHome();
        } else {
          controller.clear();
          Future.delayed(const Duration(milliseconds: 50), () {
            _focusPinField();
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur _biometricAuthentication: ${e.toString()}");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        controller.clear();
        Future.delayed(const Duration(milliseconds: 50), () {
          _focusPinField();
        });
      }
    }
  }

  /// Force le focus sur le champ PIN et ouvre le clavier
  Future<void> _focusPinField() async {
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
}
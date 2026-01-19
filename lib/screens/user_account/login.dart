import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:cycles/screens/home/home_screen.dart';
import 'package:cycles/database/database_helper.dart';
import 'package:flutter/services.dart';

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
      print("Erreur _checkBiometricAvailability: ${e.toString()}");
      if (mounted) {
        setState(() {
          biometricAvailable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline),
            SizedBox(width: 8),
            Text('CycleTrack verrouillé'),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 6,
        toolbarHeight: 65,
        backgroundColor: Colors.brown,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text("Déverrouillage par code PIN",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.black)),
              const SizedBox(height: 10),
              const Text("Veuillez entrer votre code pin de 4 chiffres !",
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Pinput(
                focusNode: _pinFocusNode,
                controller: controller,
                length: 4,
                onCompleted: _onCompleted,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              const Spacer(),
              if (biometricAvailable &&
                  _user != null &&
                  _user!['access_empreinte'] == 1)
                Column(
                  children: <Widget>[
                    const Text("OU",
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 38),
                    InkWell(
                      onTap: _biometricAuthentication,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.brown,
                          border: Border.all(color: Colors.brown),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        )
                            : const Icon(Icons.fingerprint,
                            size: 65, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Empreinte biométrique"),
                  ],
                ),
              const SizedBox(height: 30),
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
      print("Erreur _biometricAuthentication: ${e.toString()}");
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
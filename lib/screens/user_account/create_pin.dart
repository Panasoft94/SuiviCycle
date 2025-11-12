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
          backgroundColor: Colors.brown[700],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer un code PIN"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  "Sécurisez votre compte",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Veuillez créer un code PIN de 4 chiffres.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Pinput(
                  length: 4, 
                  obscureText: true,
                  autofocus: true,
                  controller: _pinController,
                  mainAxisAlignment: MainAxisAlignment.center, 
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text("Activer l\'accès par empreinte digitale"),
                  value: _allowBiometricAccess,
                  onChanged: (bool value) {
                    setState(() {
                      _allowBiometricAccess = value;
                    });
                  },
                  secondary: const Icon(Icons.fingerprint),
                  activeColor: Colors.brown,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveUserAndNavigate,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                  child: const Text("Enregistrer", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cycles/database/database_helper.dart';
import 'package:cycles/screens/user_account/change_pin_screen.dart';
import 'package:flutter/material.dart';
import '../../utils/widgets.dart';

// --- Modèle de Données ---
class User {
  final int id;
  String name;
  String email;
  String phone;

  User({required this.id, required this.name, required this.email, required this.phone});

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['user_id'],
      name: map['user_name'] ?? '',
      email: map['user_email'] ?? '',
      phone: map['user_phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': id,
      'user_name': name,
      'user_email': email,
      'user_phone': phone,
      'user_updated_at': DateTime.now().toIso8601String(),
    };
  }
}

// --- Écran Principal ---
class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _updateUser(User user) async {
    await _dbHelper.updateUser(user.toMap());
    setState(() {}); // Rafraîchit l'UI pour afficher les nouvelles données
     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil mis à jour avec succès.'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEditProfileSheet(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _EditProfileForm(user: user, onSave: _updateUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Compte', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: const AppBackButton(),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _dbHelper.getUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: colorScheme.outline.withAlpha(128)),
                  const SizedBox(height: 16),
                  const Text("Aucun utilisateur trouvé."),
                ],
              ),
            );
          }
          final user = User.fromMap(snapshot.data!);
          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildProfileCard(user),
              const SizedBox(height: 32),
              _buildSectionHeader('Paramètres de sécurité'),
              _buildActionButton(
                icon: Icons.edit_rounded,
                title: 'Modifier le profil',
                onTap: () => _showEditProfileSheet(user),
                color: colorScheme.primary, // Changed from Colors.blue to theme primary
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.lock_rounded,
                title: 'Changer le code PIN',
                onTap: () {
                   Navigator.of(context).push(slideTransition(const ChangePinScreen()));
                },
                color: Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileCard(User user) {
    final colorScheme = Theme.of(context).colorScheme;
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
          BoxShadow(
            color: colorScheme.primary.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white24,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          _buildProfileInfoRow(Icons.email_rounded, user.email),
          const SizedBox(height: 12),
          _buildProfileInfoRow(Icons.phone_rounded, user.phone),
        ],
      ),
    );
  }
  
  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String title, required VoidCallback onTap, required Color color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(128)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

// --- Widget du Formulaire de Modification ---
class _EditProfileForm extends StatefulWidget {
  final User user;
  final Future<void> Function(User user) onSave;

  const _EditProfileForm({required this.user, required this.onSave});

  @override
  _EditProfileFormState createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Modifier le profil',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _nameController,
              label: 'Nom complet',
              icon: Icons.person_outline_rounded,
              validator: (value) => (value == null || value.isEmpty) ? 'Veuillez entrer un nom.' : null,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _emailController,
              label: 'Adresse e-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Veuillez entrer un e-mail.';
                if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(value)) {
                  return 'Veuillez entrer un e-mail valide.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) => (value == null || value.isEmpty) ? 'Veuillez entrer un numéro.' : null,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.user.name = _nameController.text;
                  widget.user.email = _emailController.text;
                  widget.user.phone = _phoneController.text;
                  widget.onSave(widget.user);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Enregistrer les modifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      validator: validator,
    );
  }
}

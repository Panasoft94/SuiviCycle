import 'package:cycles/screens/user_account/login.dart';
import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'database/database_helper.dart';
import 'models/settings.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
  
  static _MyAppState of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  ThemeMode _themeMode = ThemeMode.system;
  Widget _initialScreen = const Scaffold(body: Center(child: CircularProgressIndicator())); // Loading screen

  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
    _loadTheme();
  }

  Future<void> _determineInitialScreen() async {
    final bool userExists = await _dbHelper.hasUser();
    if (mounted) {
      setState(() {
        _initialScreen = userExists ? const LoginPage() : const HomeScreen();
      });
    }
  }

  void _loadTheme() async {
    final settings = await _dbHelper.getSettings();
    setState(() {
      _themeMode = settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CycleTrack',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.brown,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: _initialScreen,
    );
  }
}

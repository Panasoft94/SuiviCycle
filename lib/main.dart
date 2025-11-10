import 'package:flutter/material.dart';
import 'package:cycles/screens/home_screen.dart';
import 'package:cycles/database/database_helper.dart';
import 'package:cycles/models/settings.dart';
import 'package:cycles/services/notification_service.dart'; // Import the service

void main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await NotificationService().init(); // Initialize the notification service
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

  @override
  void initState() {
    super.initState();
    _loadTheme();
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
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        primarySwatch: Colors.brown,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}

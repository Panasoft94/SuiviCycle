import 'package:flutter/material.dart';
import 'package:cycles/screens/home_screen.dart';
import 'package:cycles/database/database_helper.dart';
import 'package:cycles/models/settings.dart';

void main() {
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
        // You can customize the light theme further here
      ),
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        primarySwatch: Colors.brown,
        brightness: Brightness.dark,
        // You can customize the dark theme further here
      ),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}

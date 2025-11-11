import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cycles/screens/home_screen.dart';
import 'package:cycles/database/database_helper.dart';
import 'package:cycles/models/settings.dart';
import 'package:cycles/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation sécurisée du service de notification
  try {
    await NotificationService().init();
  } catch (e, stack) {
    debugPrint('❌ Erreur init NotificationService: $e');
    debugPrintStack(stackTrace: stack);
  }

  // Activation des logs Flutter en release (optionnel)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('⚠️ FlutterError: ${details.exception}');
  };

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

  Future<void> _loadTheme() async {
    try {
      final settings = await _dbHelper.getSettings();
      if (mounted) {
        setState(() {
          _themeMode = settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement thème: $e');
    }
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
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
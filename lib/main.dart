import 'package:cycles/screens/user_account/login.dart';
import 'package:cycles/screens/user_account/lock_screen.dart';
import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'database/database_helper.dart';
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.system;
  Widget _initialScreen = const Scaffold(body: Center(child: CircularProgressIndicator())); // Loading screen

  bool _isLocked = false;
  bool _wasInBackground = false;
  bool _autoLockEnabled = false;
  bool _hasUserCached = false;
  bool _unlockCooldown = false; // empêche la re-boucle après déverrouillage
  bool _loginCompleted = false; // empêche le lock avant la fin du login initial

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determineInitialScreen();
    _loadTheme();
    _cacheAutoLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Pré-charge l'état du verrouillage pour éviter les appels DB async
  /// au moment critique du lifecycle (risque de race condition).
  Future<void> _cacheAutoLockState() async {
    try {
      final settings = await _dbHelper.getSettings();
      final hasUser = await _dbHelper.hasUser();
      _autoLockEnabled = settings.autoLock;
      _hasUserCached = hasUser;
    } catch (_) {}
  }

  /// Appelé depuis settings_screen quand l'utilisateur change le toggle
  void updateAutoLockState(bool enabled) {
    _autoLockEnabled = enabled;
  }

  /// Appelé depuis LoginPage après un login réussi.
  /// Active aussi un cooldown pour ignorer les lifecycle events
  /// provoqués par le dialogue biométrique du login.
  void markLoginCompleted() {
    _loginCompleted = true;
    _wasInBackground = false;
    _unlockCooldown = true;
    Future.delayed(const Duration(milliseconds: 2000), () {
      _unlockCooldown = false;
    });
  }

  // ── Lifecycle observer pour verrouillage auto ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Ignorer les événements lifecycle pendant le cooldown post-déverrouillage
    // (le dialog biométrique système déclenche inactive→resumed)
    if (_unlockCooldown) return;

    // Ignorer les événements lifecycle si le LockScreen est déjà affiché
    // (le dialog biométrique déclenche aussi inactive→resumed)
    if (_isLocked) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _tryShowLockScreen();
    }
  }

  Future<void> _tryShowLockScreen() async {
    if (_isLocked || _unlockCooldown) return;

    // Ne pas verrouiller tant que le login initial n'est pas terminé
    if (!_loginCompleted) return;

    // Vérification rapide avec le cache (pas de DB async)
    if (!_autoLockEnabled || !_hasUserCached) {
      // Rafraîchir le cache en arrière-plan pour la prochaine fois
      _cacheAutoLockState();
      return;
    }

    _isLocked = true;

    try {
      // Attendre que le frame soit prêt pour éviter les push pendant une transition
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) {
        _isLocked = false;
        return;
      }

      // Double-vérification avec la DB (le cache peut être obsolète)
      final settings = await _dbHelper.getSettings();
      if (!settings.autoLock) {
        _autoLockEnabled = false;
        _isLocked = false;
        return;
      }

      final hasUser = await _dbHelper.hasUser();
      if (!hasUser) {
        _hasUserCached = false;
        _isLocked = false;
        return;
      }

      final navigator = _navigatorKey.currentState;
      if (navigator != null && mounted) {
        await navigator.push(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (_, __, ___) => const LockScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );

        // Le LockScreen vient de se fermer (déverrouillé avec succès)
        // Activer le cooldown pour ignorer les lifecycle events
        // provoqués par le dialog biométrique système
        _wasInBackground = false;
        _unlockCooldown = true;
      }
    } catch (_) {
      // Silently handle errors to prevent _isLocked from staying true
    } finally {
      _isLocked = false;
      // Désactiver le cooldown après un délai suffisant
      if (_unlockCooldown) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _unlockCooldown = false;
        });
      }
    }
  }

  Future<void> _determineInitialScreen() async {
    final bool userExists = await _dbHelper.hasUser();
    if (mounted) {
      setState(() {
        if (userExists) {
          _initialScreen = const LoginPage();
          _loginCompleted = false; // attendre la fin du login
        } else {
          _initialScreen = const HomeScreen();
          _loginCompleted = true; // pas de login nécessaire
        }
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

  static const _primaryColor = Color(0xFFE91E63);
  static const _secondaryColor = Color(0xFFF48FB1);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'CycleTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          primary: _primaryColor,
          secondary: _secondaryColor,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: const Color(0xFFF8F0F2),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          primary: _primaryColor,
          secondary: _secondaryColor,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      themeMode: _themeMode,
      home: _initialScreen,
    );
  }
}

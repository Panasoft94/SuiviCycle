import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../cycles/couple_mode_screen.dart';
import '../aide/aide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    SettingsScreen(),
    CoupleModeScreen(),
  ];

  static const List<String> _widgetTitles = <String>[
    'Suivi des cycles',
    'Paramètres',
    'Mode Couple',
  ];

  static const List<IconData> _widgetIcons = <IconData>[
    Icons.water_drop_rounded,
    Icons.settings_suggest_rounded,
    Icons.favorite_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _widgetOptions.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PageRouteBuilder _slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey(_tabController.index),
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_widgetIcons[_tabController.index], color: colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(_widgetTitles[_tabController.index], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colorScheme.primary.withAlpha(20), shape: BoxShape.circle),
                child: Icon(Icons.help_rounded, color: colorScheme.primary, size: 20),
              ),
              onPressed: () => Navigator.push(context, _slideTransition(const AideScreen())),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 25,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: TabBar(
            controller: _tabController,
            tabs: const <Tab>[
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Suivi'),
              Tab(icon: Icon(Icons.settings_rounded), text: 'Réglages'),
              Tab(icon: Icon(Icons.people_rounded), text: 'Couple'),
            ],
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant.withAlpha(150),
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
      ),
    );
  }
}

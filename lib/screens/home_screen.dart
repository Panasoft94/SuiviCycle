import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'couple_mode_screen.dart';
import 'aide_screen.dart';

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
    Icons.water_drop_outlined,
    Icons.settings_outlined,
    Icons.people_outline,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_widgetIcons[_tabController.index]),
            const SizedBox(width: 8),
            Text(_widgetTitles[_tabController.index]),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        toolbarHeight: 70, // Increased height
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30), // Rounded bottom corners
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aide',
            onPressed: () {
              Navigator.push(context, _slideTransition(const AideScreen()));
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 20,
              offset: Offset.zero, // Centered shadow
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: TabBar(
            controller: _tabController,
            tabs: const <Tab>[
              Tab(
                icon: Icon(Icons.dashboard),
                text: 'Dashboard',
              ),
              Tab(
                icon: Icon(Icons.settings),
                text: 'Paramètres',
              ),
              Tab(
                icon: Icon(Icons.people),
                text: 'Mode Couple',
              ),
            ],
            labelColor: Colors.brown,
            unselectedLabelColor: Colors.grey,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.brown.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }
}

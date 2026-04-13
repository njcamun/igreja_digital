import 'package:flutter/material.dart';
import 'package:igreja_digital/presentation/screens/prayer_requests_screen.dart';
import 'package:igreja_digital/presentation/screens/announcements_screen.dart';
import 'package:igreja_digital/presentation/screens/sermons_screen.dart';
import 'package:igreja_digital/presentation/screens/events_screen.dart';
import 'package:igreja_digital/presentation/screens/congregations_screen.dart';
import 'package:igreja_digital/presentation/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    PrayerRequestsScreen(),
    AnnouncementsScreen(),
    SermonsScreen(),
    EventsScreen(),
    CongregationsScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    'Pedidos de Oração',
    'Anúncios',
    'Sermões',
    'Eventos',
    'Congregações',
    'Perfil',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Orações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Anúncios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Sermões',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Eventos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Congregações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'home/home_screen.dart';
import 'events/events_list_screen.dart';
import 'events/event_detail_screen.dart';
import 'announcements/announcements_list_screen.dart';
import 'announcements/announcement_detail_screen.dart';
import 'congregations/congregations_list_screen.dart';
import 'sermons/sermons_list_screen.dart';
import 'sermons/sermon_detail_screen.dart';
import 'prayers/prayer_list_screen.dart';
import 'prayers/prayer_detail_screen.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';
import '../providers/announcement_provider.dart';
import '../providers/event_provider.dart';
import '../providers/sermon_provider.dart';
import '../providers/prayer_provider.dart';
import '../services/notification_service.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;
  StreamSubscription<NotificationPayload>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationService = ref.read(notificationServiceProvider);
      _notificationSubscription = notificationService.notificationStream.listen(_handleNotification);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _handleNotification(NotificationPayload payload) async {
    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    final isVisitor = user?.role == UserRole.visitante;

    int tabIndexFor(NotificationType type) {
      if (isVisitor) {
        return switch (type) {
          NotificationType.event => 1,
          NotificationType.newSermon => 2,
          NotificationType.prayerRequest => 3,
          _ => 0,
        };
      }

      return switch (type) {
        NotificationType.event => 1,
        NotificationType.urgentAnnouncement => 2,
        NotificationType.newSermon => 3,
        NotificationType.prayerRequest => 4,
        NotificationType.generic => 0,
      };
    }

    switch (payload.type) {
      case NotificationType.urgentAnnouncement:
        if (!isVisitor) {
          setState(() => _selectedIndex = tabIndexFor(payload.type)); // Avisos
          final announcement = await ref.read(announcementRepositoryProvider).getAnnouncementById(payload.entityId);
          if (announcement != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: announcement)),
            );
          }
        }
        break;
      case NotificationType.newSermon:
        setState(() => _selectedIndex = tabIndexFor(payload.type)); // Sermões
        final sermon = await ref.read(sermonRepositoryProvider).getSermonById(payload.entityId);
        if (sermon != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SermonDetailScreen(sermon: sermon)),
          );
        }
        break;
      case NotificationType.prayerRequest:
        setState(() => _selectedIndex = tabIndexFor(payload.type)); // Oração
        final prayer = await ref.read(prayerRepositoryProvider).getPrayerRequestById(payload.entityId);
        if (prayer != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PrayerDetailScreen(prayer: prayer)),
          );
        }
        break;
      case NotificationType.event:
        setState(() => _selectedIndex = tabIndexFor(payload.type)); // Agenda
        final event = await ref.read(eventRepositoryProvider).getEventById(payload.entityId);
        if (event != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          );
        }
        break;
      case NotificationType.generic:
        // Generic notifications do not navigate to a specific entity.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isVisitor = user?.role == UserRole.visitante;

    final screens = <Widget>[
      const HomeScreen(),
      const EventsListScreen(),
      if (!isVisitor) const AnnouncementsListScreen(),
      const SermonsListScreen(),
      const PrayerListScreen(),
      const CongregationsListScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Início',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Agenda',
      ),
      if (!isVisitor)
        const NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign),
          label: 'Avisos',
        ),
      const NavigationDestination(
        icon: Icon(Icons.mic_none_outlined),
        selectedIcon: Icon(Icons.mic),
        label: 'Sermões',
      ),
      const NavigationDestination(
        icon: Icon(Icons.favorite_border),
        selectedIcon: Icon(Icons.favorite),
        label: 'Oração',
      ),
      const NavigationDestination(
        icon: Icon(Icons.church_outlined),
        selectedIcon: Icon(Icons.church),
        label: 'Igrejas',
      ),
    ];

    final safeIndex = _selectedIndex >= screens.length ? 0 : _selectedIndex;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}

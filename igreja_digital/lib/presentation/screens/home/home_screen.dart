import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/announcement_entity.dart';
import '../../../domain/entities/event_entity.dart';
import '../../../domain/entities/prayer_request_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/congregation_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/sermon_provider.dart';
import '../../providers/prayer_provider.dart';
import '../announcements/announcement_detail_screen.dart';
import '../announcements/announcements_list_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/events_list_screen.dart';
import '../prayers/prayer_list_screen.dart';
import '../prayers/prayer_detail_screen.dart';
import '../sermons/sermon_detail_screen.dart';
import '../sermons/sermons_list_screen.dart';
import '../admin/users_management_screen.dart';
import 'church_summary_screen.dart';
import 'congregation_selection_screen.dart';
import 'visitor_profile_screen.dart';

enum _AnnouncementPreviewFilter { urgent, all }

enum _PrayerPreviewFilter { recent, open, answered }

enum _EventPreviewFilter { today, next7Days, all }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _announcementFilterKey = 'home_announcement_filter';
  static const _prayerFilterKey = 'home_prayer_filter';
  static const _eventFilterKey = 'home_event_filter';

  _AnnouncementPreviewFilter _announcementFilter =
      _AnnouncementPreviewFilter.urgent;
  _PrayerPreviewFilter _prayerFilter = _PrayerPreviewFilter.recent;
  _EventPreviewFilter _eventFilter = _EventPreviewFilter.next7Days;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();

    final savedAnnouncementFilter = prefs.getInt(_announcementFilterKey);
    final savedPrayerFilter = prefs.getInt(_prayerFilterKey);
    final savedEventFilter = prefs.getInt(_eventFilterKey);

    if (!mounted) return;

    setState(() {
      if (savedAnnouncementFilter != null &&
          savedAnnouncementFilter >= 0 &&
          savedAnnouncementFilter < _AnnouncementPreviewFilter.values.length) {
        _announcementFilter =
            _AnnouncementPreviewFilter.values[savedAnnouncementFilter];
      }

      if (savedPrayerFilter != null &&
          savedPrayerFilter >= 0 &&
          savedPrayerFilter < _PrayerPreviewFilter.values.length) {
        _prayerFilter = _PrayerPreviewFilter.values[savedPrayerFilter];
      }

      if (savedEventFilter != null &&
          savedEventFilter >= 0 &&
          savedEventFilter < _EventPreviewFilter.values.length) {
        _eventFilter = _EventPreviewFilter.values[savedEventFilter];
      }
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_announcementFilterKey, _announcementFilter.index);
    await prefs.setInt(_prayerFilterKey, _prayerFilter.index);
    await prefs.setInt(_eventFilterKey, _eventFilter.index);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final sermonsAsync = ref.watch(sermonsStreamProvider);
    final prayersAsync = ref.watch(homePrayerRequestsStreamProvider);
    final congregationsAsync = ref.watch(allCongregationsStreamProvider);

    final congregationLabel = congregationsAsync.maybeWhen(
      data: (congregations) {
        final id = user?.congregationId;
        if (id == null || id.isEmpty || id == visitorCongregationId) {
          return 'Sem congregação';
        }
        final match = congregations.where((c) => c.id == id);
        if (match.isEmpty) {
          return 'Congregação indisponível';
        }
        return match.first.name;
      },
      orElse: () => 'Sem congregação',
    );

    final eventCounts = eventsAsync.maybeWhen(
      data: (events) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final nextWeekLimit = now.add(const Duration(days: 7));

        final todayCount = events
            .where(
              (event) =>
                  !event.startDateTime.isBefore(todayStart) &&
                  event.startDateTime.isBefore(tomorrowStart),
            )
            .length;
        final next7DaysCount = events
            .where(
              (event) =>
                  event.startDateTime.isAfter(now) &&
                  event.startDateTime.isBefore(nextWeekLimit),
            )
            .length;

        return (
          today: todayCount,
          next7Days: next7DaysCount,
          all: events.length,
        );
      },
      orElse: () => (today: 0, next7Days: 0, all: 0),
    );

    final previewEvents = eventsAsync.maybeWhen(
      data: (events) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final nextWeekLimit = now.add(const Duration(days: 7));

        final filtered = switch (_eventFilter) {
          _EventPreviewFilter.today =>
            events
                .where(
                  (event) =>
                      !event.startDateTime.isBefore(todayStart) &&
                      event.startDateTime.isBefore(tomorrowStart),
                )
                .toList(),
          _EventPreviewFilter.next7Days =>
            events
                .where(
                  (event) =>
                      event.startDateTime.isAfter(now) &&
                      event.startDateTime.isBefore(nextWeekLimit),
                )
                .toList(),
          _EventPreviewFilter.all => [...events],
        };

        filtered.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        return filtered.take(3).toList();
      },
      orElse: () => <EventEntity>[],
    );

    final previewAnnouncements = announcementsAsync.maybeWhen(
      data: (announcements) {
        final sorted = [...announcements]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final filtered =
            _announcementFilter == _AnnouncementPreviewFilter.urgent
            ? sorted
                  .where((a) => a.priority == AnnouncementPriority.urgente)
                  .toList()
            : sorted;
        return filtered.take(3).toList();
      },
      orElse: () => <AnnouncementEntity>[],
    );

    final announcementCounts = announcementsAsync.maybeWhen(
      data: (announcements) {
        final urgentCount = announcements
            .where(
              (announcement) =>
                  announcement.priority == AnnouncementPriority.urgente,
            )
            .length;
        return (urgent: urgentCount, all: announcements.length);
      },
      orElse: () => (urgent: 0, all: 0),
    );

    final recentSermons = sermonsAsync.maybeWhen(
      data: (sermons) {
        final sorted = [...sermons]
          ..sort((a, b) => b.sermonDate.compareTo(a.sermonDate));
        return sorted.take(3).toList();
      },
      orElse: () => [],
    );

    final previewPrayers = prayersAsync.maybeWhen(
      data: (prayers) {
        final sorted = [...prayers]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final filtered = switch (_prayerFilter) {
          _PrayerPreviewFilter.recent => sorted,
          _PrayerPreviewFilter.open =>
            sorted.where((p) => p.status == PrayerStatus.open).toList(),
          _PrayerPreviewFilter.answered =>
            sorted.where((p) => p.status == PrayerStatus.answered).toList(),
        };
        return filtered.take(3).toList();
      },
      orElse: () => [],
    );

    final prayerCounts = prayersAsync.maybeWhen(
      data: (prayers) {
        final openCount = prayers
            .where((prayer) => prayer.status == PrayerStatus.open)
            .length;
        final answeredCount = prayers
            .where((prayer) => prayer.status == PrayerStatus.answered)
            .length;
        return (
          recent: prayers.length,
          open: openCount,
          answered: answeredCount,
        );
      },
      orElse: () => (recent: 0, open: 0, answered: 0),
    );

    final summaryCards = <Widget>[
      if (user?.role != UserRole.visitante)
        _SummaryCard(
          title: 'Avisos',
          icon: Icons.campaign,
          color: Colors.deepOrange,
          countAsync: announcementsAsync,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementsListScreen(),
            ),
          ),
        ),
      _SummaryCard(
        title: 'Agenda',
        icon: Icons.calendar_month,
        color: Colors.blue,
        countAsync: eventsAsync,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventsListScreen()),
        ),
      ),
      _SummaryCard(
        title: 'Sermoes',
        icon: Icons.mic,
        color: Colors.teal,
        countAsync: sermonsAsync,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SermonsListScreen(),
          ),
        ),
      ),
      _SummaryCard(
        title: 'Orações',
        icon: Icons.favorite,
        color: Colors.red,
        countAsync: prayersAsync,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrayerListScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Igreja Digital'),
        actions: [
          if (user?.role != UserRole.visitante)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Resumo da igreja',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChurchSummaryScreen(),
                ),
              ),
            ),
          if (user?.role == UserRole.admin || user?.role == UserRole.lider)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Gerir utilizadores',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UsersManagementScreen(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(announcementsStreamProvider);
          ref.invalidate(eventsStreamProvider);
          ref.invalidate(sermonsStreamProvider);
          ref.invalidate(prayerRequestsStreamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bem-vindo, ${user?.fullName ?? "Utilizador"}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Perfil: ${user?.role.name.toUpperCase() ?? "VISITANTE"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Congregação: $congregationLabel',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (user?.role == UserRole.membro || user?.role == UserRole.lider)
              Text(
                'Data de membresia: ${user?.membershipDate != null ? DateFormat('dd/MM/yyyy').format(user!.membershipDate!) : 'Não definida'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VisitorProfileScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_outline),
                label: const Text('Meu perfil'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: user == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CongregationSelectionScreen(),
                        ),
                      ),
                icon: const Icon(Icons.location_city_outlined),
                label: const Text('Alterar congregação'),
              ),
            ),
            const SizedBox(height: 20),
            _SummaryCardsGrid(cards: summaryCards),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Proximos eventos',
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventsListScreen()),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Hoje (${eventCounts.today})'),
                  selected: _eventFilter == _EventPreviewFilter.today,
                  onSelected: (_) {
                    setState(() {
                      _eventFilter = _EventPreviewFilter.today;
                    });
                    _saveFilters();
                  },
                ),
                ChoiceChip(
                  label: Text('7 dias (${eventCounts.next7Days})'),
                  selected: _eventFilter == _EventPreviewFilter.next7Days,
                  onSelected: (_) {
                    setState(() {
                      _eventFilter = _EventPreviewFilter.next7Days;
                    });
                    _saveFilters();
                  },
                ),
                ChoiceChip(
                  label: Text('Todos (${eventCounts.all})'),
                  selected: _eventFilter == _EventPreviewFilter.all,
                  onSelected: (_) {
                    setState(() {
                      _eventFilter = _EventPreviewFilter.all;
                    });
                    _saveFilters();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (eventsAsync.isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (eventsAsync.hasError)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro ao carregar eventos: ${eventsAsync.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (previewEvents.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _eventFilter == _EventPreviewFilter.today
                        ? 'Nao ha eventos para hoje.'
                        : _eventFilter == _EventPreviewFilter.next7Days
                        ? 'Nao ha eventos nos proximos 7 dias.'
                        : 'Nenhum evento encontrado.',
                  ),
                ),
              )
            else
              ...previewEvents.map(
                (event) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(event.title),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(event.startDateTime)} • ${event.location}',
                    ),
                    onTap: () {
                      try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(event: event),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao abrir evento: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            if (user?.role != UserRole.visitante) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Avisos urgentes',
                onViewAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AnnouncementsListScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Urgentes (${announcementCounts.urgent})'),
                    selected:
                        _announcementFilter == _AnnouncementPreviewFilter.urgent,
                    onSelected: (_) {
                      setState(() {
                        _announcementFilter = _AnnouncementPreviewFilter.urgent;
                      });
                      _saveFilters();
                    },
                  ),
                  ChoiceChip(
                    label: Text('Todos recentes (${announcementCounts.all})'),
                    selected:
                        _announcementFilter == _AnnouncementPreviewFilter.all,
                    onSelected: (_) {
                      setState(() {
                        _announcementFilter = _AnnouncementPreviewFilter.all;
                      });
                      _saveFilters();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (announcementsAsync.isLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (announcementsAsync.hasError)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Erro ao carregar avisos: ${announcementsAsync.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else if (previewAnnouncements.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _announcementFilter == _AnnouncementPreviewFilter.urgent
                          ? 'Nenhum aviso urgente no momento.'
                          : 'Nenhum aviso encontrado.',
                    ),
                  ),
                )
              else
                ...previewAnnouncements.map(
                  (announcement) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      title: Text(announcement.title),
                      subtitle: Text(
                        announcement.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        try {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnnouncementDetailScreen(
                                announcement: announcement,
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao abrir aviso: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Sermoes recentes',
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SermonsListScreen()),
              ),
            ),
            const SizedBox(height: 8),
            if (sermonsAsync.isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (sermonsAsync.hasError)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro ao carregar sermoes: ${sermonsAsync.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (recentSermons.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum sermao publicado no momento.'),
                ),
              )
            else
              ...recentSermons.map(
                (sermon) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.mic),
                    title: Text(sermon.title),
                    subtitle: Text(
                      '${sermon.preacherName} • ${DateFormat('dd/MM/yyyy').format(sermon.sermonDate)}',
                    ),
                    onTap: () {
                      try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SermonDetailScreen(sermon: sermon),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao abrir sermao: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Pedidos de oracao recentes',
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrayerListScreen()),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Recentes (${prayerCounts.recent})'),
                  selected: _prayerFilter == _PrayerPreviewFilter.recent,
                  onSelected: (_) {
                    setState(() {
                      _prayerFilter = _PrayerPreviewFilter.recent;
                    });
                    _saveFilters();
                  },
                ),
                ChoiceChip(
                  label: Text('Em aberto (${prayerCounts.open})'),
                  selected: _prayerFilter == _PrayerPreviewFilter.open,
                  onSelected: (_) {
                    setState(() {
                      _prayerFilter = _PrayerPreviewFilter.open;
                    });
                    _saveFilters();
                  },
                ),
                ChoiceChip(
                  label: Text('Respondidos (${prayerCounts.answered})'),
                  selected: _prayerFilter == _PrayerPreviewFilter.answered,
                  onSelected: (_) {
                    setState(() {
                      _prayerFilter = _PrayerPreviewFilter.answered;
                    });
                    _saveFilters();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (prayersAsync.isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (prayersAsync.hasError)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro ao carregar pedidos: ${prayersAsync.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (previewPrayers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _prayerFilter == _PrayerPreviewFilter.recent
                        ? 'Nenhum pedido de oracao no momento.'
                        : _prayerFilter == _PrayerPreviewFilter.open
                        ? 'Nenhum pedido em aberto encontrado.'
                        : 'Nenhum pedido respondido encontrado.',
                  ),
                ),
              )
            else
              ...previewPrayers.map(
                (prayer) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: Text(prayer.title),
                    subtitle: Text(
                      '${prayer.isAnonymous ? 'Pedido Anonimo' : prayer.userName} • ${prayer.prayerCount} intercessoes',
                    ),
                    onTap: () {
                      try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrayerDetailScreen(prayer: prayer),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao abrir pedido: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: onViewAll, child: const Text('Ver todos')),
      ],
    );
  }
}

class _SummaryCardsGrid extends StatelessWidget {
  const _SummaryCardsGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < cards.length; i += 2) {
      final hasPair = i + 1 < cards.length;

      rows.add(
        Row(
          children: [
            Expanded(child: cards[i]),
            if (hasPair) ...[
              const SizedBox(width: 12),
              Expanded(child: cards[i + 1]),
            ],
          ],
        ),
      );

      if (i + 2 < cards.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.countAsync,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<dynamic>> countAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = countAsync.when(
      data: (items) => '${items.length}',
      loading: () => '...',
      error: (_, stackTrace) => '!',
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import '../data/maoyan_provider.dart';
import '../data/subscription_store.dart';
import '../domain/models.dart';
import 'notification_service.dart';

class MonitorResult {
  const MonitorResult({
    required this.checked,
    required this.notices,
    this.alert,
  });
  final int checked;
  final List<NewSessionNotice> notices;
  final NewSessionAlert? alert;

  int get newSessions => notices.fold<int>(
        0,
        (total, notice) => total + notice.sessions.length,
      );
}

class SubscriptionMonitor {
  SubscriptionMonitor({
    ScheduleProvider? provider,
    SubscriptionStore? store,
    NotificationService? notifications,
  })  : provider = provider ?? MaoyanScheduleProvider(),
        store = store ?? SubscriptionStore(),
        notifications = notifications ?? NotificationService.instance;

  final ScheduleProvider provider;
  final SubscriptionStore store;
  final NotificationService notifications;

  Future<MonitorResult> checkAll({
    Map<String, CinemaSnapshot> prefetched = const <String, CinemaSnapshot>{},
  }) async {
    final subscriptions = await store.load();
    if (subscriptions.isEmpty) {
      return const MonitorResult(checked: 0, notices: <NewSessionNotice>[]);
    }

    final byCinema = <String, List<MovieSubscription>>{};
    for (final subscription in subscriptions) {
      byCinema
          .putIfAbsent(subscription.cinema.key, () => <MovieSubscription>[])
          .add(subscription);
    }

    final notices = <NewSessionNotice>[];
    final updated = <String, MovieSubscription>{
      for (final item in subscriptions) item.key: item,
    };
    for (final group in byCinema.values) {
      final snapshot = prefetched[group.first.cinema.key] ??
          await provider.fetchCinema(group.first.cinema);
      final movies = <int, MovieSchedule>{
        for (final movie in snapshot.movies) movie.id: movie,
      };
      for (final subscription in group) {
        final movie = movies[subscription.movieId];
        final currentIds = movie?.sessions.map((item) => item.id).toSet() ?? {};
        final added = detectNewSessions(
          movie?.sessions ?? const <Session>[],
          subscription.seenSessionIds,
        );
        if (added.isNotEmpty) {
          notices.add(NewSessionNotice(
            subscription: subscription,
            sessions: added,
          ));
          try {
            await notifications.showNewSessions(subscription, added);
          } catch (_) {
            // The in-app alert and session baseline must still be updated when
            // system notifications are unavailable or permission was denied.
          }
        }
        updated[subscription.key] = subscription.copyWith(
          seenSessionIds: currentIds,
          lastCheckedAt: snapshot.fetchedAt,
        );
      }
    }
    await store.save(updated.values.toList());
    final now = DateTime.now();
    final alert = notices.isEmpty
        ? null
        : NewSessionAlert(
            id: '${now.microsecondsSinceEpoch}',
            createdAt: now,
            notices: notices,
          );
    final result = MonitorResult(
      checked: subscriptions.length,
      notices: notices,
      alert: alert,
    );
    if (alert != null) await store.saveNewSessionAlert(alert);
    return result;
  }
}

List<Session> detectNewSessions(
  List<Session> current,
  Set<String> seenSessionIds,
) {
  return current
      .where((session) => !seenSessionIds.contains(session.id))
      .toList();
}

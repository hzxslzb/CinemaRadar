import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'data/maoyan_provider.dart';
import 'data/subscription_store.dart';
import 'domain/models.dart';
import 'services/background_access_service.dart';
import 'services/background_monitor.dart';
import 'services/notification_service.dart';
import 'services/subscription_monitor.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    ScheduleProvider? provider,
    SubscriptionStore? store,
  })  : provider = provider ?? MaoyanScheduleProvider(),
        store = store ?? SubscriptionStore();

  final ScheduleProvider provider;
  final SubscriptionStore store;

  Cinema cinema = knownCinemas.first;
  CinemaSnapshot? snapshot;
  MovieSchedule? selectedMovie;
  List<MovieSubscription> subscriptions = <MovieSubscription>[];
  bool loading = false;
  bool darkMode = false;
  RefreshIntervalOption refreshInterval = refreshIntervalOptions[2];
  BackgroundAccessStatus backgroundAccessStatus =
      const BackgroundAccessStatus();
  NewSessionAlert? newSessionAlert;
  String? error;
  Timer? _foregroundTimer;
  bool _scheduledRefreshRunning = false;
  bool _observingLifecycle = false;

  Future<void> initialize() async {
    darkMode = await store.loadDarkTheme();
    final savedMinutes = await store.loadRefreshMinutes();
    refreshInterval = refreshIntervalOptions.firstWhere(
      (option) => option.minutes == savedMinutes,
      orElse: () => refreshIntervalOptions[2],
    );
    subscriptions = await store.load();
    if (subscriptions.isNotEmpty) {
      await BackgroundAccessService.instance.enablePersistentBackground();
    }
    newSessionAlert = await store.loadNewSessionAlert();
    await store.removeLegacyCinemaCache();
    notifyListeners();
    await refresh();
    await _checkSubscriptions();
    await refreshBackgroundAccessStatus();
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _configureTimerForLifecycle(lifecycleState);
    await BackgroundMonitor.syncSchedule(interval: refreshInterval);
  }

  Future<void> switchCinema(Cinema value) async {
    if (cinema.key == value.key) {
      cinema = value;
      notifyListeners();
      return;
    }
    cinema = value;
    snapshot = null;
    selectedMovie = null;
    error = null;
    notifyListeners();
    await refresh();
  }

  Future<void> openSubscription(MovieSubscription subscription) async {
    final currentMovie = snapshot?.movies
        .where((movie) => movie.id == subscription.movieId)
        .firstOrNull;
    if (cinema.key == subscription.cinema.key && currentMovie != null) {
      selectedMovie = currentMovie;
      notifyListeners();
      return;
    }
    cinema = subscription.cinema;
    snapshot = null;
    selectedMovie = null;
    error = null;
    notifyListeners();
    await refresh(preferredMovieId: subscription.movieId);
  }

  void selectMovie(MovieSchedule movie) {
    selectedMovie = movie;
    notifyListeners();
  }

  Future<void> refresh({int? preferredMovieId}) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final next = await provider.fetchCinema(cinema);
      snapshot = next;
      final preferred = preferredMovieId == null
          ? null
          : next.movies
              .where((movie) => movie.id == preferredMovieId)
              .firstOrNull;
      if (preferred != null) {
        selectedMovie = preferred;
      } else if (selectedMovie == null ||
          !next.movies.any((movie) => movie.id == selectedMovie!.id)) {
        selectedMovie = _regressionMovie(next) ?? next.movies.firstOrNull;
      } else {
        selectedMovie =
            next.movies.firstWhere((movie) => movie.id == selectedMovie!.id);
      }
    } catch (exception) {
      error = '$exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAndCheckSubscriptions() => _scheduledRefresh();

  MovieSchedule? _regressionMovie(CinemaSnapshot value) {
    if (cinema.id != 37534) return null;
    for (final movie in value.movies) {
      if (movie.name == '奥德赛') return movie;
    }
    return null;
  }

  bool isSubscribed(MovieSchedule movie) => subscriptions.any(
        (item) => item.cinema.key == cinema.key && item.movieId == movie.id,
      );

  Future<bool> toggleSubscription(MovieSchedule movie) async {
    final index = subscriptions.indexWhere(
      (item) => item.cinema.key == cinema.key && item.movieId == movie.id,
    );
    final added = index < 0;
    if (index >= 0) {
      subscriptions.removeAt(index);
    } else {
      await NotificationService.instance.requestPermissions();
      subscriptions.add(MovieSubscription(
        cinema: cinema,
        movieId: movie.id,
        movieName: movie.name,
        seenSessionIds: movie.sessions.map((item) => item.id).toSet(),
        createdAt: DateTime.now(),
        lastCheckedAt: DateTime.now(),
      ));
    }
    await store.save(subscriptions);
    if (added) {
      await BackgroundAccessService.instance.enablePersistentBackground();
    }
    await BackgroundMonitor.syncSchedule(interval: refreshInterval);
    await refreshBackgroundAccessStatus(notify: false);
    _configureTimerForLifecycle(WidgetsBinding.instance.lifecycleState);
    notifyListeners();
    return added;
  }

  Future<void> deleteSubscription(MovieSubscription subscription) async {
    subscriptions.removeWhere((item) => item.key == subscription.key);
    await store.save(subscriptions);
    await BackgroundMonitor.syncSchedule(interval: refreshInterval);
    notifyListeners();
  }

  Future<void> dismissNewSessionAlert() async {
    final current = newSessionAlert;
    if (current == null) return;
    newSessionAlert = null;
    notifyListeners();
    await store.clearNewSessionAlert(expectedId: current.id);
  }

  Future<void> reloadNewSessionAlert() async {
    final pending = await store.loadNewSessionAlert();
    if (pending?.id == newSessionAlert?.id) return;
    newSessionAlert = pending;
    notifyListeners();
  }

  Future<void> openNewSessionNotice(NewSessionNotice notice) =>
      openSubscription(notice.subscription);

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    notifyListeners();
    await store.saveDarkTheme(darkMode);
  }

  Future<void> setRefreshInterval(RefreshIntervalOption value) async {
    if (refreshInterval.minutes == value.minutes) return;
    refreshInterval = value;
    notifyListeners();
    await store.saveRefreshMinutes(value.minutes);
    await BackgroundMonitor.syncSchedule(interval: value);
    _configureTimerForLifecycle(WidgetsBinding.instance.lifecycleState);
  }

  Future<void> refreshBackgroundAccessStatus({bool notify = true}) async {
    backgroundAccessStatus = await BackgroundAccessService.instance.status();
    if (notify) notifyListeners();
  }

  Future<void> requestNotificationAccess() async {
    await NotificationService.instance.requestPermissions();
    await refreshBackgroundAccessStatus();
  }

  Future<bool> openBackgroundSettings() =>
      BackgroundAccessService.instance.openBackgroundSettings();

  Future<bool> openAppSettings() =>
      BackgroundAccessService.instance.openAppSettings();

  void _startForegroundTimer() {
    _startTimer(foregroundRefreshInterval);
  }

  void _startTimer(Duration duration) {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      duration,
      (_) => _scheduledRefresh(),
    );
  }

  void _configureTimerForLifecycle(AppLifecycleState? state) {
    if (state == null || state == AppLifecycleState.resumed) {
      _startForegroundTimer();
      return;
    }
    if (Platform.isMacOS &&
        subscriptions.isNotEmpty &&
        state != AppLifecycleState.detached) {
      _startTimer(refreshInterval.duration);
      return;
    }
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _configureTimerForLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      reloadNewSessionAlert();
      refreshBackgroundAccessStatus();
    }
  }

  Future<void> _scheduledRefresh() async {
    if (_scheduledRefreshRunning) return;
    _scheduledRefreshRunning = true;
    try {
      await refresh();
      await _checkSubscriptions();
    } finally {
      _scheduledRefreshRunning = false;
    }
  }

  Future<void> _checkSubscriptions() async {
    if (subscriptions.isEmpty) return;
    final currentSnapshot = error == null ? snapshot : null;
    final result =
        await SubscriptionMonitor(provider: provider, store: store).checkAll(
      prefetched: currentSnapshot == null
          ? const <String, CinemaSnapshot>{}
          : <String, CinemaSnapshot>{cinema.key: currentSnapshot},
    );
    subscriptions = await store.load();
    if (result.alert != null) {
      newSessionAlert = await store.loadNewSessionAlert();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _foregroundTimer?.cancel();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

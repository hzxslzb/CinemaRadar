import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class SubscriptionStore {
  static const _subscriptionsKey = 'movie_subscriptions_v1';
  static const _customCinemasKey = 'custom_cinemas_v1';
  static const _darkThemeKey = 'dark_theme_v1';
  static const _refreshMinutesKey = 'refresh_minutes_v1';
  static const _newSessionAlertKey = 'new_session_alert_v1';

  Future<List<MovieSubscription>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_subscriptionsKey);
    if (source == null || source.isEmpty) return <MovieSubscription>[];
    try {
      return MovieSubscription.decodeList(source);
    } catch (_) {
      return <MovieSubscription>[];
    }
  }

  Future<void> save(List<MovieSubscription> subscriptions) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _subscriptionsKey,
      MovieSubscription.encodeList(subscriptions),
    );
  }

  Future<bool> loadDarkTheme() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_darkThemeKey) ?? false;
  }

  Future<void> saveDarkTheme(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkThemeKey, value);
  }

  Future<int> loadRefreshMinutes() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_refreshMinutesKey) ?? 15;
  }

  Future<void> saveRefreshMinutes(int value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_refreshMinutesKey, value);
  }

  Future<void> removeLegacyCinemaCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_customCinemasKey);
  }

  Future<NewSessionAlert?> loadNewSessionAlert() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_newSessionAlertKey);
    if (source == null || source.isEmpty) return null;
    try {
      return NewSessionAlert.decode(source);
    } catch (_) {
      await preferences.remove(_newSessionAlertKey);
      return null;
    }
  }

  Future<void> saveNewSessionAlert(NewSessionAlert alert) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_newSessionAlertKey, alert.encode());
  }

  Future<void> clearNewSessionAlert({String? expectedId}) async {
    final preferences = await SharedPreferences.getInstance();
    if (expectedId != null) {
      final current = preferences.getString(_newSessionAlertKey);
      if (current != null) {
        try {
          if (NewSessionAlert.decode(current).id != expectedId) return;
        } catch (_) {
          // A malformed pending alert can always be discarded.
        }
      }
    }
    await preferences.remove(_newSessionAlertKey);
  }
}

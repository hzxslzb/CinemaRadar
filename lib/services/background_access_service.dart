import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';

class BackgroundAccessStatus {
  const BackgroundAccessStatus({
    this.notificationsEnabled,
    this.batteryOptimizationExempt,
    this.backgroundRestricted,
    this.loginItemEnabled,
    this.settingsAvailable = false,
    this.scheduledBackgroundSupported = false,
  });

  final bool? notificationsEnabled;
  final bool? batteryOptimizationExempt;
  final bool? backgroundRestricted;
  final bool? loginItemEnabled;
  final bool settingsAvailable;
  final bool scheduledBackgroundSupported;

  bool get needsAttention {
    if (notificationsEnabled == false) return true;
    if (!kIsWeb && Platform.isAndroid) {
      return batteryOptimizationExempt == false || backgroundRestricted == true;
    }
    if (!kIsWeb && Platform.isMacOS) {
      return loginItemEnabled != true;
    }
    // HarmonyOS does not provide a suitable always-on mode for this kind of
    // periodic polling. Keep the system-settings guidance visible instead of
    // presenting the foreground fallback as guaranteed background execution.
    return !kIsWeb && Platform.operatingSystem == 'ohos';
  }
}

class BackgroundAccessService {
  BackgroundAccessService._();

  static final instance = BackgroundAccessService._();
  static const _channel = MethodChannel(
    'com.cinemaradar.app/background_access',
  );
  static const _nativeCallTimeout = Duration(seconds: 1);

  bool get _runningInFlutterTest =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  Future<BackgroundAccessStatus> status() async {
    final notificationsEnabled =
        await NotificationService.instance.areNotificationsEnabled();
    if (kIsWeb ||
        _runningInFlutterTest ||
        (!Platform.isAndroid &&
            !Platform.isMacOS &&
            Platform.operatingSystem != 'ohos')) {
      return BackgroundAccessStatus(
        notificationsEnabled: notificationsEnabled,
      );
    }

    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>('getStatus')
          .timeout(_nativeCallTimeout);
      return BackgroundAccessStatus(
        notificationsEnabled: notificationsEnabled,
        batteryOptimizationExempt: raw?['batteryOptimizationExempt'] as bool?,
        backgroundRestricted: raw?['backgroundRestricted'] as bool?,
        loginItemEnabled: raw?['loginItemEnabled'] as bool?,
        settingsAvailable: raw?['settingsAvailable'] as bool? ?? false,
        scheduledBackgroundSupported:
            raw?['scheduledBackgroundSupported'] as bool? ?? false,
      );
    } on PlatformException {
      return BackgroundAccessStatus(
        notificationsEnabled: notificationsEnabled,
      );
    } on MissingPluginException {
      return BackgroundAccessStatus(
        notificationsEnabled: notificationsEnabled,
      );
    } on TimeoutException {
      return BackgroundAccessStatus(
        notificationsEnabled: notificationsEnabled,
      );
    }
  }

  Future<bool> openBackgroundSettings() async {
    if (kIsWeb ||
        _runningInFlutterTest ||
        (!Platform.isAndroid &&
            !Platform.isMacOS &&
            Platform.operatingSystem != 'ohos')) {
      return false;
    }
    try {
      return await _channel
              .invokeMethod<bool>('openBackgroundSettings')
              .timeout(_nativeCallTimeout) ??
          false;
    } on PlatformException {
      return openAppSettings();
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    if (kIsWeb ||
        _runningInFlutterTest ||
        (!Platform.isAndroid &&
            !Platform.isMacOS &&
            Platform.operatingSystem != 'ohos')) {
      return false;
    }
    try {
      return await _channel
              .invokeMethod<bool>('openAppSettings')
              .timeout(_nativeCallTimeout) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> enablePersistentBackground() async {
    if (kIsWeb || _runningInFlutterTest || !Platform.isMacOS) return false;
    try {
      return await _channel
              .invokeMethod<bool>('enablePersistentBackground')
              .timeout(_nativeCallTimeout) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}

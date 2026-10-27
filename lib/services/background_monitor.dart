import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/subscription_store.dart';
import '../domain/models.dart';
import 'notification_service.dart';
import 'subscription_monitor.dart';

const backgroundTaskName = 'cinema_schedule_subscription_check';
const backgroundTaskUniqueName = 'cinema_schedule_monitor_v1';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await NotificationService.instance.initialize();
      await SubscriptionMonitor().checkAll();
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundMonitor {
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> syncSchedule({RefreshIntervalOption? interval}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final store = SubscriptionStore();
    final subscriptions = await store.load();
    if (subscriptions.isEmpty) {
      await Workmanager().cancelByUniqueName(backgroundTaskUniqueName);
      return;
    }
    final selectedInterval = interval ??
        refreshIntervalOptions.firstWhere(
          (option) => option.minutes == 15,
        );
    await Workmanager().registerPeriodicTask(
      backgroundTaskUniqueName,
      backgroundTaskName,
      frequency: selectedInterval.androidBackgroundDuration,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}

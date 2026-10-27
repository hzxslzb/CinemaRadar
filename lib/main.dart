import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/background_monitor.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await BackgroundMonitor.initialize();
  await BackgroundMonitor.syncSchedule();
  runApp(const CinemaRadarApp());
}

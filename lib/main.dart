import 'dart:async';
import 'package:carcare_service/app/app.dart';
import 'package:carcare_service/core/keys/keys.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/device_service.dart';
import 'package:carcare_service/core/services/notification_service.dart';
import 'package:carcare_service/firebase_options.dart';
import 'package:carcare_service/core/widgets/screens/error_screens.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget get carcare => Carcare();

void main() {
  runGuardian();
  runZonedGuarded(() async {
    flutterRequired();
    await appIniter();
    onTokenRefresh();
    runApp(carcare);
  }, onException);
}

void runGuardian() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) => AppErrorScreen(details: details);
}

Future appIniter() async {
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await initializeDateFormatting('mn');
  await Authenticator.init();
  await DeviceService.instance.init();
  await NotificationService.instance.init();
}

void onTokenRefresh() {
  NotificationService.instance.onTokenRefresh.listen(DeviceService.instance.updateToken);
}

void flutterRequired() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
}

onException(Object e, StackTrace s) {
  debugPrint("ERROR=======> \n${e.toString()}");
  debugPrint("STACKTRACE=======> \n${s.toString()}");
}

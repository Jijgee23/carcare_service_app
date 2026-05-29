import 'dart:async';

import 'package:carcare_service/app/configs/configs.dart';
import 'package:carcare_service/app/configs/global_keys.dart';
import 'package:carcare_service/app/theme/theme_provider.dart';
import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:carcare_service/authentication/root/root.dart';
import 'package:carcare_service/screens/main/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

Future<void> main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env');
      await Hive.initFlutter();
      await Authenticator.init();
      runApp(MyApp());
    },
    (error, stack) async {
      debugPrint("ERROR=======> ${error.toString()}");
      debugPrint("ERROR=======> ${stack.toString()}");
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: Configs.providers,
      child: Consumer<ThemeProvider>(
        builder: (context, value, child) => GetMaterialApp(
          title: 'Flutter Demo',
          debugShowCheckedModeBanner: false,
          themeMode: value.mode,
          navigatorKey: GlobalKeys.navigator,
          home: RootPage(),
        ),
      ),
    );
  }
}

import 'package:carcare_service/core/keys/keys.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/auth/root.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class Configs {
  // Navigator дээр байх ёстой providers — бүх route-аас хандагдана.
  // OrderController → IndexScreen, NewInspectionController → NewInspectionScreen (self-providing)
  static List<SingleChildWidget> providers = [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AuthController()),
    ChangeNotifierProvider(create: (_) => InspectionController()),
    ChangeNotifierProvider(create: (_) => BottomNavController()),
  ];
}

class Carcare extends StatelessWidget {
  const Carcare({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: Configs.providers,
      child: Consumer<ThemeProvider>(
        builder: (context, value, child) => GetMaterialApp(
          title: 'carCare.mn',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          enableLog: false,

          themeMode: value.mode,
          navigatorKey: GlobalKeys.navigator,
          home: RootPage(),
        ),
      ),
    );
  }
}

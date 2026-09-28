import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/orders/data/order_repository.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class Configs {
  static List<SingleChildWidget> providers(AuthController authController) => [
    ChangeNotifierProvider<AuthController>.value(value: authController),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => InspectionController()),
    ChangeNotifierProvider(create: (_) => BottomNavController()),
    Provider<OrdersRepository>(create: (_) => RemoteOrdersRepository()),
  ];
}

class Carcare extends StatefulWidget {
  const Carcare({super.key});

  @override
  State<Carcare> createState() => _CarcareState();
}

class _CarcareState extends State<Carcare> {
  final AuthController _authController = AuthController();
  late final GoRouter _router = buildRouter(_authController);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authController.loadUser());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: Configs.providers(_authController),
      child: Consumer<ThemeProvider>(
        builder: (context, value, child) => GetMaterialApp.router(
          title: 'carservice.mn',
          debugShowCheckedModeBanner: false,
          enableLog: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: value.mode,
          routerDelegate: _router.routerDelegate,
          routeInformationParser: _router.routeInformationParser,
          routeInformationProvider: _router.routeInformationProvider,
          backButtonDispatcher: _router.backButtonDispatcher,
          locale: const Locale('mn'),
          supportedLocales: const [Locale('mn'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}

import 'package:carcare_service/app/theme/theme_provider.dart';
import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:carcare_service/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class Configs {
  static List<SingleChildWidget> providers = [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => InspectionProvider()),
    ChangeNotifierProvider(create: (_) => NewInspectionProvider()),
    ChangeNotifierProvider(create: (_) => BottomNavProvider()),
  ];

  // static List<LocalizationsDelegate<dynamic>> localizations = [
  //   FlutterQuillLocalizations.delegate,
  //   GlobalMaterialLocalizations.delegate,
  //   GlobalWidgetsLocalizations.delegate,
  //   GlobalCupertinoLocalizations.delegate,
  // ];

  // static List<Locale> locales = [
  //   Locale('en', 'US'),
  //   // Locale('mn', 'MN'),
  // ];
}

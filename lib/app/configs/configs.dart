import 'package:carcare_service/app/theme/theme_provider.dart';
import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class Configs {
  static List<SingleChildWidget> providers = [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
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

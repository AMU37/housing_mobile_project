import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'screens/contractor_shell.dart';
import 'state/housing_store.dart';
import 'widgets/app_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HousingMobileApp());
}

class HousingMobileApp extends StatefulWidget {
  const HousingMobileApp({super.key});
  @override
  State<HousingMobileApp> createState() => _HousingMobileAppState();
}

class _HousingMobileAppState extends State<HousingMobileApp> {
  late final HousingStore store;
  @override
  void initState() {
    super.initState();
    store = HousingStore();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal, secondary: navy),
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: navy, elevation: 0, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: teal, width: 1.5)),
      ),
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (!store.isLoggedIn) return LoginScreen(store: store);
          if (store.usesContractorPortal) return ContractorShell(store: store);
          return MainShell(store: store);
        },
      ),
    ),
  );
}

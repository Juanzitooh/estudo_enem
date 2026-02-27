import 'package:flutter/material.dart';

import 'src/data/local_database.dart';
import 'src/ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnemOfflineApp());
}

class EnemOfflineApp extends StatefulWidget {
  const EnemOfflineApp({super.key});

  @override
  State<EnemOfflineApp> createState() => _EnemOfflineAppState();
}

class _EnemOfflineAppState extends State<EnemOfflineApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontScale = profileFontScaleDefault;

  ThemeMode _toThemeMode(String value) {
    final normalized = normalizeProfileThemeMode(value);
    if (normalized == profileThemeModeLight) {
      return ThemeMode.light;
    }
    if (normalized == profileThemeModeDark) {
      return ThemeMode.dark;
    }
    return ThemeMode.system;
  }

  void _handleAppearanceChanged(String themeMode, double fontScale) {
    final nextMode = _toThemeMode(themeMode);
    final nextScale = normalizeProfileFontScale(fontScale);
    if (nextMode == _themeMode && (nextScale - _fontScale).abs() < 0.001) {
      return;
    }
    setState(() {
      _themeMode = nextMode;
      _fontScale = nextScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A7A52),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2EA37B),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'ENEM Offline Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0E1512),
      ),
      themeMode: _themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(_fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomePage(onAppearanceChanged: _handleAppearanceChanged),
    );
  }
}

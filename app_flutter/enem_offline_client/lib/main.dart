import 'package:flutter/material.dart';

import 'src/data/local_database.dart';
import 'src/ui/app_theme.dart';
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
    return MaterialApp(
      title: 'Enem Questões',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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

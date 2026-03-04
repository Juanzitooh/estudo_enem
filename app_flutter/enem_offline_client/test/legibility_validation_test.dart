import 'package:enem_offline_client/src/data/local_database.dart';
import 'package:enem_offline_client/src/ui/app_theme.dart';
import 'package:enem_offline_client/src/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LegibilityScenario {
  const _LegibilityScenario({
    required this.name,
    required this.surfaceSize,
    required this.themeMode,
    required this.platformBrightness,
  });

  final String name;
  final Size surfaceSize;
  final ThemeMode themeMode;
  final Brightness platformBrightness;
}

class _LegibilityHarness extends StatelessWidget {
  const _LegibilityHarness({
    required this.themeMode,
    required this.fontScale,
    required this.child,
  });

  final ThemeMode themeMode;
  final double fontScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, appChild) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: appChild ?? const SizedBox.shrink(),
        );
      },
      home: child,
    );
  }
}

Future<void> _pumpScenario(
  WidgetTester tester, {
  required _LegibilityScenario scenario,
  required double fontScale,
}) async {
  final binding = tester.binding;

  await binding.setSurfaceSize(scenario.surfaceSize);
  binding.platformDispatcher.platformBrightnessTestValue =
      scenario.platformBrightness;

  await tester.pumpWidget(
    _LegibilityHarness(
      themeMode: scenario.themeMode,
      fontScale: fontScale,
      child: const HomePage(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  _assertNoRenderError(
    tester: tester,
    scenarioName: scenario.name,
    phase: 'frame_inicial',
  );

  expect(
    find.text('Aulas'),
    findsOneWidget,
    reason: 'aba Aulas ausente em ${scenario.name}',
  );
  expect(
    find.text('Questões'),
    findsOneWidget,
    reason: 'aba Questões ausente em ${scenario.name}',
  );
  expect(
    find.text('Perfil'),
    findsOneWidget,
    reason: 'aba Perfil ausente em ${scenario.name}',
  );

  await tester.tap(find.text('Questões'));
  await tester.pump(const Duration(milliseconds: 300));
  _assertNoRenderError(
    tester: tester,
    scenarioName: scenario.name,
    phase: 'tab_questoes',
  );
  await tester.tap(find.text('Perfil'));
  await tester.pump(const Duration(milliseconds: 300));
  _assertNoRenderError(
    tester: tester,
    scenarioName: scenario.name,
    phase: 'tab_perfil',
  );
  await tester.tap(find.text('Aulas'));
  await tester.pump(const Duration(milliseconds: 300));
  _assertNoRenderError(
    tester: tester,
    scenarioName: scenario.name,
    phase: 'tab_aulas_retorno',
  );

  binding.platformDispatcher.clearPlatformBrightnessTestValue();
  await binding.setSurfaceSize(null);
}

void _assertNoRenderError({
  required WidgetTester tester,
  required String scenarioName,
  required String phase,
}) {
  final error = tester.takeException();
  if (error != null) {
    fail('erro de renderização em $scenarioName [$phase]: $error');
  }
}

void main() {
  const maxFontScale = profileFontScaleMax;
  const desktopSize = Size(1366, 768);
  const mobileSize = Size(390, 844);

  final scenarios = <_LegibilityScenario>[
    const _LegibilityScenario(
      name: 'desktop_light_font_max',
      surfaceSize: desktopSize,
      themeMode: ThemeMode.light,
      platformBrightness: Brightness.light,
    ),
    const _LegibilityScenario(
      name: 'desktop_dark_font_max',
      surfaceSize: desktopSize,
      themeMode: ThemeMode.dark,
      platformBrightness: Brightness.dark,
    ),
    const _LegibilityScenario(
      name: 'desktop_system_font_max',
      surfaceSize: desktopSize,
      themeMode: ThemeMode.system,
      platformBrightness: Brightness.dark,
    ),
    const _LegibilityScenario(
      name: 'mobile_light_font_max',
      surfaceSize: mobileSize,
      themeMode: ThemeMode.light,
      platformBrightness: Brightness.light,
    ),
    const _LegibilityScenario(
      name: 'mobile_dark_font_max',
      surfaceSize: mobileSize,
      themeMode: ThemeMode.dark,
      platformBrightness: Brightness.dark,
    ),
    const _LegibilityScenario(
      name: 'mobile_system_font_max',
      surfaceSize: mobileSize,
      themeMode: ThemeMode.system,
      platformBrightness: Brightness.light,
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      'valida legibilidade ${scenario.name}',
      (tester) async {
        await _pumpScenario(
          tester,
          scenario: scenario,
          fontScale: maxFontScale,
        );
      },
    );
  }
}

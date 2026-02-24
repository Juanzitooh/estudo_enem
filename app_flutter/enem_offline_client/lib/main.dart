import 'package:flutter/material.dart';

import 'src/ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnemOfflineApp());
}

class EnemOfflineApp extends StatelessWidget {
  const EnemOfflineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENEM Offline Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A7A52)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

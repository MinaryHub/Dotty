import 'package:flutter/material.dart';

import 'models/show_store.dart';
import 'platform/screen_mode.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow();
  final store = await ShowStore.load();
  runApp(DottyApp(store: store));
}

class DottyApp extends StatelessWidget {
  const DottyApp({super.key, required this.store});

  final ShowStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dotty',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF3B30),
        useMaterial3: true,
      ),
      home: HomeScreen(store: store),
    );
  }
}

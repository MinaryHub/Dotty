import 'package:flutter/material.dart';

import 'l10n.dart';
import 'models/show_store.dart';
import 'platform/screen_mode.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow();
  final store = await ShowStore.load();
  final language = await LanguageController.load();
  runApp(DottyApp(store: store, language: language));
}

class DottyApp extends StatelessWidget {
  const DottyApp({super.key, required this.store, required this.language});

  final ShowStore store;
  final LanguageController language;

  @override
  Widget build(BuildContext context) {
    return LanguageScope(controller: language, child: _app());
  }

  Widget _app() {
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

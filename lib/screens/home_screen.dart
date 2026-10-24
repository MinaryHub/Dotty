import 'package:flutter/material.dart';

import '../dot_matrix/dot_matrix_display.dart';
import '../models/settings_store.dart';
import 'settings_panel.dart';
import 'sign_screen.dart';

/// Live preview plus settings; side by side on wide screens, stacked on phones.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final SettingsStore store;

  void _openSign(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => SignScreen(store: store),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => _openSign(context),
        child: ValueListenableBuilder(
          valueListenable: store,
          builder: (context, settings, _) =>
              DotMatrixDisplay(settings: settings),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dotty'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.fullscreen),
              label: const Text('전체 화면'),
              onPressed: () => _openSign(context),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(child: Center(child: _aspect(preview))),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: SettingsPanel(store: store)),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.3).clamp(120, 260),
                width: double.infinity,
                child: preview,
              ),
              const Divider(height: 1),
              Expanded(child: SettingsPanel(store: store)),
            ],
          );
        },
      ),
    );
  }

  Widget _aspect(Widget child) => AspectRatio(aspectRatio: 3, child: child);
}

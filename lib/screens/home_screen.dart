import 'package:flutter/material.dart';

import '../dot_matrix/show_player.dart';
import '../models/show_store.dart';
import '../platform/screen_mode.dart';
import '../sound/flip_sound.dart';
import 'editor/panel_editor.dart';
import 'editor/scene_editor.dart';
import 'editor/scene_strip.dart';
import 'sign_screen.dart';

/// Preview, scene list and editors; side by side on wide screens, stacked
/// on phones.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ShowStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _selectedId = widget.store.value.scenes.first.id;

  /// Preview the whole show instead of only the selected scene.
  bool _playAll = false;
  int? _playingIndex;

  ShowStore get store => widget.store;

  void _select(String id) => setState(() => _selectedId = id);

  void _openSign() {
    // Within the tap itself, so the browser allows going fullscreen.
    enterSignMode();
    FlipSound.instance.unlock();
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
    // The selected scene may have been deleted.
    if (store.value.indexOf(_selectedId) < 0) {
      _selectedId = store.value.scenes.first.id;
    }

    final preview = Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: InkWell(
        onTap: _openSign,
        child: ValueListenableBuilder(
          valueListenable: store,
          builder: (context, show, _) => ShowPlayer(
            show: show,
            soloSceneId: _playAll ? null : _selectedId,
            onSceneChanged: (i) => setState(() => _playingIndex = i),
            sound: true,
          ),
        ),
      ),
    );

    final strip = SceneStrip(
      store: store,
      selectedId: _selectedId,
      playingIndex: _playAll ? _playingIndex : null,
      onSelect: _select,
    );

    final editors = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '선택한 장면'),
              Tab(text: '패널 (공통)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SceneEditor(
                  key: ValueKey(_selectedId),
                  store: store,
                  sceneId: _selectedId,
                ),
                PanelEditor(store: store),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dotty'),
        actions: [
          Tooltip(
            message: _playAll ? '선택한 장면만 미리보기' : '모든 장면을 순서대로 미리보기',
            child: OutlinedButton.icon(
              icon: Icon(_playAll ? Icons.stop : Icons.playlist_play),
              label: Text(_playAll ? '연속 재생 끄기' : '연속 재생'),
              onPressed: () => setState(() {
                _playAll = !_playAll;
                _playingIndex = _playAll ? 0 : null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.fullscreen),
              label: const Text('전체 화면'),
              onPressed: _openSign,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(aspectRatio: 3, child: preview),
                        ),
                      ),
                      strip,
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: editors),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.24).clamp(100, 220),
                width: double.infinity,
                child: preview,
              ),
              strip,
              const Divider(height: 1),
              Expanded(child: editors),
            ],
          );
        },
      ),
    );
  }
}

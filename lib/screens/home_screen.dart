import 'package:flutter/material.dart';

import '../dot_matrix/show_player.dart';
import '../l10n.dart';
import '../dot_matrix/sign_geometry.dart';
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
        // The whole show only when continuous play is on; otherwise just
        // the scene being edited, as in the preview.
        pageBuilder: (_, _, _) => SignScreen(
          store: store,
          soloSceneId: _playAll ? null : _selectedId,
        ),
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

    // Shaped exactly like the fullscreen sign, so what is set up here is
    // what will be shown.
    final preview = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ValueListenableBuilder(
        valueListenable: store,
        builder: (context, show, _) {
          final panel = show.panel;
          final columns = signColumns(panel, signAspect(context, panel));
          return Center(
            child: AspectRatio(
              aspectRatio: columns / panel.rows,
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: _openSign,
                  child: ShowPlayer(
                    show: show,
                    soloSceneId: _playAll ? null : _selectedId,
                    onSceneChanged: (i) => setState(() => _playingIndex = i),
                    sound: true,
                  ),
                ),
              ),
            ),
          );
        },
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
          TabBar(
            tabs: [
              Tab(text: context.tr('Selected scene', '선택한 장면')),
              Tab(text: context.tr('Panel (all scenes)', '패널 (공통)')),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 30, height: 30),
            const SizedBox(width: 10),
            const Flexible(
              child: Text('Dotty', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          // Named in the language it switches to; just an icon on phones,
          // where the app bar is short of room.
          if (MediaQuery.sizeOf(context).width < 600)
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: context.tr('한국어', 'English'),
              onPressed: LanguageScope.maybeOf(context)?.toggle,
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.translate, size: 18),
              label: Text(context.tr('한국어', 'English')),
              onPressed: LanguageScope.maybeOf(context)?.toggle,
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: _playAll
                ? context.tr('Preview only the selected scene', '선택한 장면만 미리보기')
                : context.tr('Preview all scenes in order', '모든 장면을 순서대로 미리보기'),
            child: OutlinedButton.icon(
              icon: Icon(_playAll ? Icons.stop : Icons.playlist_play),
              label: Text(
                _playAll
                    ? context.tr('Stop play all', '연속 재생 끄기')
                    : context.tr('Play all', '연속 재생'),
              ),
              onPressed: () => setState(() {
                _playAll = !_playAll;
                _playingIndex = _playAll ? 0 : null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: _playAll
                  ? context.tr(
                      'All scenes in order, fullscreen',
                      '모든 장면을 순서대로 전체 화면으로',
                    )
                  : context.tr(
                      'Only the selected scene, fullscreen',
                      '선택한 장면만 전체 화면으로',
                    ),
              child: FilledButton.icon(
                icon: const Icon(Icons.fullscreen),
                label: Text(context.tr('Fullscreen', '전체 화면')),
                onPressed: _openSign,
              ),
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
                      Expanded(child: preview),
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
                height: (constraints.maxHeight * 0.3).clamp(120, 260),
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

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

  /// The preview stands still (tap it, or the pause button).
  bool _paused = false;

  /// Bumped to play the preview again from the start.
  int _restarts = 0;

  ShowStore get store => widget.store;

  void _select(String id) => setState(() => _selectedId = id);

  void _togglePause() => setState(() => _paused = !_paused);

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
                  // Tapping the preview pauses it; fullscreen has its own
                  // button, so a stray tap never leaves the editor.
                  onTap: _togglePause,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ShowPlayer(
                        key: ValueKey(_restarts),
                        show: show,
                        paused: _paused,
                        soloSceneId: _playAll ? null : _selectedId,
                        onSceneChanged: (i) =>
                            setState(() => _playingIndex = i),
                        sound: true,
                      ),
                      if (_paused)
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x99000000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.pause,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          IconButton.filledTonal(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            tooltip: _paused
                ? context.tr('Play', '재생')
                : context.tr('Pause', '일시정지'),
            onPressed: _togglePause,
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.replay),
            tooltip: context.tr('Play from the start', '처음부터 다시'),
            onPressed: () => setState(() {
              _restarts++;
              _paused = false;
              _playingIndex = _playAll ? 0 : null;
            }),
          ),
          Tooltip(
            message: _playAll
                ? context.tr('Preview only the selected scene', '선택한 장면만 미리보기')
                : context.tr('Preview all scenes in order', '모든 장면을 순서대로 미리보기'),
            child: FilterChip(
              avatar: const Icon(Icons.playlist_play, size: 18),
              label: Text(context.tr('Play all', '연속 재생')),
              selected: _playAll,
              showCheckmark: false,
              onSelected: (v) => setState(() {
                _playAll = v;
                _playingIndex = v ? 0 : null;
                _restarts++;
              }),
            ),
          ),
          Tooltip(
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
        ],
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
              Tab(text: context.tr('This scene', '이 장면')),
              Tab(text: context.tr('Sign (all scenes)', '전광판 (모든 장면)')),
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
          const SizedBox(width: 8),
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
                      controls,
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
                height: (constraints.maxHeight * 0.26).clamp(110, 240),
                width: double.infinity,
                child: preview,
              ),
              controls,
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

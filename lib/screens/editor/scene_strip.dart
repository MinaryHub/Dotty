import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../dot_matrix/dot_matrix_display.dart';
import '../../models/show.dart';
import '../../models/show_store.dart';
import 'scene_editor.dart';

/// Horizontal list of the show's scenes: select, reorder (long-press and
/// drag, or the card menu), duplicate, delete, and add new ones.
class SceneStrip extends StatelessWidget {
  const SceneStrip({
    super.key,
    required this.store,
    required this.selectedId,
    required this.playingIndex,
    required this.onSelect,
  });

  final ShowStore store;
  final String selectedId;

  /// Highlighted while the whole show is previewed.
  final int? playingIndex;
  final ValueChanged<String> onSelect;

  /// Adds a scene after the selection and selects it.
  void _add(SceneKind kind, {Uint8List? image}) {
    final id = newSceneId();
    store.addScene(
      Scene(
        id: id,
        kind: kind,
        image: image,
        text: kind == SceneKind.text ? '새 장면' : '',
        direction: kind == SceneKind.image
            ? MarqueeDirection.none
            : MarqueeDirection.left,
        durationMode: kind == SceneKind.image
            ? DurationMode.seconds
            : DurationMode.passes,
      ),
      afterId: selectedId,
    );
    onSelect(id);
  }

  /// Picks first and only adds the scene if an image was chosen.
  Future<void> _addImage(BuildContext context) async {
    final image = await pickImageWithFeedback(context);
    if (image != null) _add(SceneKind.image, image: image);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, show, _) {
        return SizedBox(
          height: 104,
          child: Row(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: show.scenes.length,
                  onReorderItem: store.moveScene,
                  itemBuilder: (context, i) {
                    final scene = show.scenes[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(scene.id),
                      index: i,
                      child: _SceneCard(
                        index: i,
                        count: show.scenes.length,
                        scene: scene,
                        panel: show.panel,
                        selected: scene.id == selectedId,
                        playing: i == playingIndex,
                        onTap: () => onSelect(scene.id),
                        onMove: (to) => store.moveScene(i, to),
                        onDuplicate: () =>
                            onSelect(store.duplicateScene(scene.id)),
                        onDelete: () {
                          final next = show.scenes[i == 0 ? 1 : i - 1].id;
                          store.removeScene(scene.id);
                          if (scene.id == selectedId) onSelect(next);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AddButton(
                      icon: Icons.text_fields,
                      label: '문구 추가',
                      onPressed: () => _add(SceneKind.text),
                    ),
                    const SizedBox(height: 6),
                    _AddButton(
                      icon: Icons.add_photo_alternate_outlined,
                      label: '이미지 추가',
                      onPressed: () => _addImage(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Icon-only on phones to leave room for the scene cards.
    if (MediaQuery.sizeOf(context).width < 600) {
      return IconButton.outlined(
        icon: Icon(icon),
        tooltip: label,
        onPressed: onPressed,
      );
    }
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: onPressed,
    );
  }
}

enum _CardAction { left, right, duplicate, delete }

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.index,
    required this.count,
    required this.scene,
    required this.panel,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onMove,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final int count;
  final Scene scene;
  final PanelSettings panel;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final ValueChanged<int> onMove;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  String get _timing => scene.usesPasses
      ? '스크롤 ${scene.passes}회'
      : '${scene.durationSeconds.round()}초';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = selected
        ? colors.primary
        : playing
        ? colors.tertiary
        : colors.outlineVariant;
    // Thumbnail: the scene's start, centered and still.
    final thumb = scene.copyWith(
      direction: MarqueeDirection.none,
      blink: false,
      rainbow: false,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: selected || playing ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: IgnorePointer(
                    child: DotMatrixDisplay(
                      scene: thumb,
                      panel: panel.copyWith(glow: false),
                      paused: true,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        scene.kind == SceneKind.image
                            ? Icons.image_outlined
                            : Icons.text_fields,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _timing,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<_CardAction>(
                        tooltip: '장면 메뉴',
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        onSelected: (a) => switch (a) {
                          _CardAction.left => onMove(index - 1),
                          _CardAction.right => onMove(index + 1),
                          _CardAction.duplicate => onDuplicate(),
                          _CardAction.delete => onDelete(),
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _CardAction.left,
                            enabled: index > 0,
                            child: const Text('앞으로 이동'),
                          ),
                          PopupMenuItem(
                            value: _CardAction.right,
                            enabled: index < count - 1,
                            child: const Text('뒤로 이동'),
                          ),
                          const PopupMenuItem(
                            value: _CardAction.duplicate,
                            child: Text('복제'),
                          ),
                          PopupMenuItem(
                            value: _CardAction.delete,
                            enabled: count > 1,
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

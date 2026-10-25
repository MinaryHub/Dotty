import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../dot_matrix/dot_matrix_display.dart';
import '../../l10n.dart';
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
  void _add(BuildContext context, SceneKind kind, {Uint8List? image}) {
    final id = newSceneId();
    store.addScene(
      Scene(
        id: id,
        kind: kind,
        image: image,
        text: kind == SceneKind.text ? context.tr('New scene', '새 장면') : '',
        direction: kind == SceneKind.text
            ? MarqueeDirection.left
            : MarqueeDirection.none,
        durationMode: kind == SceneKind.text
            ? DurationMode.passes
            : DurationMode.seconds,
        dotColor: kind == SceneKind.clock
            ? const Color(0xFF00E5FF)
            : const Scene(id: '').dotColor,
      ),
      afterId: selectedId,
    );
    onSelect(id);
  }

  /// Picks first and only adds the scene if an image was chosen.
  Future<void> _addImage(BuildContext context) async {
    final image = await pickImageWithFeedback(context);
    if (image != null && context.mounted) {
      _add(context, SceneKind.image, image: image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, show, _) {
        return SizedBox(
          height: 136,
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
                      label: context.tr('Add text', '문구 추가'),
                      onPressed: () => _add(context, SceneKind.text),
                    ),
                    const SizedBox(height: 4),
                    _AddButton(
                      icon: Icons.add_photo_alternate_outlined,
                      label: context.tr('Add image', '이미지 추가'),
                      onPressed: () => _addImage(context),
                    ),
                    const SizedBox(height: 4),
                    _AddButton(
                      icon: Icons.schedule,
                      label: context.tr('Add clock', '시계 추가'),
                      onPressed: () => _add(context, SceneKind.clock),
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

  String _timing(BuildContext context) => scene.usesPasses
      ? context.tr('Scroll ${scene.passes}×', '스크롤 ${scene.passes}회')
      : context.tr(
          '${scene.durationSeconds.round()} s',
          '${scene.durationSeconds.round()}초',
        );

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
                      Icon(switch (scene.kind) {
                        SceneKind.text => Icons.text_fields,
                        SceneKind.image => Icons.image_outlined,
                        SceneKind.clock => Icons.schedule,
                      }, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _timing(context),
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<_CardAction>(
                        tooltip: context.tr('Scene menu', '장면 메뉴'),
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
                            child: Text(context.tr('Move earlier', '앞으로 이동')),
                          ),
                          PopupMenuItem(
                            value: _CardAction.right,
                            enabled: index < count - 1,
                            child: Text(context.tr('Move later', '뒤로 이동')),
                          ),
                          PopupMenuItem(
                            value: _CardAction.duplicate,
                            child: Text(context.tr('Duplicate', '복제')),
                          ),
                          PopupMenuItem(
                            value: _CardAction.delete,
                            enabled: count > 1,
                            child: Text(context.tr('Delete', '삭제')),
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

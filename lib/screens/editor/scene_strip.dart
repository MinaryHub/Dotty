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
        final narrow = MediaQuery.sizeOf(context).width < 600;
        return SizedBox(
          height: narrow ? 112 : 136,
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
                        compact: narrow,
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
                          final wasSelected = scene.id == selectedId;
                          store.removeScene(scene.id);
                          if (wasSelected) onSelect(next);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('Scene deleted', '장면을 삭제했습니다'),
                                ),
                                action: SnackBarAction(
                                  label: context.tr('Undo', '되돌리기'),
                                  onPressed: () {
                                    store.insertScene(scene, i);
                                    if (wasSelected) onSelect(scene.id);
                                  },
                                ),
                              ),
                            );
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AddMenu(
                  compact: narrow,
                  onText: () => _add(context, SceneKind.text),
                  onImage: () => _addImage(context),
                  onClock: () => _add(context, SceneKind.clock),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One button that offers the kinds of scene to add.
class _AddMenu extends StatelessWidget {
  const _AddMenu({
    required this.compact,
    required this.onText,
    required this.onImage,
    required this.onClock,
  });

  final bool compact;
  final VoidCallback onText;
  final VoidCallback onImage;
  final VoidCallback onClock;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.text_fields),
          onPressed: onText,
          child: Text(context.tr('Text', '문구')),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add_photo_alternate_outlined),
          onPressed: onImage,
          child: Text(context.tr('Image…', '이미지…')),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.schedule),
          onPressed: onClock,
          child: Text(context.tr('Clock', '시계')),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final label = context.tr('Add scene', '장면 추가');
        if (compact) {
          return IconButton.filled(
            icon: const Icon(Icons.add),
            tooltip: label,
            onPressed: toggle,
          );
        }
        return FilledButton.icon(
          icon: const Icon(Icons.add),
          label: Text(label),
          onPressed: toggle,
        );
      },
    );
  }
}

enum _CardAction { left, right, duplicate, delete }

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.compact,
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

  final bool compact;
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
            width: compact ? 124 : 150,
            child: Column(
              children: [
                SizedBox(
                  height: compact ? 40 : 50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: DotMatrixDisplay(
                          scene: thumb,
                          panel: panel.copyWith(glow: false),
                          paused: true,
                        ),
                      ),
                      // What the scene does, at a glance.
                      Positioned(
                        right: 3,
                        top: 3,
                        child: _StatusIcons(scene: scene),
                      ),
                    ],
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

/// Small icons for how a scene moves and which effects it uses.
class _StatusIcons extends StatelessWidget {
  const _StatusIcons({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final s = scene;
    final icons = [
      if (s.isStill)
        (Icons.pause, context.tr('Still', '고정'))
      else if (s.direction == MarqueeDirection.left)
        (Icons.arrow_back, context.tr('Scrolls left', '왼쪽으로 흐름'))
      else
        (Icons.arrow_forward, context.tr('Scrolls right', '오른쪽으로 흐름')),
      if (s.blink) (Icons.flash_on, context.tr('Blinks', '깜빡임')),
      if (s.isStill && s.flipAll) (Icons.flip, context.tr('Flip all', '전체 플립')),
      if (s.isStill && s.replay)
        (Icons.replay, context.tr('Replays its entrance', '다시 나타나기')),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label) in icons)
              Tooltip(
                message: label,
                child: Icon(icon, size: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

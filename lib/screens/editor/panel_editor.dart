import 'package:flutter/material.dart';

import '../../models/show.dart';
import '../../models/show_store.dart';
import 'controls.dart';

/// Edits the settings shared by all scenes: the sign's dot grid and look.
class PanelEditor extends StatelessWidget {
  const PanelEditor({super.key, required this.store});

  final ShowStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, show, _) {
        final p = show.panel;
        void update(PanelSettings Function(PanelSettings p) change) =>
            store.updatePanel(change);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SectionHeader('도트'),
            LabeledSlider(
              label: '해상도 (세로 점 수)',
              value: p.rows.toDouble(),
              min: PanelSettings.minRows.toDouble(),
              max: PanelSettings.maxRows.toDouble(),
              divisions: PanelSettings.maxRows - PanelSettings.minRows,
              display: (v) => '${v.round()}',
              onChanged: (v) => update((p) => p.copyWith(rows: v.round())),
            ),
            LabeledSlider(
              label: '점 크기',
              value: p.dotFill,
              min: 0.3,
              max: 1,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => update((p) => p.copyWith(dotFill: v)),
            ),
            LabeledSlider(
              label: '꺼진 점 밝기',
              value: p.offDotOpacity,
              min: 0,
              max: 0.4,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => update((p) => p.copyWith(offDotOpacity: v)),
            ),
            const SizedBox(height: 8),
            ChoiceRow<DotShape>(
              options: const [
                (DotShape.circle, Icons.circle, '원형'),
                (DotShape.square, Icons.square, '사각형'),
              ],
              selected: p.shape,
              onSelected: (v) => update((p) => p.copyWith(shape: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('빛 번짐 (글로우)'),
              value: p.glow,
              onChanged: (v) => update((p) => p.copyWith(glow: v)),
            ),
            const SectionHeader('배경'),
            ColorSwatches(
              colors: backgroundColors,
              selected: p.backgroundColor,
              onSelected: (c) => update((p) => p.copyWith(backgroundColor: c)),
            ),
            const SectionHeader('전환'),
            LabeledSlider(
              label: '전환 효과 시간',
              value: p.transitionMs,
              min: 100,
              max: 2000,
              divisions: 19,
              display: (v) => '${(v / 1000).toStringAsFixed(1)}초',
              onChanged: (v) => update((p) => p.copyWith(transitionMs: v)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('패널 설정 초기화'),
              onPressed: store.resetPanel,
            ),
          ],
        );
      },
    );
  }
}

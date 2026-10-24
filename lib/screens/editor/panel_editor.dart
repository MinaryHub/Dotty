import 'package:flutter/material.dart';

import '../../models/show.dart';
import '../../models/show_store.dart';
import '../../sound/flip_sound.dart';
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
            const SectionHeader('표시 방식'),
            ChoiceRow<bool>(
              options: const [
                (false, Icons.lightbulb_outline, 'LED'),
                (true, Icons.flip, '플립 도트'),
              ],
              selected: p.flipDots,
              onSelected: (v) {
                FlipSound.instance.unlock();
                update((p) => p.copyWith(flipDots: v));
              },
            ),
            Hint(
              p.flipDots
                  ? '실제 플립 도트 전광판처럼 바뀌는 점만 하나씩 뒤집힙니다. '
                        '장면 전환 효과에 따라 뒤집히는 순서가 달라집니다.'
                  : '빛나는 LED 전광판입니다.',
            ),
            if (p.flipDots) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('뒤집히는 소리'),
                value: p.flipSound,
                onChanged: (v) {
                  FlipSound.instance.unlock();
                  update((p) => p.copyWith(flipSound: v));
                },
              ),
              LabeledSlider(
                label: '음량',
                value: p.soundVolume,
                min: 0,
                max: 1,
                display: (v) => '${(v * 100).round()}%',
                onChanged: p.flipSound
                    ? (v) => update((p) => p.copyWith(soundVolume: v))
                    : null,
              ),
            ],
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
            if (!p.flipDots)
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

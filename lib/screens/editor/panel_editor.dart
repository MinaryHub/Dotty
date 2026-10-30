import 'package:flutter/material.dart';

import '../../l10n.dart';

import '../../dot_matrix/sign_geometry.dart';
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
            SectionHeader(context.tr('Display type', '표시 방식')),
            ChoiceRow<bool>(
              options: [
                (false, Icons.lightbulb_outline, 'LED'),
                (true, Icons.flip, context.tr('Flip dots', '플립 도트')),
              ],
              selected: p.flipDots,
              onSelected: (v) {
                FlipSound.instance.unlock();
                update((p) => p.copyWith(flipDots: v));
              },
            ),
            Hint(
              p.flipDots
                  ? context.tr(
                      'Like a real flip-dot sign, only the dots that change flip, one by one. The flip order depends on the scene transition.',
                      '실제 플립 도트 전광판처럼 바뀌는 점만 하나씩 뒤집힙니다. 장면 전환 효과에 따라 뒤집히는 순서가 달라집니다.',
                    )
                  : context.tr('A glowing LED sign.', '빛나는 LED 전광판입니다.'),
            ),
            if (p.flipDots) ...[
              LabeledSlider(
                label: context.tr('Disc flip time', '원판 뒤집힘 시간'),
                value: p.flipSeconds,
                min: 0.08,
                max: 1.0,
                display: (v) => context.tr(
                  '${v.toStringAsFixed(2)} s',
                  '${v.toStringAsFixed(2)}초',
                ),
                onChanged: (v) => update((p) => p.copyWith(flipSeconds: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr('Flip every dot in transitions', '전환할 때 모든 점 뒤집기'),
                ),
                subtitle: Text(
                  context.tr(
                    'Dots that stay the same also turn over and back in the wave. Off: only the dots that change flip.',
                    '바뀌지 않는 점도 물결에 맞춰 뒤집혔다가 돌아옵니다. 끄면 바뀌는 점만 뒤집힙니다.',
                  ),
                ),
                value: p.flipUnchanged,
                onChanged: (v) {
                  FlipSound.instance.unlock();
                  update((p) => p.copyWith(flipUnchanged: v));
                },
              ),
              Hint(
                context.tr(
                  'How long one disc takes to flip and settle. Best seen when a still scene changes. For fast scrolling or blinking it is shortened automatically so text stays readable; lower the scroll speed (e.g. 5 dots/s) to watch the discs turn. How long the wave takes to cross the sign on a scene change is set by "Transition time" below.',
                  '원판 하나가 뒤집혀 멈출 때까지의 시간입니다. 고정된 장면이 바뀔 때 가장 잘 보입니다. 빠르게 흐르는 글자나 깜빡임에서는 글자가 뭉개지지 않도록 자동으로 짧아지니, 뒤집히는 모습을 보려면 스크롤 속도를 낮추세요 (예: 5칸/초). 장면이 바뀔 때 물결이 화면을 지나가는 시간은 아래 "전환 효과 시간"으로 조절합니다.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Flip sound', '뒤집히는 소리')),
                value: p.flipSound,
                onChanged: (v) {
                  FlipSound.instance.unlock();
                  update((p) => p.copyWith(flipSound: v));
                },
              ),
              LabeledSlider(
                label: context.tr('Volume', '음량'),
                value: p.soundVolume,
                min: 0,
                max: 1,
                display: (v) => '${(v * 100).round()}%',
                onChanged: p.flipSound
                    ? (v) => update((p) => p.copyWith(soundVolume: v))
                    : null,
              ),
            ],
            SectionHeader(context.tr('Aspect ratio', '화면 비율')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (ratio, label) in [
                  (0.0, context.tr('Auto (this screen)', '자동 (이 화면)')),
                  (16 / 9, '16:9'),
                  (4 / 3, '4:3'),
                  (21 / 9, '21:9'),
                  (32 / 9, '32:9'),
                  (3.0, '3:1'),
                  (2.0, '2:1'),
                  (1.0, '1:1'),
                  (9 / 16, context.tr('9:16 portrait', '9:16 세로')),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: (p.aspectRatio - ratio).abs() < 0.001,
                    onSelected: (_) =>
                        update((p) => p.copyWith(aspectRatio: ratio)),
                  ),
              ],
            ),
            Builder(
              builder: (context) {
                final columns = signColumns(p, signAspect(context, p));
                return Hint(
                  context.tr(
                    '$columns × ${p.rows} dots. The preview and fullscreen look the same. "Auto" fills the fullscreen to this device\'s screen shape and turns with it.',
                    '가로 $columns × 세로 ${p.rows} 점. 미리보기와 전체 화면이 같은 모양으로 보입니다. "자동"은 이 기기 화면 비율에 맞춰 전체 화면을 꽉 채웁니다.',
                  ),
                );
              },
            ),
            SectionHeader(context.tr('Dots', '도트')),
            LabeledSlider(
              label: context.tr('Resolution (dots tall)', '해상도 (세로 점 수)'),
              value: p.rows.toDouble(),
              min: PanelSettings.minRows.toDouble(),
              max: PanelSettings.maxRows.toDouble(),
              divisions: PanelSettings.maxRows - PanelSettings.minRows,
              display: (v) => '${v.round()}',
              onChanged: (v) => update((p) => p.copyWith(rows: v.round())),
            ),
            LabeledSlider(
              label: context.tr('Dot size', '점 크기'),
              value: p.dotFill,
              min: 0.3,
              max: 1,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => update((p) => p.copyWith(dotFill: v)),
            ),
            LabeledSlider(
              label: context.tr('Unlit dot brightness', '꺼진 점 밝기'),
              value: p.offDotOpacity,
              min: 0,
              max: 0.4,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => update((p) => p.copyWith(offDotOpacity: v)),
            ),
            const SizedBox(height: 8),
            ChoiceRow<DotShape>(
              options: [
                (DotShape.circle, Icons.circle, context.tr('Round', '원형')),
                (DotShape.square, Icons.square, context.tr('Square', '사각형')),
              ],
              selected: p.shape,
              onSelected: (v) => update((p) => p.copyWith(shape: v)),
            ),
            if (!p.flipDots)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Glow', '빛 번짐 (글로우)')),
                value: p.glow,
                onChanged: (v) => update((p) => p.copyWith(glow: v)),
              ),
            SectionHeader(context.tr('Background', '배경')),
            ColorSwatches(
              colors: backgroundColors,
              selected: p.backgroundColor,
              onSelected: (c) => update((p) => p.copyWith(backgroundColor: c)),
            ),
            SectionHeader(context.tr('Transitions', '전환')),
            LabeledSlider(
              label: context.tr('Transition time', '전환 효과 시간'),
              value: p.transitionMs,
              min: 100,
              max: 2000,
              divisions: 19,
              display: (v) => context.tr(
                '${(v / 1000).toStringAsFixed(1)} s',
                '${(v / 1000).toStringAsFixed(1)}초',
              ),
              onChanged: (v) => update((p) => p.copyWith(transitionMs: v)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: Text(context.tr('Reset panel settings', '패널 설정 초기화')),
              onPressed: store.resetPanel,
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n.dart';

import '../../dot_matrix/sign_geometry.dart';
import '../../models/show.dart';
import '../../models/show_store.dart';
import '../../sound/flip_sound.dart';
import 'controls.dart';

/// Edits the settings shared by all scenes: the sign's dot grid and look.
class PanelEditor extends StatefulWidget {
  const PanelEditor({super.key, required this.store});

  final ShowStore store;

  @override
  State<PanelEditor> createState() => _PanelEditorState();
}

class _PanelEditorState extends State<PanelEditor> {
  /// Whether the less common aspect ratios are listed too.
  bool _moreRatios = false;

  ShowStore get store => widget.store;

  static const _commonRatios = [0.0, 16 / 9, 4 / 3, 9 / 16];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, show, _) {
        final p = show.panel;
        void update(PanelSettings Function(PanelSettings p) change) =>
            store.updatePanel(change);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          children: [
            SettingsGroup(
              id: 'panel-type',
              icon: p.flipDots ? Icons.flip : Icons.lightbulb_outline,
              title: context.tr('Display type', '표시 방식'),
              summary: p.flipDots
                  ? context.tr(
                      'Flip dots${p.flipSound ? ' · sound on' : ''}',
                      '플립 도트${p.flipSound ? ' · 소리 켜짐' : ''}',
                    )
                  : context.tr('LED', 'LED'),
              initiallyOpen: true,
              children: [
                Row(
                  children: [
                    for (final (flip, icon, title, about) in [
                      (
                        false,
                        Icons.lightbulb_outline,
                        'LED',
                        context.tr('Glowing lights', '빛나는 전구'),
                      ),
                      (
                        true,
                        Icons.flip,
                        context.tr('Flip dots', '플립 도트'),
                        context.tr('Discs that turn over', '뒤집히는 원판'),
                      ),
                    ])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: flip ? 0 : 8),
                          child: _TypeCard(
                            icon: icon,
                            title: title,
                            about: about,
                            selected: p.flipDots == flip,
                            onTap: () {
                              FlipSound.instance.unlock();
                              update((p) => p.copyWith(flipDots: flip));
                            },
                          ),
                        ),
                      ),
                  ],
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
                      context.tr(
                        'Flip every dot in transitions',
                        '전환할 때 모든 점 뒤집기',
                      ),
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
              ],
            ),
            SettingsGroup(
              id: 'panel-shape',
              icon: Icons.aspect_ratio,
              title: context.tr('Shape and size', '모양과 크기'),
              summary: _shapeSummary(context, p),
              children: [
                FieldLabel(context.tr('Aspect ratio', '화면 비율')),
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
                      if (_moreRatios ||
                          _commonRatios.contains(ratio) ||
                          (p.aspectRatio - ratio).abs() < 0.001)
                        ChoiceChip(
                          label: Text(label),
                          selected: (p.aspectRatio - ratio).abs() < 0.001,
                          onSelected: (_) =>
                              update((p) => p.copyWith(aspectRatio: ratio)),
                        ),
                    ActionChip(
                      avatar: Icon(
                        _moreRatios ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _moreRatios
                            ? context.tr('Fewer', '접기')
                            : context.tr('More', '더보기'),
                      ),
                      onPressed: () =>
                          setState(() => _moreRatios = !_moreRatios),
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
                LabeledSlider(
                  label: context.tr('Dots tall (detail)', '세로 점 수 (선명도)'),
                  value: p.rows.toDouble(),
                  min: PanelSettings.minRows.toDouble(),
                  max: PanelSettings.maxRows.toDouble(),
                  divisions: PanelSettings.maxRows - PanelSettings.minRows,
                  display: (v) => '${v.round()}',
                  onChanged: (v) => update((p) => p.copyWith(rows: v.round())),
                ),
              ],
            ),
            SettingsGroup(
              id: 'panel-dots',
              icon: Icons.blur_on,
              title: context.tr('Dots and background', '점과 배경'),
              summary: _dotsSummary(context, p),
              trailing: ColorDot(color: p.backgroundColor),
              children: [
                LabeledSlider(
                  label: context.tr('Dot size', '점 크기'),
                  value: p.dotFill,
                  min: 0.3,
                  max: 1,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => update((p) => p.copyWith(dotFill: v)),
                ),
                LabeledSlider(
                  label: context.tr('Show unlit dots', '꺼진 점 보이기'),
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
                    (
                      DotShape.square,
                      Icons.square,
                      context.tr('Square', '사각형'),
                    ),
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
                FieldLabel(context.tr('Background', '배경')),
                ColorSwatches(
                  colors: backgroundColors,
                  selected: p.backgroundColor,
                  onSelected: (c) =>
                      update((p) => p.copyWith(backgroundColor: c)),
                ),
              ],
            ),
            SettingsGroup(
              id: 'panel-transitions',
              icon: Icons.skip_next_outlined,
              title: context.tr('Scene changes', '장면 전환'),
              summary: context.tr(
                'Transition time ${(p.transitionMs / 1000).toStringAsFixed(1)} s',
                '전환 효과 시간 ${(p.transitionMs / 1000).toStringAsFixed(1)}초',
              ),
              children: [
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
                Hint(
                  context.tr(
                    'How long a scene change takes, for every scene. Each scene picks its own effect.',
                    '모든 장면에 공통인 전환 시간입니다. 효과 종류는 장면마다 고릅니다.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: Text(context.tr('Reset sign settings', '전광판 설정 초기화')),
              onPressed: store.resetPanel,
            ),
          ],
        );
      },
    );
  }

  String _shapeSummary(BuildContext context, PanelSettings p) {
    final ratio = p.aspectRatio == 0
        ? context.tr('Auto', '자동')
        : switch (p.aspectRatio) {
            final r when (r - 16 / 9).abs() < 0.001 => '16:9',
            final r when (r - 4 / 3).abs() < 0.001 => '4:3',
            final r when (r - 21 / 9).abs() < 0.001 => '21:9',
            final r when (r - 32 / 9).abs() < 0.001 => '32:9',
            final r when (r - 9 / 16).abs() < 0.001 => '9:16',
            final r => '${r.toStringAsFixed(r == r.roundToDouble() ? 0 : 2)}:1',
          };
    final columns = signColumns(p, signAspect(context, p));
    return context.tr(
      '$ratio · $columns × ${p.rows} dots',
      '$ratio · 가로 $columns × 세로 ${p.rows} 점',
    );
  }

  String _dotsSummary(BuildContext context, PanelSettings p) => [
    p.shape == DotShape.circle
        ? context.tr('Round', '원형')
        : context.tr('Square', '사각형'),
    context.tr(
      'size ${(p.dotFill * 100).round()}%',
      '크기 ${(p.dotFill * 100).round()}%',
    ),
    if (!p.flipDots && p.glow) context.tr('glow', '빛 번짐'),
  ].join(' · ');
}

/// A large choice between the two kinds of sign.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.about,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String about;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? colors.onPrimaryContainer : null,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? colors.onPrimaryContainer : null,
                ),
              ),
              Text(
                about,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

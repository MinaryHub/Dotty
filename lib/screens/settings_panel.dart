import 'package:flutter/material.dart';

import '../models/display_settings.dart';
import '../models/settings_store.dart';

const _dotColors = [
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00E5FF),
  Color(0xFF2F7BFF),
  Color(0xFFB36BFF),
  Color(0xFFFF4FA3),
  Color(0xFFFFFFFF),
];

const _backgroundColors = [
  Color(0xFF000000),
  Color(0xFF0A0A0A),
  Color(0xFF101828),
  Color(0xFF1A0F0A),
  Color(0xFF0B1A10),
  Color(0xFF2A2A2A),
];

const _presets = [
  'HELLO DOTTY',
  '안녕하세요',
  'OPEN',
  'WELCOME',
  '영업중',
  '♥ I LOVE YOU ♥',
  '12:34',
];

/// Every display option, edited live against [store].
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.store});

  final SettingsStore store;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final _text = TextEditingController(text: widget.store.value.text);

  SettingsStore get store => widget.store;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _setText(String value) {
    _text.text = value;
    store.update((s) => s.copyWith(text: value));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, s, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _Header('문구'),
            TextField(
              controller: _text,
              decoration: InputDecoration(
                hintText: '표시할 문구를 입력하세요',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '지우기',
                  onPressed: () => _setText(''),
                ),
              ),
              onChanged: (v) => store.update((s) => s.copyWith(text: v)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _presets)
                  ActionChip(label: Text(p), onPressed: () => _setText(p)),
              ],
            ),
            const _Header('색상'),
            const _Label('점 색상'),
            _Swatches(
              colors: _dotColors,
              selected: s.rainbow ? null : s.dotColor,
              onSelected: (c) =>
                  store.update((s) => s.copyWith(dotColor: c, rainbow: false)),
            ),
            _LabeledSlider(
              label: '색조',
              value: HSVColor.fromColor(s.dotColor).hue,
              min: 0,
              max: 359,
              display: (v) => '${v.round()}°',
              onChanged: (v) => store.update(
                (s) => s.copyWith(
                  dotColor: HSVColor.fromAHSV(1, v, 0.85, 1).toColor(),
                  rainbow: false,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('무지개 효과'),
              value: s.rainbow,
              onChanged: (v) => store.update((s) => s.copyWith(rainbow: v)),
            ),
            const _Label('배경 색상'),
            _Swatches(
              colors: _backgroundColors,
              selected: s.backgroundColor,
              onSelected: (c) =>
                  store.update((s) => s.copyWith(backgroundColor: c)),
            ),
            const _Header('움직임'),
            SegmentedButton<MarqueeDirection>(
              segments: const [
                ButtonSegment(
                  value: MarqueeDirection.left,
                  icon: Icon(Icons.arrow_back),
                  label: Text('왼쪽'),
                ),
                ButtonSegment(
                  value: MarqueeDirection.none,
                  icon: Icon(Icons.pause),
                  label: Text('고정'),
                ),
                ButtonSegment(
                  value: MarqueeDirection.right,
                  icon: Icon(Icons.arrow_forward),
                  label: Text('오른쪽'),
                ),
              ],
              selected: {s.direction},
              onSelectionChanged: (v) =>
                  store.update((s) => s.copyWith(direction: v.first)),
            ),
            _LabeledSlider(
              label: '속도',
              value: s.speed,
              min: 1,
              max: 120,
              display: (v) => '${v.round()} 칸/초',
              onChanged: s.direction == MarqueeDirection.none
                  ? null
                  : (v) => store.update((s) => s.copyWith(speed: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('깜빡임'),
              value: s.blink,
              onChanged: (v) => store.update((s) => s.copyWith(blink: v)),
            ),
            _LabeledSlider(
              label: '깜빡임 속도',
              value: s.blinkHz,
              min: 0.5,
              max: 8,
              display: (v) => '${v.toStringAsFixed(1)} Hz',
              onChanged: s.blink
                  ? (v) => store.update((s) => s.copyWith(blinkHz: v))
                  : null,
            ),
            const _Header('도트'),
            _LabeledSlider(
              label: '해상도 (세로 점 수)',
              value: s.rows.toDouble(),
              min: DisplaySettings.minRows.toDouble(),
              max: DisplaySettings.maxRows.toDouble(),
              divisions: DisplaySettings.maxRows - DisplaySettings.minRows,
              display: (v) => '${v.round()}',
              onChanged: (v) =>
                  store.update((s) => s.copyWith(rows: v.round())),
            ),
            _LabeledSlider(
              label: '점 크기',
              value: s.dotFill,
              min: 0.3,
              max: 1,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => store.update((s) => s.copyWith(dotFill: v)),
            ),
            _LabeledSlider(
              label: '꺼진 점 밝기',
              value: s.offDotOpacity,
              min: 0,
              max: 0.4,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) =>
                  store.update((s) => s.copyWith(offDotOpacity: v)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DotShape>(
              segments: const [
                ButtonSegment(
                  value: DotShape.circle,
                  icon: Icon(Icons.circle),
                  label: Text('원형'),
                ),
                ButtonSegment(
                  value: DotShape.square,
                  icon: Icon(Icons.square),
                  label: Text('사각형'),
                ),
              ],
              selected: {s.shape},
              onSelectionChanged: (v) =>
                  store.update((s) => s.copyWith(shape: v.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('굵은 글씨'),
              value: s.bold,
              onChanged: (v) => store.update((s) => s.copyWith(bold: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('빛 번짐 (글로우)'),
              value: s.glow,
              onChanged: (v) => store.update((s) => s.copyWith(glow: v)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('기본값으로 초기화'),
              onPressed: () {
                store.reset();
                _text.text = store.value.text;
              },
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in colors)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelected(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? outline : Colors.white24,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) display;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(display(v), style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

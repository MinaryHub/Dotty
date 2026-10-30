import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../models/show.dart';
import '../../models/show_store.dart';
import '../../platform/image_import.dart';
import 'controls.dart';

const _presets = [
  'HELLO DOTTY',
  '안녕하세요',
  'OPEN',
  'WELCOME',
  '영업중',
  '♥ I LOVE YOU ♥',
  '12:34',
];

/// Lets the user pick an image, reporting failures in a snack bar. Returns
/// null if cancelled or failed.
///
/// Call it first thing in a tap handler: browsers only open file dialogs
/// during the click's user gesture.
Future<Uint8List?> pickImageWithFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final unsupported = context.tr(
    'This image format can\'t be opened.',
    '이 이미지 형식은 열 수 없습니다.',
  );
  final failed = context.tr('Couldn\'t load the image', '이미지를 불러오지 못했습니다');
  try {
    return await pickImage();
  } on UnsupportedImageException {
    messenger.showSnackBar(SnackBar(content: Text(unsupported)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$failed: $e')));
  }
  return null;
}

/// Edits one scene. Key it by scene id so its text field resets when the
/// selection changes.
class SceneEditor extends StatefulWidget {
  const SceneEditor({super.key, required this.store, required this.sceneId});

  final ShowStore store;
  final String sceneId;

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  late final _text = TextEditingController(text: _scene?.text ?? '');
  bool _importing = false;

  ShowStore get store => widget.store;

  Scene? get _scene {
    final i = store.value.indexOf(widget.sceneId);
    return i < 0 ? null : store.value.scenes[i];
  }

  void _update(Scene Function(Scene s) change) =>
      store.updateScene(widget.sceneId, change);

  void _setText(String value) {
    _text.text = value;
    _update((s) => s.copyWith(text: value));
  }

  Future<void> _pickImage() async {
    final picking = pickImageWithFeedback(context);
    setState(() => _importing = true);
    final image = await picking;
    if (image != null) {
      _update((s) => s.copyWith(kind: SceneKind.image, image: image));
    }
    if (mounted) setState(() => _importing = false);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store,
      builder: (context, show, _) {
        final s = _scene;
        if (s == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            SectionHeader(context.tr('Content', '내용')),
            SegmentedButton<SceneKind>(
              segments: [
                ButtonSegment(
                  value: SceneKind.text,
                  icon: const Icon(Icons.text_fields),
                  label: Text(context.tr('Text', '문구')),
                ),
                ButtonSegment(
                  value: SceneKind.image,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.tr('Image', '이미지')),
                ),
                ButtonSegment(
                  value: SceneKind.clock,
                  icon: const Icon(Icons.schedule),
                  label: Text(context.tr('Clock', '시계')),
                ),
              ],
              selected: {s.kind},
              onSelectionChanged: (v) =>
                  _update((s) => s.copyWith(kind: v.first)),
            ),
            const SizedBox(height: 12),
            if (s.kind == SceneKind.text) ..._textFields(s),
            if (s.kind == SceneKind.image) ..._imageFields(s),
            if (s.kind == SceneKind.clock) ..._clockFields(s),
            if (s.usesDotColor) ..._colorFields(s),
            ..._motionFields(s),
            ..._timingFields(s, show),
          ],
        );
      },
    );
  }

  List<Widget> _textFields(Scene s) => [
    TextField(
      controller: _text,
      decoration: InputDecoration(
        hintText: context.tr(
          'Type the text to show (Enter for a new line)',
          '표시할 문구를 입력하세요 (Enter로 줄바꿈)',
        ),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.tr('Clear', '지우기'),
          onPressed: () => _setText(''),
        ),
      ),
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: 4,
      onChanged: (v) => _update((s) => s.copyWith(text: v)),
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
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Bold', '굵은 글씨')),
      value: s.bold,
      onChanged: (v) => _update((s) => s.copyWith(bold: v)),
    ),
    LabeledSlider(
      label: context.tr('Text size', '글자 크기'),
      value: s.textSize,
      min: 0.2,
      max: 1,
      divisions: 16,
      display: (v) => '${(v * 100).round()}%',
      onChanged: (v) => _update((s) => s.copyWith(textSize: v)),
    ),
    Hint(
      context.tr(
        'Share of the panel height the text uses, all lines together. '
            'Several lines share the height, so each gets smaller.',
        '패널 높이 중 글자가 차지하는 비율입니다 (모든 줄 합계). 여러 줄이면 '
            '높이를 나눠 쓰므로 줄마다 작아집니다.',
      ),
    ),
  ];

  List<Widget> _clockFields(Scene s) => [
    FieldLabel(context.tr('Format', '표시 형식')),
    ChoiceRow<ClockFormat>(
      options: const [
        (ClockFormat.hm, Icons.schedule, '14:05'),
        (ClockFormat.hms, Icons.timer_outlined, '14:05:09'),
        (ClockFormat.hm12, Icons.wb_sunny_outlined, '오후 2:05'),
        (ClockFormat.dateHm, Icons.calendar_today, '10/24 14:05'),
      ],
      selected: s.clockFormat,
      onSelected: (v) => _update((s) => s.copyWith(clockFormat: v)),
    ),
    Hint(
      context.tr(
        'Shows this device\'s current time, updated as it changes. With flip dots only the discs of changed digits flip.',
        '이 기기의 현재 시간을 보여 줍니다. 시간이 바뀔 때마다 갱신되고, 플립 도트에서는 바뀐 숫자의 원판만 뒤집힙니다.',
      ),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Bold', '굵은 글씨')),
      value: s.bold,
      onChanged: (v) => _update((s) => s.copyWith(bold: v)),
    ),
  ];

  List<Widget> _imageFields(Scene s) {
    final image = s.image;
    return [
      Row(
        children: [
          Container(
            width: 120,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.image_not_supported_outlined)
                : Image.memory(
                    image,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                image == null
                    ? context.tr('Choose image', '이미지 선택')
                    : context.tr('Change image', '이미지 변경'),
              ),
              onPressed: _importing ? null : _pickImage,
            ),
          ),
        ],
      ),
      Hint(
        context.tr(
          'PNG · JPG · GIF · WebP, turned into dots to fit the panel height.',
          'PNG · JPG · GIF · WebP. 패널 높이에 맞춰 도트로 변환됩니다.',
        ),
      ),
      const SizedBox(height: 12),
      FieldLabel(context.tr('Color', '색상')),
      ChoiceRow<ImageColorMode>(
        options: [
          (
            ImageColorMode.original,
            Icons.palette_outlined,
            context.tr('Original', '원본 색'),
          ),
          (ImageColorMode.mono, Icons.circle, context.tr('Single color', '단색')),
        ],
        selected: s.imageColorMode,
        onSelected: (v) => _update((s) => s.copyWith(imageColorMode: v)),
      ),
      LabeledSlider(
        label: context.tr('Threshold (dark parts off)', '밝기 기준 (어두운 부분 끄기)'),
        value: s.imageThreshold,
        min: 0,
        max: 0.9,
        display: (v) => '${(v * 100).round()}%',
        onChanged: (v) => _update((s) => s.copyWith(imageThreshold: v)),
      ),
    ];
  }

  List<Widget> _colorFields(Scene s) => [
    SectionHeader(context.tr('Dot color', '점 색상')),
    ColorSwatches(
      colors: dotColors,
      selected: s.rainbow ? null : s.dotColor,
      onSelected: (c) =>
          _update((s) => s.copyWith(dotColor: c, rainbow: false)),
    ),
    LabeledSlider(
      label: context.tr('Hue', '색조'),
      value: HSVColor.fromColor(s.dotColor).hue,
      min: 0,
      max: 359,
      display: (v) => '${v.round()}°',
      onChanged: (v) => _update(
        (s) => s.copyWith(
          dotColor: HSVColor.fromAHSV(1, v, 0.85, 1).toColor(),
          rainbow: false,
        ),
      ),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Rainbow', '무지개 효과')),
      value: s.rainbow,
      onChanged: (v) => _update((s) => s.copyWith(rainbow: v)),
    ),
  ];

  List<Widget> _motionFields(Scene s) => [
    SectionHeader(context.tr('Motion', '움직임')),
    ChoiceRow<MarqueeDirection>(
      options: [
        (MarqueeDirection.left, Icons.arrow_back, context.tr('Left', '왼쪽으로')),
        (MarqueeDirection.none, Icons.pause, context.tr('Still', '고정')),
        (
          MarqueeDirection.right,
          Icons.arrow_forward,
          context.tr('Right', '오른쪽으로'),
        ),
      ],
      selected: s.direction,
      onSelected: (v) => _update((s) => s.copyWith(direction: v)),
    ),
    LabeledSlider(
      label: context.tr('Speed', '속도'),
      value: s.speed,
      min: 0,
      max: 120,
      display: (v) => v.round() == 0
          ? context.tr('0 (stopped)', '0 (멈춤)')
          : context.tr('${v.round()} dots/s', '${v.round()} 칸/초'),
      onChanged: s.direction == MarqueeDirection.none
          ? null
          : (v) => _update((s) => s.copyWith(speed: v.roundToDouble())),
    ),
    if (s.speed <= 0 && s.direction != MarqueeDirection.none)
      Hint(
        context.tr(
          'Speed 0: the text stays still in the middle.',
          '속도 0: 글자가 흐르지 않고 가운데에 멈춰 있습니다.',
        ),
      ),
    if (s.direction == MarqueeDirection.none)
      Hint(
        context.tr(
          'A still scene ignores speed and stays in the middle. Text wider than the sign is shrunk to fit.',
          '고정 장면은 속도를 쓰지 않고 가운데에 멈춰 있습니다. 화면보다 긴 글자는 화면에 맞게 줄어듭니다.',
        ),
      ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Blink', '깜빡임')),
      value: s.blink,
      onChanged: (v) => _update((s) => s.copyWith(blink: v)),
    ),
    LabeledSlider(
      label: context.tr('Blink rate', '깜빡임 속도'),
      value: s.blinkHz,
      min: 0.5,
      max: 8,
      display: (v) => '${v.toStringAsFixed(1)} Hz',
      onChanged: s.blink ? (v) => _update((s) => s.copyWith(blinkHz: v)) : null,
    ),
    if (s.direction == MarqueeDirection.none || s.speed <= 0) ...[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Flip all', '전체 플립')),
        subtitle: Text(
          context.tr(
            'Every dot flips over and back in a wave, now and then',
            '일정 간격으로 모든 점이 물결처럼 뒤집혔다가 돌아옵니다',
          ),
        ),
        value: s.flipAll,
        onChanged: (v) => _update((s) => s.copyWith(flipAll: v)),
      ),
      LabeledSlider(
        label: context.tr('Flip every', '플립 간격'),
        value: s.flipAllSeconds,
        min: 3,
        max: 30,
        divisions: 27,
        display: (v) => context.tr('${v.round()} s', '${v.round()}초'),
        onChanged: s.flipAll
            ? (v) =>
                  _update((s) => s.copyWith(flipAllSeconds: v.roundToDouble()))
            : null,
      ),
    ],
  ];

  List<Widget> _timingFields(Scene s, Show show) {
    final scrolls = s.direction != MarqueeDirection.none;
    return [
      SectionHeader(context.tr('Scene change', '장면 전환')),
      FieldLabel(context.tr('Move on to the next scene', '다음 장면으로 넘어가는 시점')),
      ChoiceRow<DurationMode>(
        options: [
          (
            DurationMode.passes,
            Icons.repeat,
            context.tr('After scrolling', '스크롤 완료 후'),
          ),
          (
            DurationMode.seconds,
            Icons.timer_outlined,
            context.tr('After a time', '시간 지정'),
          ),
        ],
        selected: s.durationMode,
        onSelected: (v) => _update((s) => s.copyWith(durationMode: v)),
      ),
      if (s.usesPasses)
        LabeledSlider(
          label: context.tr('Scroll passes', '스크롤 횟수'),
          value: s.passes.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          display: (v) => context.tr('${v.round()}×', '${v.round()}회'),
          onChanged: (v) => _update((s) => s.copyWith(passes: v.round())),
        )
      else ...[
        LabeledSlider(
          label: context.tr('Show for', '표시 시간'),
          value: s.durationSeconds,
          min: 1,
          max: 60,
          divisions: 59,
          display: (v) => context.tr('${v.round()} s', '${v.round()}초'),
          onChanged: (v) =>
              _update((s) => s.copyWith(durationSeconds: v.roundToDouble())),
        ),
        if (s.durationMode == DurationMode.passes && !scrolls)
          Hint(
            context.tr(
              'A still scene uses the time instead of scroll passes.',
              '고정된 장면은 스크롤 횟수 대신 표시 시간을 사용합니다.',
            ),
          ),
      ],
      const SizedBox(height: 8),
      FieldLabel(context.tr('How this scene appears', '이 장면이 나타나는 효과')),
      ChoiceRow<SceneTransition>(
        options: [
          (SceneTransition.cut, Icons.flash_on, context.tr('Cut', '바로')),
          (SceneTransition.fade, Icons.gradient, context.tr('Fade', '페이드')),
          (
            SceneTransition.slideLeft,
            Icons.keyboard_double_arrow_left,
            context.tr('Slide', '옆으로 밀기'),
          ),
          (
            SceneTransition.slideUp,
            Icons.keyboard_double_arrow_up,
            context.tr('Slide up', '위로 밀기'),
          ),
          (SceneTransition.flip, Icons.flip, context.tr('Flip', '플립')),
        ],
        selected: s.transition,
        onSelected: (v) => _update((s) => s.copyWith(transition: v)),
      ),
      if (show.scenes.length == 1)
        Hint(
          context.tr(
            'With only one scene it simply repeats. Add scenes with the buttons below the preview.',
            '장면이 하나뿐이면 전환 없이 계속 반복됩니다. 아래 + 버튼으로 장면을 추가하세요.',
          ),
        ),
    ];
  }
}

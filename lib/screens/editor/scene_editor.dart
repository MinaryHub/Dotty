import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  try {
    return await pickImage();
  } on UnsupportedImageException {
    messenger.showSnackBar(
      const SnackBar(content: Text('이 이미지 형식은 열 수 없습니다.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('이미지를 불러오지 못했습니다: $e')));
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
            const SectionHeader('내용'),
            SegmentedButton<SceneKind>(
              segments: const [
                ButtonSegment(
                  value: SceneKind.text,
                  icon: Icon(Icons.text_fields),
                  label: Text('문구'),
                ),
                ButtonSegment(
                  value: SceneKind.image,
                  icon: Icon(Icons.image_outlined),
                  label: Text('이미지'),
                ),
              ],
              selected: {s.kind},
              onSelectionChanged: (v) =>
                  _update((s) => s.copyWith(kind: v.first)),
            ),
            const SizedBox(height: 12),
            if (s.kind == SceneKind.text) ..._textFields(s),
            if (s.kind == SceneKind.image) ..._imageFields(s),
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
        hintText: '표시할 문구를 입력하세요',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          tooltip: '지우기',
          onPressed: () => _setText(''),
        ),
      ),
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
      title: const Text('굵은 글씨'),
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
              label: Text(image == null ? '이미지 선택' : '이미지 변경'),
              onPressed: _importing ? null : _pickImage,
            ),
          ),
        ],
      ),
      const Hint('PNG · JPG · GIF · WebP. 패널 높이에 맞춰 도트로 변환됩니다.'),
      const SizedBox(height: 12),
      const FieldLabel('색상'),
      ChoiceRow<ImageColorMode>(
        options: const [
          (ImageColorMode.original, Icons.palette_outlined, '원본 색'),
          (ImageColorMode.mono, Icons.circle, '단색'),
        ],
        selected: s.imageColorMode,
        onSelected: (v) => _update((s) => s.copyWith(imageColorMode: v)),
      ),
      LabeledSlider(
        label: '밝기 기준 (어두운 부분 끄기)',
        value: s.imageThreshold,
        min: 0,
        max: 0.9,
        display: (v) => '${(v * 100).round()}%',
        onChanged: (v) => _update((s) => s.copyWith(imageThreshold: v)),
      ),
    ];
  }

  List<Widget> _colorFields(Scene s) => [
    const SectionHeader('점 색상'),
    ColorSwatches(
      colors: dotColors,
      selected: s.rainbow ? null : s.dotColor,
      onSelected: (c) =>
          _update((s) => s.copyWith(dotColor: c, rainbow: false)),
    ),
    LabeledSlider(
      label: '색조',
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
      title: const Text('무지개 효과'),
      value: s.rainbow,
      onChanged: (v) => _update((s) => s.copyWith(rainbow: v)),
    ),
  ];

  List<Widget> _motionFields(Scene s) => [
    const SectionHeader('움직임'),
    ChoiceRow<MarqueeDirection>(
      options: const [
        (MarqueeDirection.left, Icons.arrow_back, '왼쪽으로'),
        (MarqueeDirection.none, Icons.pause, '고정'),
        (MarqueeDirection.right, Icons.arrow_forward, '오른쪽으로'),
      ],
      selected: s.direction,
      onSelected: (v) => _update((s) => s.copyWith(direction: v)),
    ),
    LabeledSlider(
      label: '속도',
      value: s.speed,
      min: 1,
      max: 120,
      display: (v) => '${v.round()} 칸/초',
      onChanged: s.direction == MarqueeDirection.none
          ? null
          : (v) => _update((s) => s.copyWith(speed: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('깜빡임'),
      value: s.blink,
      onChanged: (v) => _update((s) => s.copyWith(blink: v)),
    ),
    LabeledSlider(
      label: '깜빡임 속도',
      value: s.blinkHz,
      min: 0.5,
      max: 8,
      display: (v) => '${v.toStringAsFixed(1)} Hz',
      onChanged: s.blink ? (v) => _update((s) => s.copyWith(blinkHz: v)) : null,
    ),
  ];

  List<Widget> _timingFields(Scene s, Show show) {
    final scrolls = s.direction != MarqueeDirection.none;
    return [
      const SectionHeader('장면 전환'),
      const FieldLabel('다음 장면으로 넘어가는 시점'),
      ChoiceRow<DurationMode>(
        options: const [
          (DurationMode.passes, Icons.repeat, '스크롤 완료 후'),
          (DurationMode.seconds, Icons.timer_outlined, '시간 지정'),
        ],
        selected: s.durationMode,
        onSelected: (v) => _update((s) => s.copyWith(durationMode: v)),
      ),
      if (s.usesPasses)
        LabeledSlider(
          label: '스크롤 횟수',
          value: s.passes.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          display: (v) => '${v.round()}회',
          onChanged: (v) => _update((s) => s.copyWith(passes: v.round())),
        )
      else ...[
        LabeledSlider(
          label: '표시 시간',
          value: s.durationSeconds,
          min: 1,
          max: 60,
          divisions: 59,
          display: (v) => '${v.round()}초',
          onChanged: (v) =>
              _update((s) => s.copyWith(durationSeconds: v.roundToDouble())),
        ),
        if (s.durationMode == DurationMode.passes && !scrolls)
          const Hint('고정된 장면은 스크롤 횟수 대신 표시 시간을 사용합니다.'),
      ],
      const SizedBox(height: 8),
      const FieldLabel('이 장면이 나타나는 효과'),
      ChoiceRow<SceneTransition>(
        options: const [
          (SceneTransition.cut, Icons.flash_on, '바로'),
          (SceneTransition.fade, Icons.gradient, '페이드'),
          (
            SceneTransition.slideLeft,
            Icons.keyboard_double_arrow_left,
            '옆으로 밀기',
          ),
          (SceneTransition.slideUp, Icons.keyboard_double_arrow_up, '위로 밀기'),
          (SceneTransition.flip, Icons.flip, '플립'),
        ],
        selected: s.transition,
        onSelected: (v) => _update((s) => s.copyWith(transition: v)),
      ),
      if (show.scenes.length == 1)
        const Hint('장면이 하나뿐이면 전환 없이 계속 반복됩니다. 아래 + 버튼으로 장면을 추가하세요.'),
    ];
  }
}

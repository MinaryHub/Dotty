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

  /// Whether the hue slider for a color of one's own is open.
  bool _customColor = false;

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
        final look = _lookFields(s);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          children: [
            SettingsGroup(
              id: 'content',
              icon: Icons.edit_outlined,
              title: context.tr('Content', '내용'),
              summary: _contentSummary(s),
              initiallyOpen: true,
              children: [
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
              ],
            ),
            if (look.isNotEmpty)
              SettingsGroup(
                id: 'look',
                icon: Icons.palette_outlined,
                title: context.tr('Look', '모양'),
                summary: _lookSummary(s),
                trailing: s.usesDotColor
                    ? ColorDot(color: s.dotColor, rainbow: s.rainbow)
                    : null,
                children: look,
              ),
            SettingsGroup(
              id: 'motion',
              icon: Icons.swap_horiz,
              title: context.tr('Motion', '움직임'),
              summary: _motionSummary(s),
              children: _motionFields(s),
            ),
            SettingsGroup(
              id: 'effects',
              icon: Icons.auto_awesome_outlined,
              title: context.tr('Effects', '효과'),
              summary: _effectsSummary(s),
              children: _effectFields(s),
            ),
            SettingsGroup(
              id: 'change',
              icon: Icons.skip_next_outlined,
              title: context.tr('Scene change', '장면 전환'),
              summary: _changeSummary(s),
              children: _timingFields(s, show),
            ),
          ],
        );
      },
    );
  }

  String _seconds(double v) => context.tr('${v.round()} s', '${v.round()}초');

  String _transitionName(SceneTransition t) => switch (t) {
    SceneTransition.cut => context.tr('Cut', '바로'),
    SceneTransition.fade => context.tr('Fade', '페이드'),
    SceneTransition.slideLeft => context.tr('Slide', '옆으로 밀기'),
    SceneTransition.slideUp => context.tr('Slide up', '위로 밀기'),
    SceneTransition.slideDiagLeft => context.tr('Diagonal ←', '사선 ←'),
    SceneTransition.slideDiagRight => context.tr('Diagonal →', '사선 →'),
    SceneTransition.flip => context.tr('Flip', '플립'),
  };

  String _speedName(double v) {
    final dots = v.round();
    final pace = dots < 12
        ? context.tr('slow', '느리게')
        : dots < 40
        ? context.tr('normal', '보통')
        : context.tr('fast', '빠르게');
    return context.tr('$dots dots/s · $pace', '$dots칸/초 · $pace');
  }

  String _contentSummary(Scene s) => switch (s.kind) {
    SceneKind.text =>
      s.text.trim().isEmpty
          ? context.tr('(no text)', '(문구 없음)')
          : s.text.trim().replaceAll('\n', ' / '),
    SceneKind.image =>
      s.image == null
          ? context.tr('Image (none chosen)', '이미지 (선택 안 함)')
          : context.tr('Image', '이미지'),
    SceneKind.clock => context.tr('Clock', '시계'),
  };

  String _lookSummary(Scene s) => [
    if (s.rainbow) context.tr('Rainbow', '무지개'),
    if (s.kind != SceneKind.image)
      s.bold ? context.tr('Bold', '굵게') : context.tr('Regular', '보통 굵기'),
    if (s.kind == SceneKind.text)
      context.tr(
        'size ${(s.textSize * 100).round()}%',
        '크기 ${(s.textSize * 100).round()}%',
      ),
  ].join(' · ');

  String _motionSummary(Scene s) => s.isStill
      ? context.tr('Still, centered', '고정 (가운데)')
      : '${s.direction == MarqueeDirection.left ? context.tr('Left', '왼쪽으로') : context.tr('Right', '오른쪽으로')} · ${_speedName(s.speed)}';

  String _effectsSummary(Scene s) {
    final on = [
      if (s.blink)
        context.tr(
          'Blink ${s.blinkHz.toStringAsFixed(1)} Hz',
          '깜빡임 ${s.blinkHz.toStringAsFixed(1)} Hz',
        ),
      if (s.isStill && s.flipAll)
        context.tr(
          'Flip all every ${_seconds(s.flipAllSeconds)}',
          '전체 플립 ${_seconds(s.flipAllSeconds)}마다',
        ),
      if (s.isStill && s.replay)
        context.tr(
          'Replay after ${_seconds(s.replaySeconds)}',
          '다시 나타나기 ${_seconds(s.replaySeconds)}',
        ),
    ];
    return on.isEmpty ? context.tr('None', '없음') : on.join(' · ');
  }

  String _changeSummary(Scene s) {
    final when = s.usesPasses
        ? context.tr(
            'after ${s.passes} scroll${s.passes == 1 ? '' : 's'}',
            '${s.passes}번 흐른 뒤',
          )
        : context.tr(
            'after ${_seconds(s.durationSeconds)}',
            '${_seconds(s.durationSeconds)} 뒤',
          );
    return '${_transitionName(s.transition)} · $when';
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
          'PNG · JPG · GIF · WebP, turned into dots to fit the sign height.',
          'PNG · JPG · GIF · WebP. 전광판 높이에 맞춰 도트로 변환됩니다.',
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
        label: context.tr('Hide dark parts', '어두운 부분 끄기'),
        value: s.imageThreshold,
        min: 0,
        max: 0.9,
        display: (v) => '${(v * 100).round()}%',
        onChanged: (v) => _update((s) => s.copyWith(imageThreshold: v)),
      ),
    ];
  }

  /// Color, weight and size of what is drawn; empty for an image in its
  /// own colors.
  List<Widget> _lookFields(Scene s) => [
    if (s.usesDotColor) ...[
      FieldLabel(context.tr('Dot color', '점 색상')),
      _ColorPicker(
        scene: s,
        customOpen: _customColor,
        onColor: (c) => _update((s) => s.copyWith(dotColor: c, rainbow: false)),
        onRainbow: () => _update((s) => s.copyWith(rainbow: true)),
        onCustom: () => setState(() => _customColor = true),
      ),
    ],
    if (s.kind != SceneKind.image)
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Bold', '굵은 글씨')),
        value: s.bold,
        onChanged: (v) => _update((s) => s.copyWith(bold: v)),
      ),
    if (s.kind == SceneKind.text) ...[
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
          'Share of the sign\'s height the text uses, all lines together. '
              'Several lines share the height, so each gets smaller.',
          '전광판 높이 중 글자가 차지하는 비율입니다 (모든 줄 합계). 여러 줄이면 '
              '높이를 나눠 쓰므로 줄마다 작아집니다.',
        ),
      ),
    ],
  ];

  List<Widget> _motionFields(Scene s) => [
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
    if (s.direction != MarqueeDirection.none)
      LabeledSlider(
        label: context.tr('Speed', '속도'),
        value: s.speed,
        min: 0,
        max: 120,
        display: (v) => v.round() == 0
            ? context.tr('0 (stopped)', '0 (멈춤)')
            : _speedName(v),
        onChanged: (v) => _update((s) => s.copyWith(speed: v.roundToDouble())),
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
  ];

  List<Widget> _effectFields(Scene s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Blink', '깜빡임')),
      value: s.blink,
      onChanged: (v) => _update((s) => s.copyWith(blink: v)),
    ),
    if (s.blink)
      LabeledSlider(
        label: context.tr('Blink rate', '깜빡임 속도'),
        value: s.blinkHz,
        min: 0.5,
        max: 8,
        display: (v) => '${v.toStringAsFixed(1)} Hz',
        onChanged: (v) => _update((s) => s.copyWith(blinkHz: v)),
      ),
    if (!s.isStill)
      Hint(
        context.tr(
          'Flip all and Replay entrance are for still scenes (Motion: Still).',
          '전체 플립과 다시 나타나기는 고정 장면에서 쓸 수 있습니다 (움직임: 고정).',
        ),
      ),
    if (s.isStill) ...[
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
      if (s.flipAll) ...[
        FieldLabel(context.tr('Flip period', '돌리는 주기')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final seconds in const [1.0, 2.0, 3.0, 5.0, 10.0, 30.0, 60.0])
              ChoiceChip(
                label: Text(
                  context.tr('${seconds.round()} s', '${seconds.round()}초'),
                ),
                selected: s.flipAllSeconds == seconds,
                onSelected: (_) =>
                    _update((s) => s.copyWith(flipAllSeconds: seconds)),
              ),
          ],
        ),
        LabeledSlider(
          label: context.tr('Every', '주기'),
          value: s.flipAllSeconds,
          min: Scene.minFlipAllSeconds,
          max: Scene.maxFlipAllSeconds,
          divisions: (Scene.maxFlipAllSeconds - Scene.minFlipAllSeconds)
              .round(),
          display: (v) => context.tr('${v.round()} s', '${v.round()}초'),
          onChanged: (v) =>
              _update((s) => s.copyWith(flipAllSeconds: v.roundToDouble())),
        ),
        Hint(
          context.tr(
            'The sign flips over every ${s.flipAllSeconds.round()} s and '
                'turns back ${s.flipAllHold.toStringAsFixed(1)} s later.',
            '${s.flipAllSeconds.round()}초마다 전체가 뒤집히고 '
                '${s.flipAllHold.toStringAsFixed(1)}초 뒤 돌아옵니다.',
          ),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Replay entrance', '다시 나타나기')),
        subtitle: Text(
          context.tr(
            'After a set time, the same screen comes in again with this scene\'s effect',
            '정해진 시간이 지나면 같은 화면이 이 장면의 효과로 다시 지나가며 나타납니다',
          ),
        ),
        value: s.replay,
        onChanged: (v) => _update((s) => s.copyWith(replay: v)),
      ),
      if (s.replay) ...[
        FieldLabel(context.tr('Replay after', '다시 나타나는 시간')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final seconds in const [5.0, 10.0, 30.0, 60.0, 120.0, 300.0])
              ChoiceChip(
                label: Text(
                  context.tr('${seconds.round()} s', '${seconds.round()}초'),
                ),
                selected: s.replaySeconds == seconds,
                onSelected: (_) =>
                    _update((s) => s.copyWith(replaySeconds: seconds)),
              ),
          ],
        ),
        LabeledSlider(
          label: context.tr('After', '시간'),
          value: s.replaySeconds,
          min: Scene.minReplaySeconds,
          max: Scene.maxReplaySeconds,
          divisions: (Scene.maxReplaySeconds - Scene.minReplaySeconds).round(),
          display: (v) => context.tr('${v.round()} s', '${v.round()}초'),
          onChanged: (v) =>
              _update((s) => s.copyWith(replaySeconds: v.roundToDouble())),
        ),
        Hint(
          context.tr(
            'Counted from when the scene has settled. Pick the effect under "How this scene appears" below (Cut shows nothing on LEDs). If the scene leaves sooner than this, it never replays.',
            '장면이 자리 잡은 뒤부터 셉니다. 아래 "이 장면이 나타나는 효과"에서 고른 효과로 나타납니다 (LED에서 "바로"는 눈에 띄지 않습니다). 장면이 이 시간보다 먼저 넘어가면 다시 나타나지 않습니다.',
          ),
        ),
      ],
    ],
  ];

  List<Widget> _timingFields(Scene s, Show show) {
    final scrolls = s.direction != MarqueeDirection.none;
    return [
      FieldLabel(context.tr('When to move on', '다음 장면으로 넘어가는 때')),
      ChoiceRow<DurationMode>(
        options: [
          (
            DurationMode.passes,
            Icons.repeat,
            context.tr('After it scrolls by', '다 흐르고 나서'),
          ),
          (
            DurationMode.seconds,
            Icons.timer_outlined,
            context.tr('After a set time', '정한 시간 뒤'),
          ),
        ],
        selected: s.durationMode,
        onSelected: (v) => _update((s) => s.copyWith(durationMode: v)),
      ),
      if (s.usesPasses)
        LabeledSlider(
          label: context.tr('Times to scroll by', '흐르는 횟수'),
          value: s.passes.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          display: (v) => context.tr(
            '${v.round()} time${v.round() == 1 ? '' : 's'}',
            '${v.round()}번',
          ),
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
              'A still scene doesn\'t scroll, so it uses the time instead.',
              '고정 장면은 흐르지 않으므로 표시 시간을 사용합니다.',
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
          (
            SceneTransition.slideDiagLeft,
            Icons.north_west,
            context.tr('Diagonal ←', '사선 ←'),
          ),
          (
            SceneTransition.slideDiagRight,
            Icons.north_east,
            context.tr('Diagonal →', '사선 →'),
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

/// Preset dot colors, a rainbow, and a color of one's own (a hue slider).
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.scene,
    required this.customOpen,
    required this.onColor,
    required this.onRainbow,
    required this.onCustom,
  });

  final Scene scene;
  final bool customOpen;
  final ValueChanged<Color> onColor;
  final VoidCallback onRainbow;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final s = scene;
    final preset = dotColors.contains(s.dotColor);
    final custom = !s.rainbow && (!preset || customOpen);
    final outline = Theme.of(context).colorScheme.primary;
    Widget circle({
      required bool selected,
      required VoidCallback onTap,
      required String tooltip,
      Color? color,
      Gradient? gradient,
      Widget? child,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              gradient: gradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? outline : Colors.white24,
                width: selected ? 3 : 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in dotColors)
              circle(
                selected: !s.rainbow && !custom && c == s.dotColor,
                onTap: () => onColor(c),
                tooltip:
                    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                color: c,
              ),
            circle(
              selected: s.rainbow,
              onTap: onRainbow,
              tooltip: context.tr('Rainbow', '무지개'),
              gradient: rainbowGradient,
            ),
            circle(
              selected: custom,
              onTap: onCustom,
              tooltip: context.tr('Your own color', '직접 고르기'),
              color: custom ? s.dotColor : null,
              child: custom ? null : const Icon(Icons.tune, size: 18),
            ),
          ],
        ),
        if (custom)
          LabeledSlider(
            label: context.tr('Hue', '색조'),
            value: HSVColor.fromColor(s.dotColor).hue,
            min: 0,
            max: 359,
            display: (v) => '${v.round()}°',
            onChanged: (v) =>
                onColor(HSVColor.fromAHSV(1, v, 0.85, 1).toColor()),
          ),
      ],
    );
  }
}

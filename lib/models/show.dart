import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum MarqueeDirection { left, right, none }

enum DotShape { circle, square }

enum SceneKind { text, image, clock }

/// How a clock scene shows the current time.
enum ClockFormat {
  /// 14:05
  hm,

  /// 14:05:09
  hms,

  /// 오후 2:05
  hm12,

  /// 10/24 14:05
  dateHm,
}

/// [time] as a clock scene shows it in [format].
String formatClock(DateTime time, ClockFormat format) {
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(time.hour)}:${two(time.minute)}';
  return switch (format) {
    ClockFormat.hm => hm,
    ClockFormat.hms => '$hm:${two(time.second)}',
    ClockFormat.hm12 =>
      '${time.hour < 12 ? '오전' : '오후'} '
          '${time.hour % 12 == 0 ? 12 : time.hour % 12}:${two(time.minute)}',
    ClockFormat.dateHm => '${time.month}/${time.day} $hm',
  };
}

/// How image pixels become dots: keep their colors, or light them in the
/// scene's dot color.
enum ImageColorMode { original, mono }

/// When a scene hands over to the next one.
enum DurationMode { seconds, passes }

/// How a scene enters the display.
enum SceneTransition { cut, fade, slideLeft, slideUp, diagonal, flip }

/// Settings of the physical sign, shared by every scene.
@immutable
class PanelSettings {
  const PanelSettings({
    this.rows = 24,
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.offDotOpacity = 0.12,
    this.shape = DotShape.circle,
    this.dotFill = 0.82,
    this.glow = true,
    this.transitionMs = 600,
    this.flipDots = false,
    this.flipSound = true,
    this.soundVolume = 0.6,
    this.aspectRatio = 0,
    this.flipSeconds = 0.5,
  });

  /// Vertical resolution in dots.
  final int rows;
  final Color backgroundColor;

  /// Opacity of unlit dots (0 hides them).
  final double offDotOpacity;
  final DotShape shape;

  /// Dot diameter relative to the dot pitch (0..1).
  final double dotFill;
  final bool glow;
  final double transitionMs;

  /// Mechanical flip-dot board instead of LEDs: each disc turns over when
  /// its state changes, with the matching click.
  final bool flipDots;
  final bool flipSound;

  /// 0..1.
  final double soundVolume;

  /// Width / height of the sign; 0 means the shape of this device's screen,
  /// so the preview looks exactly like fullscreen.
  final double aspectRatio;

  /// How long one flip-dot disc takes to turn over and settle.
  final double flipSeconds;

  static const minRows = 8;
  static const maxRows = 64;

  PanelSettings copyWith({
    int? rows,
    Color? backgroundColor,
    double? offDotOpacity,
    DotShape? shape,
    double? dotFill,
    bool? glow,
    double? transitionMs,
    bool? flipDots,
    bool? flipSound,
    double? soundVolume,
    double? aspectRatio,
    double? flipSeconds,
  }) {
    return PanelSettings(
      rows: rows ?? this.rows,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      offDotOpacity: offDotOpacity ?? this.offDotOpacity,
      shape: shape ?? this.shape,
      dotFill: dotFill ?? this.dotFill,
      glow: glow ?? this.glow,
      transitionMs: transitionMs ?? this.transitionMs,
      flipDots: flipDots ?? this.flipDots,
      flipSound: flipSound ?? this.flipSound,
      soundVolume: soundVolume ?? this.soundVolume,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flipSeconds: flipSeconds ?? this.flipSeconds,
    );
  }

  Map<String, Object> toJson() => {
    'rows': rows,
    'backgroundColor': backgroundColor.toARGB32(),
    'offDotOpacity': offDotOpacity,
    'shape': shape.name,
    'dotFill': dotFill,
    'glow': glow,
    'transitionMs': transitionMs,
    'flipDots': flipDots,
    'flipSound': flipSound,
    'soundVolume': soundVolume,
    'aspectRatio': aspectRatio,
    'flipSeconds': flipSeconds,
  };

  factory PanelSettings.fromJson(Map<String, dynamic> json) {
    const d = PanelSettings();
    final r = _Reader(json);
    return PanelSettings(
      rows: r.integer('rows', d.rows).clamp(minRows, maxRows),
      backgroundColor: r.color('backgroundColor', d.backgroundColor),
      offDotOpacity: r.number('offDotOpacity', d.offDotOpacity).clamp(0, 1),
      shape: r.enumValue(DotShape.values, 'shape', d.shape),
      dotFill: r.number('dotFill', d.dotFill).clamp(0.2, 1),
      glow: r.boolean('glow', d.glow),
      transitionMs: r.number('transitionMs', d.transitionMs).clamp(100, 3000),
      flipDots: r.boolean('flipDots', d.flipDots),
      flipSound: r.boolean('flipSound', d.flipSound),
      soundVolume: r.number('soundVolume', d.soundVolume).clamp(0, 1),
      aspectRatio: r.number('aspectRatio', d.aspectRatio).clamp(0, 8),
      flipSeconds: _migrateFlipSeconds(r.number('flipSeconds', d.flipSeconds))
          .clamp(0.08, 1.5),
    );
  }
}

/// 0.19 s was the default before discs were drawn turning in 3D; it read as
/// a blink. Saves still holding it get the current default.
double _migrateFlipSeconds(double v) =>
    (v - 0.19).abs() < 1e-9 ? const PanelSettings().flipSeconds : v;

/// One step of the show: what is displayed, how it looks and moves, and how
/// long it stays.
@immutable
class Scene {
  const Scene({
    required this.id,
    this.kind = SceneKind.text,
    this.text = 'HELLO DOTTY',
    this.bold = true,
    this.image,
    this.imageColorMode = ImageColorMode.original,
    this.imageThreshold = 0.15,
    this.dotColor = const Color(0xFFFF3B30),
    this.rainbow = false,
    this.direction = MarqueeDirection.left,
    this.speed = 20,
    this.blink = false,
    this.blinkHz = 2,
    this.durationMode = DurationMode.passes,
    this.durationSeconds = 5,
    this.passes = 1,
    this.transition = SceneTransition.fade,
    this.clockFormat = ClockFormat.hm,
    this.textSize = 1,
    this.flipAll = false,
    this.flipAllSeconds = 6,
  });

  final String id;
  final SceneKind kind;
  final String text;
  final bool bold;

  /// Encoded (PNG) image, already downscaled at import.
  final Uint8List? image;
  final ImageColorMode imageColorMode;

  /// Pixels darker than this luminance (0..1) stay unlit.
  final double imageThreshold;
  final Color dotColor;
  final bool rainbow;
  final MarqueeDirection direction;

  /// Scroll speed in columns per second.
  final double speed;
  final bool blink;
  final double blinkHz;
  final DurationMode durationMode;
  final double durationSeconds;

  /// Full scroll passes before moving on ([DurationMode.passes]).
  final int passes;
  final SceneTransition transition;

  /// Time format of a [SceneKind.clock] scene.
  final ClockFormat clockFormat;

  /// Height of text, as a fraction of the panel (shared by all its lines).
  final double textSize;

  /// A still scene flips every dot over and back every [flipAllSeconds],
  /// in a wave across the sign, to catch the eye.
  final bool flipAll;
  final double flipAllSeconds;

  /// Shortest and longest [flipAllSeconds].
  static const minFlipAllSeconds = 1.0, maxFlipAllSeconds = 60.0;

  /// How long the [flipAll] wave takes to cross the sign, and how long the
  /// sign stays flipped; both shrink for short periods so the sign is back
  /// before the next flip.
  double get flipAllSweep => math.min(0.6, flipAllSeconds * 0.3);
  double get flipAllHold => math.min(1.2, flipAllSeconds * 0.35);

  /// Whether column [c] of [cols] shows flipped (inverted) [seconds] after
  /// this scene came up, for a still scene with [flipAll] on.
  bool flippedAt(double seconds, int c, int cols) {
    if (!flipAll || seconds < flipAllSeconds) return false;
    final phase = seconds % flipAllSeconds;
    final start = c / math.max(1, cols - 1) * flipAllSweep;
    return phase >= start && phase < start + flipAllHold;
  }

  /// Scenes that do not scroll cannot count passes and fall back to seconds.
  bool get usesPasses =>
      durationMode == DurationMode.passes &&
      direction != MarqueeDirection.none &&
      speed > 0;

  /// Whether this scene lights dots in its own [dotColor] (vs image colors).
  bool get usesDotColor =>
      kind != SceneKind.image || imageColorMode == ImageColorMode.mono;

  Scene copyWith({
    String? id,
    SceneKind? kind,
    String? text,
    bool? bold,
    Uint8List? image,
    ImageColorMode? imageColorMode,
    double? imageThreshold,
    Color? dotColor,
    bool? rainbow,
    MarqueeDirection? direction,
    double? speed,
    bool? blink,
    double? blinkHz,
    DurationMode? durationMode,
    double? durationSeconds,
    int? passes,
    SceneTransition? transition,
    ClockFormat? clockFormat,
    double? textSize,
    bool? flipAll,
    double? flipAllSeconds,
  }) {
    return Scene(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      bold: bold ?? this.bold,
      image: image ?? this.image,
      imageColorMode: imageColorMode ?? this.imageColorMode,
      imageThreshold: imageThreshold ?? this.imageThreshold,
      dotColor: dotColor ?? this.dotColor,
      rainbow: rainbow ?? this.rainbow,
      direction: direction ?? this.direction,
      speed: speed ?? this.speed,
      blink: blink ?? this.blink,
      blinkHz: blinkHz ?? this.blinkHz,
      durationMode: durationMode ?? this.durationMode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      passes: passes ?? this.passes,
      transition: transition ?? this.transition,
      clockFormat: clockFormat ?? this.clockFormat,
      textSize: textSize ?? this.textSize,
      flipAll: flipAll ?? this.flipAll,
      flipAllSeconds: flipAllSeconds ?? this.flipAllSeconds,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'text': text,
    'bold': bold,
    'image': image == null ? null : base64Encode(image!),
    'imageColorMode': imageColorMode.name,
    'imageThreshold': imageThreshold,
    'dotColor': dotColor.toARGB32(),
    'rainbow': rainbow,
    'direction': direction.name,
    'speed': speed,
    'blink': blink,
    'blinkHz': blinkHz,
    'durationMode': durationMode.name,
    'durationSeconds': durationSeconds,
    'passes': passes,
    'transition': transition.name,
    'clockFormat': clockFormat.name,
    'textSize': textSize,
    'flipAll': flipAll,
    'flipAllSeconds': flipAllSeconds,
  };

  factory Scene.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final d = Scene(id: fallbackId ?? newSceneId());
    final r = _Reader(json);
    Uint8List? image;
    final encoded = json['image'];
    if (encoded is String) {
      try {
        image = base64Decode(encoded);
      } on FormatException {
        image = null;
      }
    }
    return Scene(
      id: r.string('id', d.id),
      kind: r.enumValue(SceneKind.values, 'kind', d.kind),
      text: r.string('text', d.text),
      bold: r.boolean('bold', d.bold),
      image: image,
      imageColorMode: r.enumValue(
        ImageColorMode.values,
        'imageColorMode',
        d.imageColorMode,
      ),
      imageThreshold: r.number('imageThreshold', d.imageThreshold).clamp(0, 1),
      dotColor: r.color('dotColor', d.dotColor),
      rainbow: r.boolean('rainbow', d.rainbow),
      direction: r.enumValue(MarqueeDirection.values, 'direction', d.direction),
      speed: r.number('speed', d.speed).clamp(0, 120),
      blink: r.boolean('blink', d.blink),
      blinkHz: r.number('blinkHz', d.blinkHz).clamp(0.2, 10),
      durationMode: r.enumValue(
        DurationMode.values,
        'durationMode',
        d.durationMode,
      ),
      durationSeconds: r
          .number('durationSeconds', d.durationSeconds)
          .clamp(1, 600),
      passes: r.integer('passes', d.passes).clamp(1, 20),
      transition: r.enumValue(
        SceneTransition.values,
        'transition',
        d.transition,
      ),
      clockFormat: r.enumValue(
        ClockFormat.values,
        'clockFormat',
        d.clockFormat,
      ),
      textSize: r.number('textSize', d.textSize).clamp(0.2, 1),
      flipAll: r.boolean('flipAll', d.flipAll),
      flipAllSeconds: r
          .number('flipAllSeconds', d.flipAllSeconds)
          .clamp(minFlipAllSeconds, maxFlipAllSeconds),
    );
  }
}

int _idCounter = 0;

String newSceneId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '-${(_idCounter++).toRadixString(36)}';

/// The whole program: the panel plus scenes played in order, looping.
@immutable
class Show {
  Show({required this.panel, required List<Scene> scenes})
    : assert(scenes.isNotEmpty),
      scenes = List.unmodifiable(scenes);

  final PanelSettings panel;
  final List<Scene> scenes;

  factory Show.initial() => Show(
    panel: const PanelSettings(),
    scenes: [
      Scene(id: newSceneId(), text: 'HELLO DOTTY'),
      Scene(
        id: newSceneId(),
        text: '안녕하세요',
        dotColor: const Color(0xFF34C759),
        speed: 28,
        transition: SceneTransition.slideUp,
      ),
      Scene(
        id: newSceneId(),
        text: 'OPEN',
        dotColor: const Color(0xFFFFCC00),
        direction: MarqueeDirection.none,
        blink: true,
        durationMode: DurationMode.seconds,
        durationSeconds: 3,
        transition: SceneTransition.flip,
      ),
      // Demo: the current time, live.
      Scene(
        id: newSceneId(),
        kind: SceneKind.clock,
        dotColor: const Color(0xFF00E5FF),
        direction: MarqueeDirection.none,
        durationMode: DurationMode.seconds,
        durationSeconds: 6,
        transition: SceneTransition.flip,
      ),
    ],
  );

  Show copyWith({PanelSettings? panel, List<Scene>? scenes}) =>
      Show(panel: panel ?? this.panel, scenes: scenes ?? this.scenes);

  int indexOf(String id) => scenes.indexWhere((s) => s.id == id);

  Map<String, Object> toJson() => {
    'version': 2,
    'panel': panel.toJson(),
    'scenes': [for (final s in scenes) s.toJson()],
  };

  factory Show.fromJson(Map<String, dynamic> json) {
    final panel = json['panel'];
    final scenes = json['scenes'];
    final parsed = <Scene>[
      if (scenes is List)
        for (final s in scenes)
          if (s is Map<String, dynamic>) Scene.fromJson(s),
    ];
    // Duplicate ids would confuse selection and widget keys.
    final seen = <String>{};
    final unique = [
      for (final s in parsed) seen.add(s.id) ? s : s.copyWith(id: newSceneId()),
    ];
    if (unique.isEmpty) return Show.initial();
    return Show(
      panel: panel is Map<String, dynamic>
          ? PanelSettings.fromJson(panel)
          : const PanelSettings(),
      scenes: unique,
    );
  }

  /// Converts a save from version 1, which held a single text display whose
  /// field names match today's panel and scene fields.
  factory Show.fromLegacyJson(Map<String, dynamic> json) => Show(
    panel: PanelSettings.fromJson(json),
    scenes: [
      Scene.fromJson(json).copyWith(id: newSceneId(), kind: SceneKind.text),
    ],
  );

  String encode() => jsonEncode(toJson());

  static Show decode(String? source) {
    final json = _tryJson(source);
    return json == null ? Show.initial() : Show.fromJson(json);
  }

  static Show? decodeLegacy(String? source) {
    final json = _tryJson(source);
    return json == null ? null : Show.fromLegacyJson(json);
  }

  static Map<String, dynamic>? _tryJson(String? source) {
    if (source == null) return null;
    try {
      final json = jsonDecode(source);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }
}

/// Lenient JSON field access: missing or mistyped fields fall back to
/// defaults so an older or damaged save never breaks startup.
class _Reader {
  _Reader(this.json);

  final Map<String, dynamic> json;

  String string(String key, String fallback) {
    final v = json[key];
    return v is String ? v : fallback;
  }

  bool boolean(String key, bool fallback) {
    final v = json[key];
    return v is bool ? v : fallback;
  }

  int integer(String key, int fallback) {
    final v = json[key];
    return v is num ? v.round() : fallback;
  }

  double number(String key, double fallback) {
    final v = json[key];
    return v is num ? v.toDouble() : fallback;
  }

  Color color(String key, Color fallback) {
    final v = json[key];
    return v is int ? Color(v) : fallback;
  }

  E enumValue<E extends Enum>(List<E> values, String key, E fallback) {
    final v = json[key];
    return values.firstWhere((e) => e.name == v, orElse: () => fallback);
  }
}

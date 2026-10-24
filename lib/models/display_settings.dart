import 'dart:convert';

import 'package:flutter/material.dart';

enum MarqueeDirection { left, right, none }

enum DotShape { circle, square }

/// All user-configurable options of the dot-matrix display.
@immutable
class DisplaySettings {
  const DisplaySettings({
    this.text = 'HELLO DOTTY  안녕하세요',
    this.rows = 24,
    this.dotColor = const Color(0xFFFF3B30),
    this.backgroundColor = const Color(0xFF0A0A0A),
    this.offDotOpacity = 0.12,
    this.shape = DotShape.circle,
    this.dotFill = 0.82,
    this.speed = 20,
    this.direction = MarqueeDirection.left,
    this.bold = true,
    this.blink = false,
    this.blinkHz = 2,
    this.glow = true,
    this.rainbow = false,
  });

  final String text;

  /// Vertical resolution in dots.
  final int rows;
  final Color dotColor;
  final Color backgroundColor;

  /// Opacity of unlit dots (0 hides them).
  final double offDotOpacity;
  final DotShape shape;

  /// Dot diameter relative to the dot pitch (0..1).
  final double dotFill;

  /// Scroll speed in columns per second.
  final double speed;
  final MarqueeDirection direction;
  final bool bold;
  final bool blink;
  final double blinkHz;
  final bool glow;
  final bool rainbow;

  static const minRows = 8;
  static const maxRows = 64;

  DisplaySettings copyWith({
    String? text,
    int? rows,
    Color? dotColor,
    Color? backgroundColor,
    double? offDotOpacity,
    DotShape? shape,
    double? dotFill,
    double? speed,
    MarqueeDirection? direction,
    bool? bold,
    bool? blink,
    double? blinkHz,
    bool? glow,
    bool? rainbow,
  }) {
    return DisplaySettings(
      text: text ?? this.text,
      rows: rows ?? this.rows,
      dotColor: dotColor ?? this.dotColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      offDotOpacity: offDotOpacity ?? this.offDotOpacity,
      shape: shape ?? this.shape,
      dotFill: dotFill ?? this.dotFill,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
      bold: bold ?? this.bold,
      blink: blink ?? this.blink,
      blinkHz: blinkHz ?? this.blinkHz,
      glow: glow ?? this.glow,
      rainbow: rainbow ?? this.rainbow,
    );
  }

  Map<String, Object> toJson() => {
    'text': text,
    'rows': rows,
    'dotColor': dotColor.toARGB32(),
    'backgroundColor': backgroundColor.toARGB32(),
    'offDotOpacity': offDotOpacity,
    'shape': shape.name,
    'dotFill': dotFill,
    'speed': speed,
    'direction': direction.name,
    'bold': bold,
    'blink': blink,
    'blinkHz': blinkHz,
    'glow': glow,
    'rainbow': rainbow,
  };

  /// Restores settings from JSON, falling back to defaults for any missing
  /// or malformed field so an older save never breaks startup.
  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    const d = DisplaySettings();
    T read<T>(String key, T fallback) {
      final v = json[key];
      return v is T ? v : fallback;
    }

    double readDouble(String key, double fallback) {
      final v = json[key];
      return v is num ? v.toDouble() : fallback;
    }

    E readEnum<E extends Enum>(List<E> values, String key, E fallback) {
      final v = json[key];
      return values.firstWhere((e) => e.name == v, orElse: () => fallback);
    }

    return DisplaySettings(
      text: read('text', d.text),
      rows: read<int>('rows', d.rows).clamp(minRows, maxRows),
      dotColor: Color(read('dotColor', d.dotColor.toARGB32())),
      backgroundColor: Color(
        read('backgroundColor', d.backgroundColor.toARGB32()),
      ),
      offDotOpacity: readDouble('offDotOpacity', d.offDotOpacity).clamp(0, 1),
      shape: readEnum(DotShape.values, 'shape', d.shape),
      dotFill: readDouble('dotFill', d.dotFill).clamp(0.2, 1),
      speed: readDouble('speed', d.speed).clamp(0, 120),
      direction: readEnum(MarqueeDirection.values, 'direction', d.direction),
      bold: read('bold', d.bold),
      blink: read('blink', d.blink),
      blinkHz: readDouble('blinkHz', d.blinkHz).clamp(0.2, 10),
      glow: read('glow', d.glow),
      rainbow: read('rainbow', d.rainbow),
    );
  }

  String encode() => jsonEncode(toJson());

  static DisplaySettings decode(String? source) {
    if (source == null) return const DisplaySettings();
    try {
      final json = jsonDecode(source);
      if (json is Map<String, dynamic>) return DisplaySettings.fromJson(json);
    } on FormatException {
      // Corrupt save: start from defaults.
    }
    return const DisplaySettings();
  }
}

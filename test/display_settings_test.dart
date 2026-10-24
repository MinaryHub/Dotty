import 'package:dotty/models/display_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings survive an encode/decode round trip', () {
    const s = DisplaySettings(
      text: '테스트',
      rows: 32,
      dotColor: Color(0xFF00FF00),
      shape: DotShape.square,
      direction: MarqueeDirection.right,
      blink: true,
      rainbow: true,
    );
    final r = DisplaySettings.decode(s.encode());
    expect(r.toJson(), s.toJson());
  });

  test('corrupt or partial saves fall back to defaults', () {
    const d = DisplaySettings();
    expect(DisplaySettings.decode('not json').toJson(), d.toJson());
    expect(DisplaySettings.decode(null).toJson(), d.toJson());
    final r = DisplaySettings.decode('{"rows": 999, "shape": "hexagon"}');
    expect(r.rows, DisplaySettings.maxRows);
    expect(r.shape, d.shape);
    expect(r.text, d.text);
  });
}

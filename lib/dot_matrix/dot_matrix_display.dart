import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/display_settings.dart';
import 'dot_bitmap.dart';
import 'dot_matrix_painter.dart';

/// An animated LED dot-matrix sign showing [settings.text].
class DotMatrixDisplay extends StatefulWidget {
  const DotMatrixDisplay({
    super.key,
    required this.settings,
    this.paused = false,
  });

  final DisplaySettings settings;
  final bool paused;

  @override
  State<DotMatrixDisplay> createState() => _DotMatrixDisplayState();
}

class _DotMatrixDisplayState extends State<DotMatrixDisplay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier(const DotFrame());
  DotBitmap? _bitmap;
  int _rasterRequest = 0;

  Duration _lastTick = Duration.zero;
  double _scroll = 0;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _rasterize();
    _ticker.start();
  }

  @override
  void didUpdateWidget(DotMatrixDisplay old) {
    super.didUpdateWidget(old);
    final s = widget.settings, o = old.settings;
    if (s.text != o.text || s.rows != o.rows || s.bold != o.bold) {
      _rasterize();
    }
    if (s.direction != o.direction) _scroll = 0;
  }

  Future<void> _rasterize() async {
    final request = ++_rasterRequest;
    final s = widget.settings;
    final bitmap = await rasterizeText(s.text, rows: s.rows, bold: s.bold);
    // Drop stale results when the text changed again while rendering.
    if (!mounted || request != _rasterRequest) return;
    setState(() => _bitmap = bitmap);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (widget.paused) return;
    _seconds += dt;
    _scroll += dt * widget.settings.speed;
    _frame.value = DotFrame(scroll: _scroll, seconds: _seconds);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final bitmap = _bitmap ?? DotBitmap.empty(s.rows);
    return RepaintBoundary(
      child: CustomPaint(
        painter: DotMatrixPainter(bitmap: bitmap, settings: s, frame: _frame),
        child: const SizedBox.expand(),
      ),
    );
  }
}

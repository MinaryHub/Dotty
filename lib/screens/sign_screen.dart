import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dot_matrix/dot_matrix_display.dart';
import '../models/settings_store.dart';
import '../platform/screen_mode.dart';

/// Fullscreen display. Tap to show controls, Esc to leave, Space to pause.
class SignScreen extends StatefulWidget {
  const SignScreen({super.key, required this.store});

  final SettingsStore store;

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  bool _paused = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    enterSignMode();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    exitSignMode();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.space): _togglePause,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder(
                    valueListenable: widget.store,
                    builder: (context, settings, _) =>
                        DotMatrixDisplay(settings: settings, paused: _paused),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _RoundButton(
                              icon: Icons.close,
                              tooltip: '닫기 (Esc)',
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            _RoundButton(
                              icon: _paused ? Icons.play_arrow : Icons.pause,
                              tooltip: _paused ? '재생 (Space)' : '일시정지 (Space)',
                              onPressed: _togglePause,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
      ),
    );
  }
}

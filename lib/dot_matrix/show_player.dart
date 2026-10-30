import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/show.dart';
import 'dot_matrix_display.dart';
import 'dot_matrix_painter.dart';
import 'sign_geometry.dart';

/// Plays a [Show]: each scene for its duration, then the next one with its
/// entry transition, looping forever.
class ShowPlayer extends StatefulWidget {
  const ShowPlayer({
    super.key,
    required this.show,
    this.paused = false,
    this.soloSceneId,
    this.onSceneChanged,
    this.sound = false,
  });

  final Show show;
  final bool paused;

  /// When set, only this scene is shown (looping), e.g. while editing it.
  final String? soloSceneId;

  /// Reports the index of the scene now playing.
  final ValueChanged<int>? onSceneChanged;

  /// Whether a flip-dot panel clicks as its discs turn.
  final bool sound;

  @override
  State<ShowPlayer> createState() => _ShowPlayerState();
}

class _PlayingScene {
  _PlayingScene(this.scene, this.entry);

  final Scene scene;

  /// Increments on every entry so a scene shown twice in a row (or a
  /// single-scene loop) restarts from scratch.
  final int entry;

  Key get key => ValueKey('${scene.id}#$entry');
}

/// Nothing lit: just the sign's dot grid.
final _emptyScene = Scene(
  id: '__empty',
  text: '',
  direction: MarqueeDirection.none,
);

/// The part of [panel] none of the [covered] rectangles reach.
class _UncoveredClipper extends CustomClipper<Path> {
  _UncoveredClipper(this.panel, this.covered);

  final Rect panel;
  final List<Rect> covered;

  @override
  Path getClip(Size size) {
    var path = Path()..addRect(panel);
    for (final r in covered) {
      path = Path.combine(PathOperation.difference, path, Path()..addRect(r));
    }
    return path;
  }

  @override
  bool shouldReclip(_UncoveredClipper old) =>
      old.panel != panel || !listEquals(old.covered, covered);
}

class _ShowPlayerState extends State<ShowPlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  int _index = 0;
  int _entries = 0;
  double _elapsed = 0;

  /// Seconds the shown scene has stood with no transition running; a still
  /// scene with [Scene.replay] comes in again when this reaches its period.
  double _settled = 0;
  _PlayingScene? _outgoing;
  double _transition = 1;

  List<Scene> get _scenes => widget.show.scenes;

  Scene get _current => _scenes[_index % _scenes.length];

  bool get _advances => widget.soloSceneId == null && _scenes.length > 1;

  /// A flip wave needs longer than a fade or slide to read well.
  double get _transitionMs =>
      widget.show.panel.transitionMs *
      (_current.transition == SceneTransition.flip ? 2.5 : 1);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(ShowPlayer old) {
    super.didUpdateWidget(old);
    if (widget.soloSceneId != old.soloSceneId) {
      _outgoing = null;
      _transition = 1;
      _elapsed = 0;
      _settled = 0;
    }
    if (_index >= _scenes.length) _index = 0;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (widget.paused) return;

    if (_outgoing != null) {
      setState(() {
        _transition += dt * 1000 / _transitionMs;
        if (_transition >= 1) {
          _transition = 1;
          _outgoing = null;
        }
      });
    }

    if (_outgoing == null) _settled += dt;

    if (_advances) {
      _elapsed += dt;
      final scene = _current;
      if (!scene.usesPasses && _elapsed >= scene.durationSeconds) {
        _advance();
        return;
      }
    }

    // Edited scenes count too: the solo scene is the one on the sign.
    final soloIndex = widget.soloSceneId == null
        ? -1
        : widget.show.indexOf(widget.soloSceneId!);
    final shown = soloIndex >= 0 ? _scenes[soloIndex] : _current;
    if (_outgoing == null && shown.replayDue(_settled)) _replay();
  }

  void _onPass(Scene scene, int passes) {
    if (_advances && scene.id == _current.id && scene.usesPasses) {
      if (passes >= scene.passes) _advance();
    }
  }

  void _advance() {
    setState(() {
      final previous = _PlayingScene(_current, _entries);
      _index = (_index + 1) % _scenes.length;
      _entries++;
      _elapsed = 0;
      _settled = 0;
      // A flip-dot board turns its own discs over to the next scene.
      final cut =
          _current.transition == SceneTransition.cut ||
          widget.show.panel.flipDots;
      _outgoing = cut ? null : previous;
      _transition = cut ? 1 : 0;
    });
    widget.onSceneChanged?.call(_index);
  }

  /// Brings the same scene in again with its entry effect. The content is
  /// identical, so on LEDs the old copy leaves as the new one arrives; a
  /// flip-dot board clears and redraws itself (see [DotMatrixDisplay]).
  void _replay() {
    setState(() {
      final soloIndex = widget.soloSceneId == null
          ? -1
          : widget.show.indexOf(widget.soloSceneId!);
      final scene = soloIndex >= 0 ? _scenes[soloIndex] : _current;
      // While editing, the solo scene's entry number is -1 - _entries.
      final previous = _PlayingScene(
        scene,
        soloIndex >= 0 ? -1 - _entries : _entries,
      );
      _entries++;
      _settled = 0;
      final cut =
          scene.transition == SceneTransition.cut || widget.show.panel.flipDots;
      _outgoing = cut ? null : previous;
      _transition = cut ? 1 : 0;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Widget _display(_PlayingScene p, FlipState? flip, int columns, {Key? key}) {
    return DotMatrixDisplay(
      key: key,
      columns: columns,
      scene: p.scene,
      entry: p.entry,
      panel: widget.show.panel,
      paused: widget.paused,
      onPass: (n) => _onPass(p.scene, n),
      flip: flip,
      sound: widget.sound,
    );
  }

  @override
  Widget build(BuildContext context) {
    final soloIndex = widget.soloSceneId == null
        ? -1
        : widget.show.indexOf(widget.soloSceneId!);
    final current = soloIndex >= 0
        ? _PlayingScene(_scenes[soloIndex], -1 - _entries)
        : _PlayingScene(_current, _entries);
    // Keep the outgoing scene's latest settings if it was edited meanwhile.
    final outgoing = _outgoing;
    final out = outgoing == null
        ? null
        : _PlayingScene(
            _scenes.firstWhere(
              (s) => s.id == outgoing.scene.id,
              orElse: () => outgoing.scene,
            ),
            outgoing.entry,
          );

    // The sign has one fixed grid wherever it is shown, so the preview and
    // fullscreen look identical; leftover space is filled with the board.
    final panel = widget.show.panel;
    final columns = signColumns(panel, signAspect(context, panel));
    Widget sign(Widget child) => ColoredBox(
      color: panel.backgroundColor,
      child: Center(
        child: AspectRatio(
          aspectRatio: columns / panel.rows,
          child: ClipRect(child: child),
        ),
      ),
    );

    if (panel.flipDots) {
      // One board for the whole show; scene changes flip its discs.
      return sign(
        _display(current, null, columns, key: const ValueKey('flip-board')),
      );
    }

    return sign(
      LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final t = out == null
              ? 1.0
              : Curves.easeInOut.transform(_transition.clamp(0, 1));
          // Moves snap to whole dots so the grid stays aligned like a real
          // LED panel shifting its content.
          final rows = widget.show.panel.rows;
          final pitchY = size.height / rows;
          final pitchX = size.width / columns;
          double snap(double v, double pitch) => (v / pitch).round() * pitch;

          var inOffset = Offset.zero, outOffset = Offset.zero;
          var inOpacity = 1.0, outOpacity = 1.0;
          FlipState? inFlip, outFlip;
          // The same scene coming in again (a replay): its two copies look
          // alike, so a fade has to dip out and back in to be seen at all.
          final replaying = out != null && out.scene.id == current.scene.id;
          switch (current.scene.transition) {
            case SceneTransition.cut:
              inOpacity = t;
            case SceneTransition.fade:
              if (replaying) {
                outOpacity = (1 - 2 * t).clamp(0.0, 1.0);
                inOpacity = (2 * t - 1).clamp(0.0, 1.0);
              } else {
                inOpacity = t;
              }
            case SceneTransition.slideDiagLeft:
            case SceneTransition.slideDiagRight:
              // Sideways like the plain slide, rising slightly: the new
              // scene arrives from the lower right (or lower left).
              final sign =
                  current.scene.transition == SceneTransition.slideDiagLeft
                  ? 1.0
                  : -1.0;
              final rise = size.height * diagonalSlideRise;
              final dx = snap(size.width * t, pitchX);
              final dy = snap(rise * t, pitchY);
              outOffset = Offset(-sign * dx, -dy);
              inOffset = Offset(sign * (size.width - dx), rise - dy);
            case SceneTransition.slideLeft:
              final dx = snap(size.width * t, pitchX);
              outOffset = Offset(-dx, 0);
              inOffset = Offset(size.width - dx, 0);
            case SceneTransition.slideUp:
              final dy = snap(size.height * t, pitchY);
              outOffset = Offset(0, -dy);
              inOffset = Offset(0, size.height - dy);
            case SceneTransition.flip:
              if (out != null) {
                outFlip = FlipState(t, outgoing: true);
                inFlip = FlipState(t, outgoing: false);
              }
          }

          // Same wrapper structure for every child, keyed per playing scene,
          // so a display keeps its state (scroll position) when it changes
          // role from incoming to settled to outgoing.
          Widget layer(
            _PlayingScene p,
            Offset offset,
            double opacity,
            FlipState? flip,
          ) {
            return KeyedSubtree(
              key: p.key,
              child: Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: opacity,
                  child: _display(p, flip, columns),
                ),
              ),
            );
          }

          // A diagonal slide leaves a band of the sign uncovered above the
          // incoming scene and below the outgoing one; an empty scene fills
          // it so the dot grid carries on there.
          final diagonalLeft =
              current.scene.transition == SceneTransition.slideDiagLeft;
          final diagonal =
              out != null &&
              (diagonalLeft ||
                  current.scene.transition == SceneTransition.slideDiagRight);
          // The two scenes meet at this x; the band beside each takes that
          // scene's dot color (the unlit dots are tinted by it).
          final meet = diagonalLeft ? inOffset.dx : outOffset.dx;
          Widget gridBand(Rect part, Scene beside, String name) => ClipPath(
            key: ValueKey('uncovered-grid-$name'),
            clipper: _UncoveredClipper(part, [
              outOffset & size,
              inOffset & size,
            ]),
            child: _display(
              _PlayingScene(_emptyScene.copyWith(dotColor: beside.dotColor), 0),
              null,
              columns,
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // Flipping scenes only paint their dots; they share this
              // background.
              ColoredBox(color: widget.show.panel.backgroundColor),
              if (diagonal) ...[
                gridBand(
                  Rect.fromLTRB(0, 0, meet, size.height),
                  diagonalLeft ? out.scene : current.scene,
                  'left',
                ),
                gridBand(
                  Rect.fromLTRB(meet, 0, size.width, size.height),
                  diagonalLeft ? current.scene : out.scene,
                  'right',
                ),
              ],
              if (out != null) layer(out, outOffset, outOpacity, outFlip),
              layer(current, inOffset, inOpacity, inFlip),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'show.dart';

/// Holds the current [Show] and persists changes.
class ShowStore extends ValueNotifier<Show> {
  ShowStore._(this._prefs, super.value);

  static const _key = 'show_v2';
  static const _legacyKey = 'display_settings_v1';
  final SharedPreferences? _prefs;
  Timer? _saveTimer;

  static Future<ShowStore> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final show = saved != null
          ? Show.decode(saved)
          : Show.decodeLegacy(prefs.getString(_legacyKey)) ?? Show.initial();
      return ShowStore._(prefs, show);
    } catch (e) {
      debugPrint('Settings storage unavailable: $e');
      return ShowStore._(null, Show.initial());
    }
  }

  /// In-memory store for tests.
  @visibleForTesting
  ShowStore.memory([Show? show]) : _prefs = null, super(show ?? Show.initial());

  @override
  set value(Show show) {
    super.value = show;
    if (_prefs == null) return;
    // Sliders fire many updates per second and shows can carry images, so
    // coalesce writes.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  void _save() {
    _prefs?.setString(_key, value.encode()).catchError((Object e) {
      debugPrint('Saving failed: $e');
      return false;
    });
  }

  void updatePanel(PanelSettings Function(PanelSettings p) change) =>
      value = value.copyWith(panel: change(value.panel));

  void updateScene(String id, Scene Function(Scene s) change) {
    value = value.copyWith(
      scenes: [for (final s in value.scenes) s.id == id ? change(s) : s],
    );
  }

  /// Inserts [scene] after [afterId] (or at the end).
  void addScene(Scene scene, {String? afterId}) {
    final scenes = [...value.scenes];
    final i = afterId == null ? -1 : value.indexOf(afterId);
    scenes.insert(i < 0 ? scenes.length : i + 1, scene);
    value = value.copyWith(scenes: scenes);
  }

  /// Returns the copy's id.
  String duplicateScene(String id) {
    final copy = value.scenes[value.indexOf(id)].copyWith(id: newSceneId());
    addScene(copy, afterId: id);
    return copy.id;
  }

  void removeScene(String id) {
    if (value.scenes.length <= 1) return;
    value = value.copyWith(
      scenes: [
        for (final s in value.scenes)
          if (s.id != id) s,
      ],
    );
  }

  /// Moves the scene at [from] so it ends up at index [to].
  void moveScene(int from, int to) {
    final scenes = [...value.scenes];
    final s = scenes.removeAt(from);
    scenes.insert(to.clamp(0, scenes.length), s);
    value = value.copyWith(scenes: scenes);
  }

  void resetPanel() => updatePanel((_) => const PanelSettings());

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }
}

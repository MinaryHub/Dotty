import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'display_settings.dart';

/// Holds the current [DisplaySettings] and persists every change.
class SettingsStore extends ValueNotifier<DisplaySettings> {
  SettingsStore._(this._prefs, super.value);

  static const _key = 'display_settings_v1';
  final SharedPreferences? _prefs;

  static Future<SettingsStore> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SettingsStore._(
        prefs,
        DisplaySettings.decode(prefs.getString(_key)),
      );
    } catch (e) {
      debugPrint('Settings storage unavailable: $e');
      return SettingsStore._(null, const DisplaySettings());
    }
  }

  /// In-memory store for tests.
  @visibleForTesting
  SettingsStore.memory([super.value = const DisplaySettings()]) : _prefs = null;

  void update(DisplaySettings Function(DisplaySettings s) change) {
    value = change(value);
    _prefs?.setString(_key, value.encode());
  }

  void reset() => update((_) => const DisplaySettings());
}

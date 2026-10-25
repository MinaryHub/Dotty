import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the interface is offered in. Scene content (the words on the
/// sign) is the user's own and is not translated.
enum AppLanguage { en, ko }

/// The chosen interface language, remembered across launches.
class LanguageController extends ValueNotifier<AppLanguage> {
  LanguageController([super.value = AppLanguage.en]);

  static const _key = 'ui_language';

  static Future<LanguageController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      return LanguageController(
        AppLanguage.values.asNameMap()[saved] ?? AppLanguage.en,
      );
    } catch (_) {
      return LanguageController();
    }
  }

  void toggle() {
    value = value == AppLanguage.en ? AppLanguage.ko : AppLanguage.en;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, value.name))
        .catchError((Object _) => false);
  }
}

/// Makes the language available below it; widgets that read it rebuild
/// when it changes.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

extension Translate on BuildContext {
  AppLanguage get language =>
      LanguageScope.maybeOf(this)?.value ?? AppLanguage.en;

  /// [en] or [ko], whichever the interface is shown in.
  String tr(String en, String ko) => language == AppLanguage.ko ? ko : en;
}

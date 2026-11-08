import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Starlit UI copy: Russian when the app locale is `ru`, otherwise English.
/// FlClash ARB covers stock screens; Starlit pages use this helper.
abstract final class StarlitL10n {
  static bool get isRuCurrent =>
      Intl.getCurrentLocale().toLowerCase().startsWith('ru');

  static bool isRu(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ru';

  static String of(
    BuildContext context, {
    required String ru,
    required String en,
  }) =>
      isRu(context) ? ru : en;

  static String t({required String ru, required String en}) =>
      isRuCurrent ? ru : en;
}

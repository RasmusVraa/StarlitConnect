import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Подтверждение и очистка локальной сессии (подписка Xray).
abstract final class StarlitSession {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Удалить',
  }) async {
    final res = await dialogs.showMessage(
      title: title,
      message: TextSpan(text: message),
      destructive: true,
      confirmText: confirmText,
    );
    return res == true;
  }

  static Future<void> clearSubscriptions(WidgetRef ref) async {
    await ref.read(starlitEngineProvider).clearSession();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:starlit_connect/common/constant.dart';

/// Ответ POST /cabinet/api/auth/deeplink/request.
class StarlitWebAuthSession {
  const StarlitWebAuthSession({
    required this.token,
    required this.expiresIn,
    required this.telegramUrl,
    required this.webUrl,
    required this.startPayload,
  });

  final String token;
  final int expiresIn;
  final String telegramUrl;
  final String webUrl;
  final String startPayload;

  /// Ссылка на бота с /start webauth_… (с запасным вариантом из supportUrl).
  String get resolvedTelegramUrl {
    final direct = telegramUrl.trim();
    if (direct.isNotEmpty) return direct;
    final payload = startPayload.trim();
    if (payload.isEmpty) return supportUrl;
    return '$supportUrl?start=${Uri.encodeComponent(payload)}';
  }

  /// Страница подтверждения на сайте.
  String get resolvedWebUrl {
    final direct = webUrl.trim();
    if (direct.isNotEmpty) return direct;
    final t = token.trim();
    if (t.isEmpty) return websiteUrl;
    return '$websiteUrl/cabinet/app-auth?t=${Uri.encodeQueryComponent(t)}';
  }
}

class StarlitWebAuthResult {
  const StarlitWebAuthResult({
    required this.subscriptionLink,
    this.accessToken,
    this.expireAt,
  });

  final String? subscriptionLink;
  final String? accessToken;
  final String? expireAt;
}

/// Клиент одноразовой авторизации кабинета (бот /start webauth_* или сайт).
///
/// Ответы читаем как plain: сервер иногда отдаёт JSON с Content-Type
/// text/plain (например poll 202), и generic Map у Dio тогда падает.
abstract final class StarlitWebAuth {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$websiteUrl/cabinet/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (code) => code != null && code < 500,
    ),
  );

  static Future<StarlitWebAuthSession> request({CancelToken? cancelToken}) async {
    final res = await _dio.post<String>(
      '/auth/deeplink/request',
      cancelToken: cancelToken,
    );
    if (res.statusCode == 404 || res.statusCode == 501) {
      throw StateError(
        'Сервер ещё без API авторизации приложения. Обновите бот/кабинет.',
      );
    }
    if (res.statusCode != 200) {
      throw StateError(
        _plainError(res.data) ??
            'Не удалось начать авторизацию (${res.statusCode})',
      );
    }
    final json = _decodeMap(res.data);
    final token = (json['token'] as String?)?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Пустой токен авторизации');
    }
    return StarlitWebAuthSession(
      token: token,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
      telegramUrl: (json['telegram_url'] as String?)?.trim() ?? '',
      webUrl: (json['web_url'] as String?)?.trim() ?? '',
      startPayload: (json['start_payload'] as String?)?.trim() ?? '',
    );
  }

  /// Ждёт подтверждения, затем пытается получить access_token через complete.
  static Future<StarlitWebAuthResult> pollUntilReady(
    String token, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 2),
    CancelToken? cancelToken,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (cancelToken?.isCancelled ?? false) {
        throw StateError('Авторизация отменена');
      }
      final res = await _dio.post<String>(
        '/auth/deeplink/poll',
        data: {'token': token},
        cancelToken: cancelToken,
      );
      if (res.statusCode == 202) {
        await Future<void>.delayed(interval);
        continue;
      }
      if (res.statusCode == 410) {
        throw StateError('Токен авторизации истёк — попробуйте снова');
      }
      if (res.statusCode == 404 || res.statusCode == 501) {
        throw StateError(
          'Сервер ещё без API авторизации приложения. Обновите бот/кабинет.',
        );
      }
      if (res.statusCode != 200) {
        throw StateError(
          _plainError(res.data) ??
              'Ошибка проверки входа (${res.statusCode})',
        );
      }
      final json = _decodeMap(res.data);
      final link = (json['subscription_link'] as String?)?.trim();
      final expireAt = (json['expire_at'] as String?)?.trim();
      var access =
          (json['access_token'] as String?)?.trim() ??
          (json['token'] as String?)?.trim();

      access ??= await _complete(token, cancelToken: cancelToken);

      // Для приложения нужен только subscription_link; токен кабинета не храним.
      return StarlitWebAuthResult(
        subscriptionLink: (link != null && link.isNotEmpty) ? link : null,
        accessToken: access,
        expireAt: expireAt,
      );
    }
    throw StateError('Время ожидания авторизации истекло');
  }

  static Future<String?> _complete(
    String token, {
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.post<String>(
        '/auth/deeplink/complete',
        data: {'token': token},
        cancelToken: cancelToken,
      );
      if (res.statusCode != 200) return null;
      final json = _decodeMap(res.data);
      return (json['access_token'] as String?)?.trim() ??
          (json['token'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeMap(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      throw StateError('Пустой ответ сервера авторизации');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw StateError('Неожиданный ответ сервера авторизации');
  }

  static String? _plainError(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty || text.startsWith('{') || text.startsWith('[')) {
      return null;
    }
    return text;
  }
}

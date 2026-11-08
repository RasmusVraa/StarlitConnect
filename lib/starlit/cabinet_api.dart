import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:starlit_connect/common/constant.dart';
import 'package:starlit_connect/starlit/hwid.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/subscription_info.dart';

class StarlitCabinetDevice {
  const StarlitCabinetDevice({
    required this.hwid,
    required this.title,
    required this.subtitle,
    this.platform = '',
    this.customName = '',
    this.model = '',
    this.isLocal = false,
  });

  final String hwid;
  final String title;
  final String subtitle;
  final String platform;
  final String customName;
  final String model;
  final bool isLocal;

  factory StarlitCabinetDevice.fromJson(Map<String, dynamic> json) {
    final hwid = '${json['hwid'] ?? ''}'.trim();
    final custom = '${json['custom_name'] ?? ''}'.trim();
    final model = '${json['device_model'] ?? ''}'.trim();
    final platform = '${json['platform'] ?? ''}'.trim();
    final os = '${json['os_version'] ?? ''}'.trim();
    final title = custom.isNotEmpty
        ? custom
        : (model.isNotEmpty
              ? model
              : (platform.isNotEmpty ? platform : (hwid.isEmpty ? 'Устройство' : hwid)));
    final parts = <String>[
      if (custom.isNotEmpty && model.isNotEmpty) model,
      if (platform.isNotEmpty) platform,
      if (os.isNotEmpty) os,
    ];
    return StarlitCabinetDevice(
      hwid: hwid,
      title: title,
      subtitle: parts.isEmpty ? hwid : parts.join(' · '),
      platform: platform,
      customName: custom,
      model: model,
    );
  }
}

class StarlitSlots {
  const StarlitSlots({
    required this.current,
    required this.base,
    required this.max,
    required this.canIncrease,
    required this.canDecrease,
    required this.pinned,
    required this.daysLeft,
  });

  final int current;
  final int base;
  final int max;
  final bool canIncrease;
  final bool canDecrease;
  final bool pinned;
  final int? daysLeft;

  static StarlitSlots? fromJson(Object? raw) {
    if (raw is! Map || raw['enabled'] != true || raw['ui_visible'] != true) {
      return null;
    }
    int number(String key) => (raw[key] as num?)?.round() ?? 0;
    return StarlitSlots(
      current: number('current_limit'),
      base: number('base_limit'),
      max: number('max_limit'),
      canIncrease: raw['can_increase'] == true,
      canDecrease: raw['can_decrease'] == true,
      pinned: raw['pinned'] == true,
      daysLeft: (raw['days_left'] as num?)?.round(),
    );
  }
}

class StarlitCabinetSnapshot {
  const StarlitCabinetSnapshot({
    required this.tariffName,
    required this.daysLeft,
    required this.expireAt,
    required this.devices,
    required this.deviceLimit,
    required this.usedBytes,
    required this.totalBytes,
    this.connected = 0,
    this.devicesEnabled = true,
    this.slots,
    this.isTrial = false,
    this.subscriptionLink = '',
  });

  final String tariffName;
  final int? daysLeft;
  final DateTime? expireAt;
  final List<StarlitCabinetDevice> devices;
  final int? deviceLimit;
  final int usedBytes;
  final int totalBytes;
  final int connected;
  final bool devicesEnabled;
  final StarlitSlots? slots;
  final bool isTrial;
  final String subscriptionLink;
}

/// Кабинетный API + метаданные из заголовков подписки.
abstract final class StarlitCabinetApi {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$websiteUrl/cabinet/api',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (code) => code != null && code < 500,
    ),
  );

  static final Map<String, String> _cookies = {};
  static var _prefsHydrated = false;

  static String? get _csrf =>
      _cookies['csrf_token'] ?? _cookies['cab_csrf'];

  /// Забирает Set-Cookie из любого ответа (в т.ч. из webauth Dio).
  static void absorbHeaders(Headers headers) {
    final lines = headers.map['set-cookie'];
    if (lines == null) return;
    for (final line in lines) {
      final pair = line.split(';').first;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty || value == 'deleted') {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
    final csrf = _csrf;
    if (csrf != null && csrf.isNotEmpty) {
      unawaited(StarlitPrefs.setCabinetCsrf(csrf));
    }
  }

  static void _absorbCookies(Headers headers) => absorbHeaders(headers);

  static void _absorbJsonCsrf(Object? json) {
    if (json is! Map) return;
    for (final key in ['csrf_token', 'cab_csrf', 'csrf', 'csrfToken']) {
      final raw = '${json[key] ?? ''}'.trim();
      if (raw.isEmpty) continue;
      _cookies['csrf_token'] = raw;
      _cookies['cab_csrf'] = raw;
      unawaited(StarlitPrefs.setCabinetCsrf(raw));
      return;
    }
  }

  static Future<void> _hydratePrefs() async {
    if (_prefsHydrated) return;
    _prefsHydrated = true;
    final saved = await StarlitPrefs.cabinetCsrf();
    if (saved != null && saved.isNotEmpty && _csrf == null) {
      _cookies['csrf_token'] = saved;
      _cookies['cab_csrf'] = saved;
    }
  }

  static Map<String, String> _authHeaders({
    String? token,
    bool withCsrf = false,
  }) {
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (withCsrf && _csrf != null && _csrf!.isNotEmpty)
        'X-CSRF-Token': _csrf!,
      if (_cookies.isNotEmpty)
        'Cookie': [
          for (final e in _cookies.entries) '${e.key}=${e.value}',
        ].join('; '),
    };
  }

  static Future<void> ensureCsrf({bool force = false}) async {
    await _hydratePrefs();
    if (!force && _csrf != null && _csrf!.isNotEmpty) return;

    final token = await StarlitPrefs.cabinetToken();
    for (final path in ['/auth/bootstrap', '/me/subscription']) {
      try {
        final res = await _dio.get<String>(
          path,
          options: Options(headers: _authHeaders(token: token)),
        );
        _absorbCookies(res.headers);
        try {
          _absorbJsonCsrf(jsonDecode(res.data ?? ''));
        } catch (_) {}
        if (_csrf != null && _csrf!.isNotEmpty) return;
      } catch (_) {}
    }

    // Double-submit fallback: кабинет читает csrf из cookie + заголовка.
    if (_csrf == null || _csrf!.isEmpty) {
      final rnd = Random.secure();
      final forged = List.generate(
        32,
        (_) => rnd.nextInt(16).toRadixString(16),
      ).join();
      _cookies['csrf_token'] = forged;
      _cookies['cab_csrf'] = forged;
      await StarlitPrefs.setCabinetCsrf(forged);
    }
  }

  static Future<StarlitCabinetSnapshot> load({
    required String? subscriptionUrl,
    required int usedBytes,
    required int totalBytes,
    required DateTime? expireFromProfile,
  }) async {
    await ensureCsrf();
    final headerMeta = subscriptionUrl == null || subscriptionUrl.isEmpty
        ? null
        : await _fetchHeaderMeta(subscriptionUrl);

    var tariff = headerMeta?.tariffHint ?? '';
    var days = headerMeta?.daysLeft;
    var expire = expireFromProfile ?? headerMeta?.expireAt;
    var devices = <StarlitCabinetDevice>[];
    int? limit;
    StarlitSlots? slots;
    var isTrial = false;
    var link = '';
    var connected = -1;
    var devicesEnabled = true;

    final token = await StarlitPrefs.cabinetToken();
    final hasToken = token != null && token.isNotEmpty;
    if (hasToken) {
      try {
        final sub = await _authedGet('/me/subscription', token);
        if (sub != null) {
          final tariffMap = sub['tariff'];
          if (tariffMap is Map) {
            final name = '${tariffMap['name'] ?? ''}'.trim();
            if (name.isNotEmpty) tariff = name;
          }
          final expireRaw = '${sub['expire_at'] ?? ''}'.trim();
          if (expireRaw.isNotEmpty) {
            expire = DateTime.tryParse(expireRaw)?.toLocal() ?? expire;
          }
          final daysRaw = sub['days_left'] ?? sub['effective_days'];
          if (daysRaw is num) days = daysRaw.round();
          final lim = sub['device_limit'] ?? sub['hwid_limit'];
          if (lim is num) limit = lim.round();
          if (tariffMap is Map && tariffMap['device_limit'] is num) {
            limit ??= (tariffMap['device_limit'] as num).round();
          }
          slots = StarlitSlots.fromJson(sub['hwid_extra']);
          isTrial = sub['is_trial'] == true;
          link = '${sub['subscription_link'] ?? ''}'.trim();
        }
      } catch (_) {}

      try {
        final payload = await _authedGetJson('/me/devices', token);
        final list = payload is List
            ? payload
            : (payload is Map ? (payload['devices'] ?? payload['items']) : null);
        if (list is List) {
          devices = [
            for (final item in list)
              if (item is Map)
                StarlitCabinetDevice.fromJson(Map<String, dynamic>.from(item)),
          ];
        }
        if (payload is Map) {
          devicesEnabled = payload['enabled'] != false;
          final used = payload['connected'];
          if (used is num) connected = used.round();
          final cap = payload['device_limit'];
          if (cap is num && cap > 0) limit = cap.round();
        }
      } catch (_) {}
    }

    if (days == null && expire != null) {
      days = expire.difference(DateTime.now()).inDays;
      if (days < 0) days = 0;
    }

    if (devices.isEmpty && !hasToken) {
      devices = [await _localDevice()];
    }

    if (tariff.isEmpty || _looksLikeNickname(tariff)) {
      tariff = 'Starlit VPN';
    }

    return StarlitCabinetSnapshot(
      tariffName: tariff,
      daysLeft: days,
      expireAt: expire,
      devices: devices,
      deviceLimit: limit,
      usedBytes: usedBytes,
      totalBytes: totalBytes,
      connected: connected >= 0 ? connected : devices.length,
      devicesEnabled: devicesEnabled,
      slots: slots,
      isTrial: isTrial,
      subscriptionLink: link,
    );
  }

  static Future<({int status, Object? json})> call(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    bool retryOnCsrf = true,
  }) async {
    await _hydratePrefs();
    final upper = method.toUpperCase();
    final needsCsrf = upper != 'GET' && upper != 'HEAD' && upper != 'OPTIONS';
    if (needsCsrf) await ensureCsrf();
    final token = await StarlitPrefs.cabinetToken();
    final res = await _dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        headers: {
          ..._authHeaders(token: token, withCsrf: needsCsrf),
          ...headers,
        },
      ),
    );
    _absorbCookies(res.headers);
    Object? json;
    final raw = res.data?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        json = jsonDecode(raw);
        _absorbJsonCsrf(json);
      } catch (_) {}
    }
    if (res.statusCode == 401 && path.startsWith('/auth/')) {
      await StarlitPrefs.clearCabinetToken();
    }
    final csrfFail =
        res.statusCode == 403 ||
        res.statusCode == 419 ||
        (json is Map &&
            '${json['reason_code'] ?? json['code'] ?? json['error'] ?? ''}'
                .toLowerCase()
                .contains('csrf'));
    if (needsCsrf && csrfFail && retryOnCsrf) {
      _cookies.remove('csrf_token');
      _cookies.remove('cab_csrf');
      await StarlitPrefs.clearCabinetCsrf();
      await ensureCsrf(force: true);
      return call(
        method,
        path,
        body: body,
        headers: headers,
        retryOnCsrf: false,
      );
    }
    return (status: res.statusCode ?? 0, json: json);
  }

  static Future<bool> renameDevice(String hwid, String name) async {
    final res = await call(
      'POST',
      '/me/devices/rename',
      body: {'hwid': hwid, 'name': name},
    );
    return res.status == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchTariffs() async {
    final res = await _dio.get<String>('/tariffs');
    if (res.statusCode != 200) return const [];
    final decoded = jsonDecode(res.data ?? '');
    if (decoded is! Map) return const [];
    final list = decoded['tariffs'];
    if (list is! List) return const [];
    return [
      for (final t in list)
        if (t is Map) Map<String, dynamic>.from(t),
    ];
  }

  static Future<bool> deleteDevice(String hwid) async {
    final res = await call(
      'POST',
      '/me/devices/delete',
      body: {'hwid': hwid},
    );
    return res.status == 200;
  }

  static Future<Map<String, dynamic>?> _authedGet(
    String path,
    String token,
  ) async {
    await _hydratePrefs();
    final res = await _dio.get<String>(
      path,
      options: Options(headers: _authHeaders(token: token)),
    );
    _absorbCookies(res.headers);
    if (res.statusCode == 401) return null;
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.data ?? '');
    _absorbJsonCsrf(decoded);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  static Future<Object?> _authedGetJson(String path, String token) async {
    await _hydratePrefs();
    final res = await _dio.get<String>(
      path,
      options: Options(headers: _authHeaders(token: token)),
    );
    _absorbCookies(res.headers);
    if (res.statusCode == 401) return null;
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.data ?? '');
    _absorbJsonCsrf(decoded);
    return decoded;
  }

  static Future<_HeaderMeta?> _fetchHeaderMeta(String url) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.bytes,
          validateStatus: (c) => c != null && c < 500,
        ),
      );
      final res = await dio.get<List<int>>(url);
      if (res.statusCode != 200) return null;
      final headers = res.headers;
      final userinfo = _header(headers, 'subscription-userinfo');
      final announce = _decodeMaybeBase64(_header(headers, 'announce'));
      final title = _decodeMaybeBase64(_header(headers, 'profile-title'));

      DateTime? expire;
      if (userinfo != null) {
        for (final part in userinfo.split(';')) {
          final i = part.indexOf('=');
          if (i < 0) continue;
          final key = part.substring(0, i).trim().toLowerCase();
          final value = int.tryParse(part.substring(i + 1).trim());
          if (key == 'expire' && value != null && value > 0) {
            expire = StarlitSubscriptionInfo.expireFromTimestamp(value);
          }
        }
      }

      int? days;
      final daysMatch = RegExp(
        r'осталось\s*:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(announce ?? '');
      if (daysMatch != null) {
        days = int.tryParse(daysMatch.group(1)!);
      }

      var tariffHint = '';
      if (title != null &&
          title.isNotEmpty &&
          !title.startsWith('@') &&
          !_looksLikeNickname(title)) {
        tariffHint = title;
      }

      return _HeaderMeta(
        daysLeft: days,
        expireAt: expire,
        tariffHint: tariffHint,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _header(Headers headers, String name) {
    return headers.value(name) ?? headers.value(name.toLowerCase());
  }

  static String? _decodeMaybeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = raw.trim();
    if (!value.toLowerCase().startsWith('base64:')) return value;
    try {
      return utf8.decode(base64.decode(value.substring(7)));
    } catch (_) {
      return value;
    }
  }

  static bool _looksLikeNickname(String value) {
    final v = value.trim();
    if (v.isEmpty) return true;
    if (v.startsWith('@')) return true;
    if (v.toLowerCase() == 'admin') return true;
    if (!v.contains(' ') && v.length <= 16 && !v.contains('Starlit')) {
      return RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v);
    }
    return false;
  }

  static Future<StarlitCabinetDevice> _localDevice() async {
    final host = Platform.localHostname;
    final info = await StarlitHwid.deviceInfo();
    return StarlitCabinetDevice(
      hwid: 'local-${host.toLowerCase()}',
      title: host.isEmpty ? 'Этот ПК' : host,
      subtitle: '${info.os} · ${info.version} · ${info.model}',
      platform: info.os,
      model: info.model,
      isLocal: true,
    );
  }
}

class _HeaderMeta {
  const _HeaderMeta({
    required this.daysLeft,
    required this.expireAt,
    required this.tariffHint,
  });

  final int? daysLeft;
  final DateTime? expireAt;
  final String tariffHint;
}

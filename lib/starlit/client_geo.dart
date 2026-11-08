import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:starlit_connect/starlit/prefs.dart';

class StarlitClientGeo {
  const StarlitClientGeo({
    required this.ip,
    required this.countryCode,
    required this.country,
    required this.city,
    required this.lat,
    required this.lon,
  });

  final String ip;
  final String countryCode;
  final String country;
  final String city;
  final double lat;
  final double lon;

  String get label {
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? (countryCode.isEmpty ? ip : countryCode) : parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'cc': countryCode,
        'country': country,
        'city': city,
        'lat': lat,
        'lon': lon,
      };

  factory StarlitClientGeo.fromJson(Map<String, dynamic> json) {
    return StarlitClientGeo(
      ip: '${json['ip'] ?? ''}',
      countryCode: '${json['cc'] ?? ''}'.toUpperCase(),
      country: '${json['country'] ?? ''}',
      city: '${json['city'] ?? ''}',
      lat: (json['lat'] as num?)?.toDouble() ?? 55.75,
      lon: (json['lon'] as num?)?.toDouble() ?? 37.62,
    );
  }
}

/// Resolve the client's real public IP / city (cached ~1h).
abstract final class StarlitClientGeoApi {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.plain,
      headers: const {'Accept': 'application/json', 'User-Agent': 'StarlitConnect'},
    ),
  );

  static StarlitClientGeo? _memory;
  static DateTime? _at;

  static StarlitClientGeo? get cached => _memory;

  static Future<StarlitClientGeo?> load({bool force = false}) async {
    if (!force &&
        _memory != null &&
        _at != null &&
        DateTime.now().difference(_at!) < const Duration(hours: 1)) {
      return _memory;
    }
    if (!force) {
      final raw = await StarlitPrefs.clientGeoJson();
      if (raw != null && raw.isNotEmpty) {
        try {
          final geo = StarlitClientGeo.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
          _memory = geo;
          _at = DateTime.now();
        } catch (_) {}
      }
    }

    final fresh = await _fetch();
    if (fresh != null) {
      _memory = fresh;
      _at = DateTime.now();
      await StarlitPrefs.setClientGeoJson(jsonEncode(fresh.toJson()));
      return fresh;
    }
    return _memory;
  }

  static Future<StarlitClientGeo?> _fetch() async {
    try {
      final res = await _dio.get<String>(
        'http://ip-api.com/json/?fields=status,country,countryCode,city,lat,lon,query',
      );
      final raw = res.data?.trim() ?? '';
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if ('${decoded['status']}' != 'success') return null;
      final lat = (decoded['lat'] as num?)?.toDouble();
      final lon = (decoded['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return StarlitClientGeo(
        ip: '${decoded['query'] ?? ''}',
        countryCode: '${decoded['countryCode'] ?? ''}'.toUpperCase(),
        country: '${decoded['country'] ?? ''}',
        city: '${decoded['city'] ?? ''}',
        lat: lat,
        lon: lon,
      );
    } catch (_) {
      return null;
    }
  }
}

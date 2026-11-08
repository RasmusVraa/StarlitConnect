import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:starlit_connect/common/constant.dart';
import 'package:starlit_connect/starlit/servers.dart';

class StarlitProbeHit {
  const StarlitProbeHit({
    required this.city,
    required this.network,
    required this.country,
    required this.kind,
    required this.ok,
    this.pingMs,
    this.icmpOk,
    this.icmpMs,
    this.tcpOk,
    this.tcpMs,
  });

  final String city;
  final String network;
  final String country;
  final String kind;
  final bool ok;
  final int? pingMs;
  final bool? icmpOk;
  final int? icmpMs;
  final bool? tcpOk;
  final int? tcpMs;

  factory StarlitProbeHit.fromJson(Map<dynamic, dynamic> json) {
    int? ms(String key) => (json[key] as num?)?.round();
    return StarlitProbeHit(
      city: '${json['city'] ?? ''}'.trim(),
      network: '${json['network'] ?? ''}'.trim(),
      country: '${json['country'] ?? ''}'.toUpperCase(),
      kind: '${json['kind'] ?? ''}',
      ok: json['ok'] == true,
      pingMs: ms('ping_ms'),
      icmpOk: json['icmp_ok'] as bool?,
      icmpMs: ms('icmp_ms'),
      tcpOk: json['tcp_ok'] as bool?,
      tcpMs: ms('tcp_ms'),
    );
  }

  bool get isWhitelist => kind == 'whitelist';
}

class StarlitProbe {
  const StarlitProbe({
    required this.worldOk,
    required this.worldTotal,
    required this.russiaOk,
    required this.russiaTotal,
    required this.history,
    required this.measuredAt,
    required this.hits,
  });

  final int worldOk;
  final int worldTotal;
  final int russiaOk;
  final int russiaTotal;
  final List<double?> history;
  final DateTime? measuredAt;
  final List<StarlitProbeHit> hits;

  factory StarlitProbe.fromJson(Map<dynamic, dynamic> json) {
    int number(String key) => (json[key] as num?)?.round() ?? 0;
    return StarlitProbe(
      worldOk: number('world_ok'),
      worldTotal: number('world_total'),
      russiaOk: number('russia_ok'),
      russiaTotal: number('russia_total'),
      history: [
        for (final h in (json['history'] as List?) ?? const [])
          (h as num?)?.toDouble(),
      ],
      measuredAt: DateTime.tryParse('${json['measured_at'] ?? ''}'),
      hits: [
        for (final h in (json['hits'] as List?) ?? const [])
          if (h is Map) StarlitProbeHit.fromJson(h),
      ],
    );
  }
}

class StarlitPublicNode {
  const StarlitPublicNode({
    required this.id,
    required this.name,
    required this.country,
    required this.whitelist,
    required this.state,
    this.note,
    this.noProbe = false,
    this.probe,
  });

  final String id;
  final String name;
  final String country;
  final bool whitelist;
  final String state;
  final String? note;
  final bool noProbe;
  final StarlitProbe? probe;

  factory StarlitPublicNode.fromJson(Map<String, dynamic> json) {
    final probe = json['probe'];
    return StarlitPublicNode(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      country: '${json['country'] ?? ''}'.toUpperCase(),
      whitelist: json['whitelist'] == true || json['kind'] == 'bypass',
      state: '${json['state'] ?? ''}',
      note: json['note'] as String?,
      noProbe: json['no_probe'] == true,
      probe: probe is Map ? StarlitProbe.fromJson(probe) : null,
    );
  }

  ({double lat, double lon})? get latLon =>
      StarlitServers.countryLatLon(country);
}

/// Публичная карта узлов кабинета (без авторизации).
abstract final class StarlitStatusApi {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$websiteUrl/cabinet/api',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
      headers: const {'Accept': 'application/json'},
    ),
  );

  static Future<List<StarlitPublicNode>> fetchNodes() async =>
      (await fetchStatus()).nodes;

  static Future<StarlitPublicStatus> fetchStatus() async {
    final res = await _dio.get<String>('/public/status');
    final raw = res.data?.trim() ?? '';
    if (raw.isEmpty) return const StarlitPublicStatus();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const StarlitPublicStatus();
    final nodes = decoded['nodes'];
    final list = [
      if (nodes is List)
        for (final n in nodes)
          if (n is Map) StarlitPublicNode.fromJson(Map<String, dynamic>.from(n)),
    ];
    return StarlitPublicStatus(
      available: decoded['available'] == true,
      updatedAt: DateTime.tryParse('${decoded['updated_at'] ?? ''}'),
      bypassProbes: decoded['bypass_probes'] != false,
      nodes: list,
    );
  }
}

class StarlitPublicStatus {
  const StarlitPublicStatus({
    this.available = false,
    this.updatedAt,
    this.bypassProbes = true,
    this.nodes = const [],
  });

  final bool available;
  final DateTime? updatedAt;
  final bool bypassProbes;
  final List<StarlitPublicNode> nodes;
}

double starlitDistanceKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

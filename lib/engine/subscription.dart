import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/share_link.dart';
import 'package:starlit_connect/starlit/hwid.dart';
import 'package:starlit_connect/starlit/servers.dart';

class StarlitSubscriptionResult {
  const StarlitSubscriptionResult({
    required this.nodes,
    this.rawBody = '',
    this.userInfo,
  });

  final List<StarlitNode> nodes;
  final String rawBody;
  final String? userInfo;
}

abstract final class StarlitSubscription {
  /// Remnawave returns Clash for clash.meta UA; ask for Xray / v2ray JSON.
  static const userAgent = 'Xray/1.8 StarlitConnect/1.1';

  static Future<StarlitSubscriptionResult> fetch(String url) async {
    final headers = await StarlitHwid.remnawaveHeaders();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        followRedirects: true,
        responseType: ResponseType.plain,
        headers: {
          ...headers,
          'User-Agent': userAgent,
          'Accept': 'application/json, text/plain, */*',
        },
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );
    final response = await dio.get<String>(url);
    final body = response.data ?? '';
    final userInfo = response.headers.value('subscription-userinfo');
    final nodes = parseBody(body);
    return StarlitSubscriptionResult(
      nodes: [
        for (final n in nodes)
          if (!StarlitServers.isSystem(n.name) && !StarlitServers.isAuto(n.name))
            n,
      ],
      rawBody: body,
      userInfo: userInfo,
    );
  }

  static List<StarlitNode> parseBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];

    // Full Xray config or { outbounds: [...] } / { servers: [...] }
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final fromJson = _fromJson(decoded);
        if (fromJson.isNotEmpty) return fromJson;
      } catch (_) {}
    }

    // Base64 subscription of share links
    final asText = _tryBase64Utf8(trimmed) ?? trimmed;
    final lines = asText
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('#'))
        .toList();

    final nodes = <StarlitNode>[];
    var i = 0;
    for (final line in lines) {
      final node = StarlitShareLink.parse(line, index: i);
      if (node != null) {
        nodes.add(node);
        i++;
      }
    }
    return nodes;
  }

  static List<StarlitNode> _fromJson(Object? decoded) {
    if (decoded is List) {
      final nodes = <StarlitNode>[];
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is String) {
          final n = StarlitShareLink.parse(item, index: i);
          if (n != null) nodes.add(n);
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final n = _nodeFromOutbound(map, i);
          if (n != null) nodes.add(n);
        }
      }
      return nodes;
    }
    if (decoded is! Map) return const [];
    final map = Map<String, dynamic>.from(decoded);

    final outbounds = map['outbounds'];
    if (outbounds is List) {
      final nodes = <StarlitNode>[];
      var i = 0;
      for (final item in outbounds) {
        if (item is! Map) continue;
        final o = Map<String, dynamic>.from(item);
        final protocol = '${o['protocol'] ?? ''}'.toLowerCase();
        if (protocol == 'freedom' ||
            protocol == 'blackhole' ||
            protocol == 'dns' ||
            protocol == 'block' ||
            protocol == 'direct') {
          continue;
        }
        final tag = '${o['tag'] ?? ''}';
        if (tag == 'direct' || tag == 'block' || tag == 'api') continue;
        final n = _nodeFromOutbound(o, i);
        if (n != null) {
          nodes.add(n);
          i++;
        }
      }
      if (nodes.isNotEmpty) return nodes;
    }

    // Remnawave / Happ style: { "serverDescription": ..., "outbounds": ... }
    // already handled. Some panels nest under "config".
    final config = map['config'];
    if (config != null) return _fromJson(config);
    return const [];
  }

  static StarlitNode? _nodeFromOutbound(Map<String, dynamic> o, int index) {
    final protocol = '${o['protocol'] ?? ''}';
    if (protocol.isEmpty) return null;
    var tag = '${o['tag'] ?? 'proxy-$index'}';
    if (tag.isEmpty) tag = 'proxy-$index';
    o = StarlitShareLink.normalizeOutbound(
      Map<String, dynamic>.from(o)..['tag'] = tag,
    );

    String? address;
    int? port;
    final settings = o['settings'];
    if (settings is Map) {
      address = settings['address']?.toString();
      port = int.tryParse('${settings['port']}');
      final vnext = settings['vnext'];
      final servers = settings['servers'];
      if (vnext is List && vnext.isNotEmpty && vnext.first is Map) {
        final s = Map<String, dynamic>.from(vnext.first as Map);
        address ??= '${s['address'] ?? ''}';
        port ??= int.tryParse('${s['port']}');
      } else if (servers is List && servers.isNotEmpty && servers.first is Map) {
        final s = Map<String, dynamic>.from(servers.first as Map);
        address ??= '${s['address'] ?? ''}';
        port ??= int.tryParse('${s['port']}');
      }
    }

    final name = tag.startsWith('proxy-') && o['remark'] != null
        ? '${o['remark']}'
        : (o['remark'] != null ? '${o['remark']}' : tag);

    return StarlitNode(
      id: tag,
      name: name,
      outbound: o,
      address: address,
      port: port,
      protocol: '${o['protocol'] ?? protocol}',
    );
  }

  static String? _tryBase64Utf8(String body) {
    try {
      var b64 = body.replaceAll(RegExp(r'\s'), '');
      final pad = b64.length % 4;
      if (pad != 0) b64 += '=' * (4 - pad);
      final decoded = utf8.decode(base64Decode(b64));
      if (decoded.contains('://') || decoded.trimLeft().startsWith('{')) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}

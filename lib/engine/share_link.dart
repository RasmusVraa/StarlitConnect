import 'dart:convert';

import 'package:starlit_connect/engine/node.dart';

/// Parse common Remnawave share links into Xray outbound objects.
abstract final class StarlitShareLink {
  static StarlitNode? parse(String raw, {int index = 0}) {
    final line = raw.trim();
    if (line.isEmpty) return null;
    final uri = Uri.tryParse(line);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    return switch (scheme) {
      'vless' => _vless(uri, index),
      'vmess' => _vmess(uri, index),
      'trojan' => _trojan(uri, index),
      'ss' || 'shadowsocks' => _ss(uri, index),
      'hysteria2' || 'hy2' => _hy2(uri, index),
      _ => null,
    };
  }

  static String _name(Uri uri, String fallback) {
    final frag = uri.fragment.trim();
    if (frag.isEmpty) return fallback;
    try {
      return Uri.decodeComponent(frag);
    } catch (_) {
      return frag;
    }
  }

  static Map<String, String> _q(Uri uri) =>
      uri.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), v));

  static StarlitNode _vless(Uri uri, int index) {
    final q = _q(uri);
    final uuid = uri.userInfo;
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final name = _name(uri, 'VLESS-$index');
    final security = (q['security'] ?? 'none').toLowerCase();
    final network = (q['type'] ?? q['network'] ?? 'tcp').toLowerCase();
    final stream = <String, dynamic>{'network': network};
    if (security == 'reality' || security == 'tls') {
      stream['security'] = security;
      if (security == 'tls') {
        stream['tlsSettings'] = {
          'serverName': q['sni'] ?? q['host'] ?? host,
          'fingerprint': q['fp'] ?? 'chrome',
          if ((q['alpn'] ?? '').isNotEmpty)
            'alpn': q['alpn']!.split(',').map((e) => e.trim()).toList(),
          'allowInsecure': q['allowinsecure'] == '1' || q['insecure'] == '1',
        };
      } else {
        stream['realitySettings'] = {
          'serverName': q['sni'] ?? host,
          'fingerprint': q['fp'] ?? 'chrome',
          'publicKey': q['pbk'] ?? '',
          'shortId': q['sid'] ?? '',
          if ((q['spx'] ?? '').isNotEmpty) 'spiderX': q['spx'],
        };
      }
    }
    if (network == 'ws') {
      stream['wsSettings'] = {
        'path': q['path'] ?? '/',
        'headers': {
          if ((q['host'] ?? '').isNotEmpty) 'Host': q['host'],
        },
      };
    } else if (network == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': q['servicename'] ?? q['serviceName'] ?? '',
      };
    } else if (network == 'xhttp' || network == 'splithttp') {
      stream['network'] = 'xhttp';
      stream['xhttpSettings'] = {
        'path': q['path'] ?? '/',
        'host': q['host'] ?? '',
        'mode': q['mode'] ?? 'auto',
      };
    }
    final tag = 'proxy-$index';
    final outbound = <String, dynamic>{
      'tag': tag,
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': host,
            'port': port,
            'users': [
              {
                'id': uuid,
                'encryption': q['encryption'] ?? 'none',
                if ((q['flow'] ?? '').isNotEmpty) 'flow': q['flow'],
              },
            ],
          },
        ],
      },
      'streamSettings': stream,
    };
    return StarlitNode(
      id: tag,
      name: name,
      outbound: outbound,
      address: host,
      port: port,
      protocol: 'vless',
    );
  }

  static StarlitNode? _vmess(Uri uri, int index) {
    // vmess://base64(json)
    try {
      var b64 = uri.toString().substring('vmess://'.length);
      final pad = b64.length % 4;
      if (pad != 0) b64 += '=' * (4 - pad);
      final json =
          jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
      final host = '${json['add'] ?? ''}';
      final port = int.tryParse('${json['port']}') ?? 443;
      final name = '${json['ps'] ?? 'VMess-$index'}';
      final tag = 'proxy-$index';
      final network = '${json['net'] ?? 'tcp'}';
      final outbound = <String, dynamic>{
        'tag': tag,
        'protocol': 'vmess',
        'settings': {
          'vnext': [
            {
              'address': host,
              'port': port,
              'users': [
                {
                  'id': '${json['id']}',
                  'alterId': int.tryParse('${json['aid']}') ?? 0,
                  'security': '${json['scy'] ?? 'auto'}',
                },
              ],
            },
          ],
        },
        'streamSettings': {
          'network': network,
          if ('${json['tls']}' == 'tls') 'security': 'tls',
          if ('${json['tls']}' == 'tls')
            'tlsSettings': {
              'serverName': '${json['sni'] ?? json['host'] ?? host}',
            },
        },
      };
      return StarlitNode(
        id: tag,
        name: name,
        outbound: outbound,
        address: host,
        port: port,
        protocol: 'vmess',
      );
    } catch (_) {
      return null;
    }
  }

  static StarlitNode _trojan(Uri uri, int index) {
    final q = _q(uri);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final name = _name(uri, 'Trojan-$index');
    final tag = 'proxy-$index';
    final outbound = <String, dynamic>{
      'tag': tag,
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': host,
            'port': port,
            'password': uri.userInfo,
          },
        ],
      },
      'streamSettings': {
        'network': (q['type'] ?? 'tcp').toLowerCase(),
        'security': 'tls',
        'tlsSettings': {
          'serverName': q['sni'] ?? host,
          'fingerprint': q['fp'] ?? 'chrome',
          'allowInsecure': q['allowinsecure'] == '1',
        },
      },
    };
    return StarlitNode(
      id: tag,
      name: name,
      outbound: outbound,
      address: host,
      port: port,
      protocol: 'trojan',
    );
  }

  static StarlitNode? _ss(Uri uri, int index) {
    try {
      String method;
      String password;
      String host;
      int port;
      if (uri.userInfo.contains(':')) {
        method = Uri.decodeComponent(uri.userInfo.split(':').first);
        password = Uri.decodeComponent(uri.userInfo.split(':').skip(1).join(':'));
        host = uri.host;
        port = uri.hasPort ? uri.port : 443;
      } else {
        var b64 = uri.userInfo;
        final pad = b64.length % 4;
        if (pad != 0) b64 += '=' * (4 - pad);
        final decoded = utf8.decode(base64Decode(b64));
        final at = decoded.lastIndexOf('@');
        final cred = decoded.substring(0, at);
        final addr = decoded.substring(at + 1);
        method = cred.split(':').first;
        password = cred.split(':').skip(1).join(':');
        final hp = addr.split(':');
        host = hp.first;
        port = int.tryParse(hp.last) ?? 443;
      }
      final name = _name(uri, 'SS-$index');
      final tag = 'proxy-$index';
      return StarlitNode(
        id: tag,
        name: name,
        outbound: {
          'tag': tag,
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address': host,
                'port': port,
                'method': method,
                'password': password,
              },
            ],
          },
        },
        address: host,
        port: port,
        protocol: 'shadowsocks',
      );
    } catch (_) {
      return null;
    }
  }

  static StarlitNode _hy2(Uri uri, int index) {
    final q = _q(uri);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final name = _name(uri, 'HY2-$index');
    final tag = 'proxy-$index';
    final password = Uri.decodeComponent(uri.userInfo);
    // Xray 26+ uses protocol "hysteria" + stream method "hysteria",
    // not the sing-box-style "hysteria2" / servers[] shape.
    final outbound = <String, dynamic>{
      'tag': tag,
      'protocol': 'hysteria',
      'settings': {
        'version': 2,
        'address': host,
        'port': port,
      },
      'streamSettings': {
        'network': 'hysteria',
        'security': 'tls',
        'tlsSettings': {
          'serverName': q['sni'] ?? q['host'] ?? host,
          'allowInsecure':
              q['insecure'] == '1' || q['allowinsecure'] == '1',
          if ((q['alpn'] ?? '').isNotEmpty)
            'alpn': q['alpn']!.split(',').map((e) => e.trim()).toList(),
          if ((q['fp'] ?? '').isNotEmpty) 'fingerprint': q['fp'],
        },
        'hysteriaSettings': {
          'version': 2,
          'auth': password,
          'udpIdleTimeout': 60,
        },
      },
    };
    final up = q['up'] ?? q['upmbps'];
    final down = q['down'] ?? q['downmbps'];
    if ((up ?? '').isNotEmpty || (down ?? '').isNotEmpty) {
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      stream['finalmask'] = {
        'quicParams': {
          if ((up ?? '').isNotEmpty) 'brutalUp': _mbps(up!),
          if ((down ?? '').isNotEmpty) 'brutalDown': _mbps(down!),
        },
      };
    }
    return StarlitNode(
      id: tag,
      name: name,
      outbound: outbound,
      address: host,
      port: port,
      protocol: 'hysteria',
    );
  }

  static String _mbps(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.endsWith('mbps') || t.endsWith('gbps') || t.endsWith('kbps')) {
      return t;
    }
    return '${t}mbps';
  }

  /// Rewrite legacy/sing-box hysteria2 outbounds into Xray 26+ shape.
  static Map<String, dynamic> normalizeOutbound(Map<String, dynamic> raw) {
    final o = Map<String, dynamic>.from(raw);
    final protocol = '${o['protocol'] ?? ''}'.toLowerCase();
    if (protocol != 'hysteria2' && protocol != 'hy2' && protocol != 'hysteria') {
      return o;
    }

    final settings = o['settings'];
    String? address;
    int? port;
    String? auth;
    if (settings is Map) {
      address = settings['address']?.toString();
      port = int.tryParse('${settings['port']}');
      auth = settings['auth']?.toString() ?? settings['password']?.toString();
      final servers = settings['servers'];
      if (servers is List && servers.isNotEmpty && servers.first is Map) {
        final s = Map<String, dynamic>.from(servers.first as Map);
        address ??= s['address']?.toString();
        port ??= int.tryParse('${s['port']}');
        auth ??= s['password']?.toString() ?? s['auth']?.toString();
      }
    }

    final streamIn = o['streamSettings'] is Map
        ? Map<String, dynamic>.from(o['streamSettings'] as Map)
        : <String, dynamic>{};
    final tlsIn = streamIn['tlsSettings'] is Map
        ? Map<String, dynamic>.from(streamIn['tlsSettings'] as Map)
        : <String, dynamic>{};
    final hyIn = streamIn['hysteriaSettings'] is Map
        ? Map<String, dynamic>.from(streamIn['hysteriaSettings'] as Map)
        : <String, dynamic>{};
    auth ??= hyIn['auth']?.toString();

    if (address == null || address.isEmpty || port == null) return o;

    return {
      ...o,
      'protocol': 'hysteria',
      'settings': {
        'version': 2,
        'address': address,
        'port': port,
      },
      'streamSettings': {
        'network': 'hysteria',
        'security': streamIn['security'] ?? 'tls',
        'tlsSettings': {
          'serverName': tlsIn['serverName'] ?? address,
          if (tlsIn['allowInsecure'] == true) 'allowInsecure': true,
          if (tlsIn['fingerprint'] != null) 'fingerprint': tlsIn['fingerprint'],
          if (tlsIn['alpn'] != null) 'alpn': tlsIn['alpn'],
        },
        'hysteriaSettings': {
          'version': 2,
          'auth': auth ?? '',
          'udpIdleTimeout': hyIn['udpIdleTimeout'] ?? 60,
        },
        if (streamIn['finalmask'] != null) 'finalmask': streamIn['finalmask'],
      },
    };
  }
}

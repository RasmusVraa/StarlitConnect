import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/share_link.dart';

/// Builds a minimal Xray config: mixed inbound + active proxy + routing.
abstract final class StarlitXrayConfig {
  static const mixedTag = 'mixed-in';
  static const proxyTag = 'proxy';
  static const directTag = 'direct';
  static const blockTag = 'block';
  static const apiTag = 'api';
  static const defaultMixedPort = 17890;
  static const defaultApiPort = 17891;

  static Map<String, dynamic> build({
    required StarlitNode node,
    required List<Map<String, dynamic>> routingRules,
    required String domainStrategy,
    int mixedPort = defaultMixedPort,
    int apiPort = defaultApiPort,
    bool tun = false,
    Map<String, dynamic>? dns,
  }) {
    final outbound = StarlitShareLink.normalizeOutbound(
      Map<String, dynamic>.from(node.outbound),
    );
    outbound['tag'] = proxyTag;

    final inbounds = <Map<String, dynamic>>[
      {
        'tag': mixedTag,
        'port': mixedPort,
        'listen': '127.0.0.1',
        'protocol': 'mixed',
        'settings': {'udp': true},
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
          'routeOnly': true,
        },
      },
      {
        'tag': apiTag,
        'listen': '127.0.0.1',
        'port': apiPort,
        'protocol': 'dokodemo-door',
        'settings': {'address': '127.0.0.1'},
      },
    ];

    if (tun) {
      // Xray 26+ TUN API (not sing-box autoRoute/stack).
      inbounds.add({
        'tag': 'tun-in',
        'protocol': 'tun',
        'settings': {
          'name': 'Starlit',
          'desc': 'Starlit',
          'mtu': 1500,
          'gateway': ['172.19.0.1/30'],
          'dns': ['1.1.1.1', '8.8.8.8'],
          'autoSystemRoutingTable': ['0.0.0.0/0'],
          'autoOutboundsInterface': 'auto',
        },
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
          'routeOnly': true,
        },
      });
    }

    final rules = <Map<String, dynamic>>[
      {
        'type': 'field',
        'inboundTag': [apiTag],
        'outboundTag': apiTag,
      },
      ...routingRules,
    ];

    return {
      'log': {'loglevel': 'warning'},
      'stats': <String, dynamic>{},
      'api': {
        'tag': apiTag,
        'services': ['StatsService'],
      },
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        },
      },
      if (dns != null) 'dns': dns,
      'inbounds': inbounds,
      'outbounds': [
        outbound,
        {
          'tag': directTag,
          'protocol': 'freedom',
          'settings': <String, dynamic>{},
        },
        {
          'tag': blockTag,
          'protocol': 'blackhole',
          'settings': <String, dynamic>{},
        },
      ],
      'routing': {
        'domainStrategy': domainStrategy,
        'rules': rules,
      },
    };
  }
}

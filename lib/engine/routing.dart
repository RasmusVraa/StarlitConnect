import 'package:starlit_connect/engine/config.dart';
import 'package:starlit_connect/engine/happ_routing.dart';
import 'package:starlit_connect/starlit/prefs.dart';

/// Starlit smart/all/selected → Xray routing.rules (+ optional Happ profile).
abstract final class StarlitXrayRouting {
  static const serviceDomains = <String, List<String>>{
    'youtube': [
      'youtube.com',
      'youtu.be',
      'googlevideo.com',
      'ytimg.com',
      'ggpht.com',
      'youtube-nocookie.com',
    ],
    'instagram': ['instagram.com', 'cdninstagram.com', 'fbcdn.net'],
    'telegram': [
      'telegram.org',
      't.me',
      'telegra.ph',
      'telesco.pe',
      'tdesktop.com',
    ],
    'whatsapp': ['whatsapp.com', 'whatsapp.net', 'wa.me'],
    'tiktok': [
      'tiktok.com',
      'tiktokv.com',
      'tiktokcdn.com',
      'byteoversea.com',
    ],
    'discord': [
      'discord.com',
      'discord.gg',
      'discordapp.com',
      'discordapp.net',
      'discord.media',
    ],
    'chatgpt': [
      'openai.com',
      'chatgpt.com',
      'oaistatic.com',
      'oaiusercontent.com',
    ],
    'gemini': [
      'gemini.google.com',
      'bard.google.com',
      'ai.google.dev',
      'generativelanguage.googleapis.com',
    ],
    'claude': ['anthropic.com', 'claude.ai', 'claude.com'],
    'x': ['x.com', 'twitter.com', 'twimg.com', 't.co'],
    'twitch': ['twitch.tv', 'ttvnw.net', 'jtvnw.net'],
    'cloudflare': [
      'cloudflare.com',
      'cloudflare-dns.com',
      'cloudflareinsights.com',
    ],
  };

  static const _telegramCidrs = [
    '91.108.4.0/22',
    '91.108.8.0/22',
    '91.108.12.0/22',
    '91.108.16.0/22',
    '91.108.56.0/22',
    '149.154.160.0/20',
  ];

  static const _private = [
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '127.0.0.0/8',
    '169.254.0.0/16',
    'fc00::/7',
    'fe80::/10',
    '::1/128',
  ];

  static Future<({List<Map<String, dynamic>> rules, String strategy, Map<String, dynamic>? dns, HappRoutingProfile? happ})>
      build() async {
    // Modes/services UI removed: always full-tunnel base, then app routing.
    const mode = 'all';
    final happOn = await StarlitPrefs.happRouting();
    final sites = await StarlitPrefs.customSites();
    final processRules = await _processRules();
    final extraProxy = [...sites];

    if (happOn) {
      final happ = await _loadHapp();
      await HappGeoAssets.ensure(happ);
      // Force GlobalProxy: RU direct lists used to make "IP check" sites show
      // the home IP even while "connected".
      final profile = HappRoutingProfile(
        name: happ.name,
        globalProxy: true,
        routeOrder: happ.routeOrder,
        domainStrategy: happ.domainStrategy,
        geoipUrl: happ.geoipUrl,
        geositeUrl: happ.geositeUrl,
        directSites: const [],
        directIp: happ.directIp
            .where((e) => e.startsWith('geoip:private') || e.contains('/'))
            .toList(),
        proxySites: happ.proxySites,
        proxyIp: happ.proxyIp,
        blockSites: happ.blockSites,
        blockIp: happ.blockIp,
        remoteDnsDomain: happ.remoteDnsDomain,
        remoteDnsIp: happ.remoteDnsIp,
        domesticDnsIp: happ.domesticDnsIp,
        dnsHosts: happ.dnsHosts,
      );
      return (
        rules: _mergeAppRules(
          profile.toXrayRules(extraProxyDomains: extraProxy),
          processRules,
        ),
        strategy: profile.domainStrategy,
        dns: profile.toXrayDns(),
        happ: profile,
      );
    }

    return (
      rules: _mergeAppRules(
        await _legacyRules(mode, const {}, sites),
        processRules,
      ),
      strategy: 'AsIs',
      dns: null,
      happ: null,
    );
  }

  /// Xray `process` match (name, absolute path, or folder). Needs TUN for most apps.
  static Future<({String mode, List<Map<String, dynamic>> rules})>
      _processRules() async {
    final mode = await StarlitPrefs.appRouteMode();
    if (mode == 'off') return (mode: mode, rules: const <Map<String, dynamic>>[]);
    final programs = await StarlitPrefs.programs();
    if (programs.isEmpty) return (mode: mode, rules: const <Map<String, dynamic>>[]);
    final tag = mode == 'direct'
        ? StarlitXrayConfig.directTag
        : StarlitXrayConfig.proxyTag;
    return (
      mode: mode,
      rules: [
        {
          'type': 'field',
          'process': programs,
          'outboundTag': tag,
        },
      ],
    );
  }

  static List<Map<String, dynamic>> _mergeAppRules(
    List<Map<String, dynamic>> base,
    ({String mode, List<Map<String, dynamic>> rules}) process,
  ) {
    if (process.mode == 'off' || process.rules.isEmpty) return base;
    // Exclusive: only listed apps use VPN; everything else goes direct.
    if (process.mode == 'proxy') {
      return [
        ...process.rules,
        {
          'type': 'field',
          'ip': _private,
          'outboundTag': StarlitXrayConfig.directTag,
        },
        {
          'type': 'field',
          'port': '0-65535',
          'outboundTag': StarlitXrayConfig.directTag,
        },
      ];
    }
    // Selected apps bypass VPN; remaining traffic keeps site/Happ rules.
    return [...process.rules, ...base];
  }

  static Future<HappRoutingProfile> _loadHapp() async {
    final custom = await StarlitPrefs.happRoutingLink();
    if (custom != null && custom.isNotEmpty) {
      final parsed = HappRoutingProfile.parseLink(custom);
      if (parsed != null) return parsed;
    }
    return HappRoutingProfile.bundled;
  }

  static Future<List<Map<String, dynamic>>> _legacyRules(
    String mode,
    Set<String> services,
    List<String> sites,
  ) async {
    final rules = <Map<String, dynamic>>[
      {
        'type': 'field',
        'ip': _private,
        'outboundTag': StarlitXrayConfig.directTag,
      },
      {
        'type': 'field',
        'domain': ['domain:local', 'domain:localhost'],
        'outboundTag': StarlitXrayConfig.directTag,
      },
    ];

    final proxyDomains = <String>[for (final site in sites) 'domain:$site'];
    final proxyIps = <String>[];
    if (mode != 'all') {
      for (final id in services) {
        for (final d in serviceDomains[id] ?? const <String>[]) {
          proxyDomains.add('domain:$d');
        }
        if (id == 'telegram') proxyIps.addAll(_telegramCidrs);
      }
    }
    if (proxyDomains.isNotEmpty) {
      rules.add({
        'type': 'field',
        'domain': proxyDomains,
        'outboundTag': StarlitXrayConfig.proxyTag,
      });
    }
    if (proxyIps.isNotEmpty) {
      rules.add({
        'type': 'field',
        'ip': proxyIps,
        'outboundTag': StarlitXrayConfig.proxyTag,
      });
    }

    switch (mode) {
      case 'all':
        rules.add({
          'type': 'field',
          'port': '0-65535',
          'outboundTag': StarlitXrayConfig.proxyTag,
        });
      case 'selected':
        rules.add({
          'type': 'field',
          'port': '0-65535',
          'outboundTag': StarlitXrayConfig.directTag,
        });
      default:
        rules.add({
          'type': 'field',
          'domain': const [
            'domain:ru',
            'domain:su',
            'domain:xn--p1ai',
            'domain:yandex.com',
            'domain:yandex.net',
            'domain:yastatic.net',
            'domain:ya.ru',
            'domain:vk.com',
            'domain:vk.me',
          ],
          'outboundTag': StarlitXrayConfig.directTag,
        });
        rules.add({
          'type': 'field',
          'port': '0-65535',
          'outboundTag': StarlitXrayConfig.proxyTag,
        });
    }
    return rules;
  }
}

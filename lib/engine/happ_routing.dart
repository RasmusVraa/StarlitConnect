import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:starlit_connect/engine/config.dart';
import 'package:starlit_connect/engine/paths.dart';

/// Happ / Starlit routing profile (happ://routing/onadd/<base64json>).
class HappRoutingProfile {
  HappRoutingProfile({
    required this.name,
    required this.globalProxy,
    required this.routeOrder,
    required this.domainStrategy,
    required this.geoipUrl,
    required this.geositeUrl,
    required this.directSites,
    required this.directIp,
    required this.proxySites,
    required this.proxyIp,
    required this.blockSites,
    required this.blockIp,
    this.remoteDnsDomain = '',
    this.remoteDnsIp = '',
    this.domesticDnsIp = '',
    this.dnsHosts = const {},
  });

  final String name;
  final bool globalProxy;
  final String routeOrder;
  final String domainStrategy;
  final String geoipUrl;
  final String geositeUrl;
  final List<String> directSites;
  final List<String> directIp;
  final List<String> proxySites;
  final List<String> proxyIp;
  final List<String> blockSites;
  final List<String> blockIp;
  final String remoteDnsDomain;
  final String remoteDnsIp;
  final String domesticDnsIp;
  final Map<String, String> dnsHosts;

  factory HappRoutingProfile.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) {
      final v = json[key];
      if (v is! List) return const [];
      return [for (final e in v) '$e'];
    }

    Map<String, String> hosts() {
      final v = json['DnsHosts'];
      if (v is! Map) return const {};
      return {
        for (final e in v.entries) '${e.key}': '${e.value}',
      };
    }

    bool asBool(Object? v) =>
        v == true || '$v'.toLowerCase() == 'true' || '$v' == '1';

    return HappRoutingProfile(
      name: '${json['Name'] ?? 'Starlit'}',
      globalProxy: asBool(json['GlobalProxy'] ?? true),
      routeOrder: '${json['RouteOrder'] ?? 'block-proxy-direct'}',
      domainStrategy: '${json['DomainStrategy'] ?? 'IPIfNonMatch'}',
      geoipUrl: '${json['Geoipurl'] ?? ''}',
      geositeUrl: '${json['Geositeurl'] ?? ''}',
      directSites: list('DirectSites'),
      directIp: list('DirectIp'),
      proxySites: list('ProxySites'),
      proxyIp: list('ProxyIp'),
      blockSites: list('BlockSites'),
      blockIp: list('BlockIp'),
      remoteDnsDomain: '${json['RemoteDNSDomain'] ?? ''}',
      remoteDnsIp: '${json['RemoteDNSIP'] ?? ''}',
      domesticDnsIp: '${json['DomesticDNSIP'] ?? ''}',
      dnsHosts: hosts(),
    );
  }

  static HappRoutingProfile? parseLink(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      if (s.startsWith('{')) {
        return HappRoutingProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(s) as Map),
        );
      }
      final uri = Uri.tryParse(s);
      String? b64;
      if (uri != null && uri.scheme == 'happ') {
        // happ://routing/onadd/<base64>
        final segs = uri.pathSegments;
        if (segs.isNotEmpty) {
          b64 = segs.last;
        } else if (uri.host.isNotEmpty) {
          b64 = uri.path.replaceFirst('/', '');
        }
        // Also support happ://routing/onadd/BASE64 in opaque form
        final full = s.replaceFirst(RegExp(r'^happ://routing/onadd/'), '');
        if (full.isNotEmpty && !full.contains('://')) b64 = full;
      } else if (RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(s) && s.length > 40) {
        b64 = s;
      }
      if (b64 == null || b64.isEmpty) return null;
      var normalized = b64.replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      if (pad != 0) normalized += '=' * (4 - pad);
      final decoded = utf8.decode(base64Decode(normalized));
      return HappRoutingProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(decoded) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Default Starlit Happ profile (YTM / RU direct + YouTube proxy + ads block).
  static HappRoutingProfile get bundled =>
      HappRoutingProfile.parseLink(_bundledLink)!;

  static const _bundledLink =
      'happ://routing/onadd/eyJOYW1lIjoiU3RhcmxpdFZQTi1ZVE0tRGVidWciLCJHbG9iYWxQcm94eSI6InRydWUiLCJSb3V0ZU9yZGVyIjoiYmxvY2stcHJveHktZGlyZWN0IiwiUmVtb3RlRE5TVHlwZSI6IkRvSCIsIlJlbW90ZUROU0RvbWFpbiI6Imh0dHBzOi8vY2xvdWRmbGFyZS1kbnMuY29tL2Rucy1xdWVyeSIsIlJlbW90ZUROU0lQIjoiMS4xLjEuMSIsIkRvbWVzdGljRE5TVHlwZSI6IkRvVSIsIkRvbWVzdGljRE5TRG9tYWluIjoiIiwiRG9tZXN0aWNETlNJUCI6Ijc3Ljg4LjguOCIsIkdlb2lwdXJsIjoiaHR0cHM6Ly9nY29yZS5qc2RlbGl2ci5uZXQvZ2gvUmFzbXVzVnJhYS9zdGFybGl0LXJvdXRpbmdAdjUvcmVsZWFzZS9nZW9pcC5kYXQiLCJHZW9zaXRldXJsIjoiaHR0cHM6Ly9nY29yZS5qc2RlbGl2ci5uZXQvZ2gvUmFzbXVzVnJhYS9zdGFybGl0LXJvdXRpbmdAdjUvcmVsZWFzZS9nZW9zaXRlLmRhdCIsIkxhc3RVcGRhdGVkIjoiMTc5Mzk4ODMzNyIsIkRuc0hvc3RzIjp7ImNsb3VkZmxhcmUtZG5zLmNvbSI6IjEuMS4xLjEiLCJkbnMuZ29vZ2xlIjoiOC44LjguOCJ9LCJEaXJlY3RTaXRlcyI6WyJnZW9zaXRlOmNhdGVnb3J5LXJ1IiwiZ2Vvc2l0ZTp0bGQtcnUiLCJnZW9zaXRlOm96b24iLCJnZW9zaXRlOndpbGRiZXJyaWVzIiwiZ2Vvc2l0ZTpjYXRlZ29yeS1iYW5rLXJ1IiwiZ2Vvc2l0ZTpydS1iYW5rcyIsImdlb3NpdGU6Y2F0ZWdvcnktZWNvbW1lcmNlLXJ1IiwiZ2Vvc2l0ZTpzYmVyIiwiZ2Vvc2l0ZTp0YmFuay1ydSIsImdlb3NpdGU6eWFuZGV4IiwiZ2Vvc2l0ZTp3aGl0ZWxpc3QiLCJnZW9zaXRlOnByaXZhdGUiLCJkb21haW46b3pvbi5ydSIsImRvbWFpbjpvem9uZS5ydSIsImRvbWFpbjpvem9uLmNvbSIsImRvbWFpbjpvem9uLmFwcCIsImRvbWFpbjpvem9uLmJ5IiwiZG9tYWluOm96b24ua3oiLCJkb21haW46b3pvbi50cmF2ZWwiLCJkb21haW46b3pvbi50ZWNoIiwiZG9tYWluOm96b24uZXhwcmVzcyIsImRvbWFpbjpvem9uLmdsb2JhbCIsImRvbWFpbjpvem9udXNlcmNvbnRlbnQuY29tIiwiZG9tYWluOm96b25nbG9iYWxldmVudHMuY29tIiwiZG9tYWluOm96b25ydS5tZSIsImRvbWFpbjpvem9ucnUuY29tIiwiZG9tYWluOm8zLnJ1IiwiZG9tYWluOm8zdC5ydSIsImRvbWFpbjp3aWxkYmVycmllcy5ydSIsImRvbWFpbjp3aWxkYmVycmllcy5ieSIsImRvbWFpbjp3aWxkYmVycmllcy5reiIsImRvbWFpbjp3Yi5ydSIsImRvbWFpbjp3Yi5reiIsImRvbWFpbjp3YmJhc2tldC5ydSIsImRvbWFpbjp3Yi1iYXNrZXQucnUiLCJkb21haW46Z2VvYmFza2V0LnJ1IiwiZG9tYWluOndic3RhdGljLm5ldCIsImRvbWFpbjp3YnN0YXRpYy5ydSIsImRvbWFpbjp3YmNvbnRlbnQubmV0IiwiZG9tYWluOnBheXdiLmNvbSIsImRvbWFpbjpwYXl3Yi5ydSIsImRvbWFpbjp3YnBheS5ydSIsImRvbWFpbjp3Yi1iYW5rLnJ1IiwiZG9tYWluOndpYmVzLmNvbSIsImRvbWFpbjp3aWJlcy5ydSIsImRvbWFpbjpyd2IucnUiLCJkb21haW46d2J3aC50ZWNoIiwiZG9tYWluOnNiZXJiYW5rLnJ1IiwiZG9tYWluOnNiZXIucnUiLCJkb21haW46c2JlcmJhbmsuY29tIiwiZG9tYWluOnNiZXIuY29tIiwiZG9tYWluOm9ubGluZS5zYmVyYmFuay5ydSIsImRvbWFpbjp0YmFuay5ydSIsImRvbWFpbjp0aW5rb2ZmLnJ1IiwiZG9tYWluOnQtYmFuay1hcHAucnUiLCJkb21haW46dGJhbmstb25saW5lLmNvbSIsImRvbWFpbjpjZG4tdGlua29mZi5ydSIsImRvbWFpbjp2dGIucnUiLCJkb21haW46dnRiLmNvbSIsImRvbWFpbjphbGZhYmFuay5ydSIsImRvbWFpbjphbGZhYmFuay5jb20iLCJkb21haW46YWxmYS1iYW5rLmNvbSIsImRvbWFpbjpnYXpwcm9tYmFuay5ydSIsImRvbWFpbjpnYXpwcm9tYmFuay50ZWNoIiwiZG9tYWluOnJhaWZmZWlzZW4ucnUiLCJkb21haW46cHNiYW5rLnJ1IiwiZG9tYWluOnJzaGIucnUiLCJkb21haW46b3Blbi5ydSIsImRvbWFpbjpzb3Zjb21iYW5rLnJ1IiwiZG9tYWluOnBvY2h0YWJhbmsucnUiLCJkb21haW46bWtiLnJ1IiwiZG9tYWluOmFrYmFycy5ydSIsImRvbWFpbjpuc3BrLnJ1IiwiZG9tYWluOm1pcm9ubGluZS5ydSIsImRvbWFpbjp5b29tb25leS5ydSIsImRvbWFpbjpxaXdpLmNvbSIsImRvbWFpbjphcHBzZmx5ZXIuY29tIiwiZG9tYWluOmFwcHNmbHllcnNkay5jb20iLCJkb21haW46YWRqdXN0LmNvbSIsImRvbWFpbjphcHBtZXRyaWNhLnlhbmRleC5ydSIsImRvbWFpbjphcHBtZXRyaWNhLnlhbmRleC5uZXQiLCJkb21haW46eWFuZGV4LnJ1IiwiZG9tYWluOnlhLnJ1IiwiZG9tYWluOnlhbmRleC5uZXQiLCJkb21haW46eWFzdGF0aWMubmV0IiwiZG9tYWluOmdvc3VzbHVnaS5ydSIsImRvbWFpbjpuYWxvZy5ydSJdLCJEaXJlY3RJcCI6WyJnZW9pcDpydSIsImdlb2lwOmRpcmVjdCIsImdlb2lwOnByaXZhdGUiLCIxMC4wLjAuMC84IiwiMTAwLjY0LjAuMC8xMCIsIjE3Mi4xNi4wLjAvMTIiLCIxOTIuMTY4LjAuMC8xNiIsIjEyNy4wLjAuMC84IiwiMTY5LjI1NC4wLjAvMTYiLCIyMjQuMC4wLjAvNCIsIjI1NS4yNTUuMjU1LjI1NSJdLCJQcm94eVNpdGVzIjpbImdlb3NpdGU6eW91dHViZSIsImdlb3NpdGU6Z29vZ2xlLXBsYXkiLCJnZW9zaXRlOmdvb2dsZS1kZWVwbWluZCIsImRvbWFpbjpnb29nbGV2aWRlby5jb20iLCJkb21haW46Z29vZ2xlYXBpcy5jb20iLCJkb21haW46Z3Z0MS5jb20iLCJkb21haW46Z3Z0Mi5jb20iLCJkb21haW46bXVzaWMueW91dHViZS5jb20iLCJkb21haW46eW91dHViZS5jb20iLCJkb21haW46eXRpbWcuY29tIiwiZG9tYWluOmdncGh0LmNvbSIsImRvbWFpbjpnb29nbGUuY29tIiwiZG9tYWluOmdzdGF0aWMuY29tIiwiZG9tYWluOmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImRvbWFpbjpsaWNlbnNlcy5kcm0uZ29vZ2xlLmNvbSIsImRvbWFpbjp3aWRldmluZS5jb20iXSwiUHJveHlJcCI6W10sIkJsb2NrU2l0ZXMiOlsiZG9tYWluOmRvdWJsZWNsaWNrLm5ldCIsImRvbWFpbjpnb29nbGVzeW5kaWNhdGlvbi5jb20iLCJkb21haW46Z29vZ2xlYWRzZXJ2aWNlcy5jb20iLCJkb21haW46YWRueHMuY29tIiwiZG9tYWluOmFkc3J2ci5vcmciLCJkb21haW46cnViaWNvbnByb2plY3QuY29tIiwiZG9tYWluOnB1Ym1hdGljLmNvbSIsImRvbWFpbjpvcGVueC5uZXQiLCJkb21haW46Y3JpdGVvLmNvbSIsImRvbWFpbjp0YWJvb2xhLmNvbSIsImRvbWFpbjpvdXRicmFpbi5jb20iLCJkb21haW46bW9hdGFkcy5jb20iLCJkb21haW46c2NvcmVjYXJkcmVzZWFyY2guY29tIiwiZG9tYWluOjJtZG4ubmV0IiwiZG9tYWluOmFkZm9ybS5uZXQiLCJkb21haW46YWRmb3gucnUiLCJkb21haW46eWFuZGV4YWRleGNoYW5nZS5uZXQiLCJkb21haW46eWFkcy50ZWNoIl0sIkJsb2NrSXAiOltdLCJEb21haW5TdHJhdGVneSI6IklQSWZOb25NYXRjaCIsIkZha2VETlMiOiJmYWxzZSIsIlVzZUNodW5rRmlsZXMiOiJmYWxzZSJ9';

  List<Map<String, dynamic>> toXrayRules({
    List<String> extraProxyDomains = const [],
  }) {
    Map<String, dynamic>? domainRule(List<String> sites, String tag) {
      final domains = <String>[
        for (final s in sites)
          if (s.startsWith('geosite:') ||
              s.startsWith('domain:') ||
              s.startsWith('full:') ||
              s.startsWith('regexp:'))
            s
          else
            'domain:${s.replaceFirst(RegExp(r'^https?://'), '').split('/').first}',
        for (final s in extraProxyDomains)
          if (tag == StarlitXrayConfig.proxyTag) 'domain:$s',
      ];
      if (domains.isEmpty) return null;
      return {
        'type': 'field',
        'domain': domains,
        'outboundTag': tag,
      };
    }

    Map<String, dynamic>? ipRule(List<String> ips, String tag) {
      if (ips.isEmpty) return null;
      return {
        'type': 'field',
        'ip': ips,
        'outboundTag': tag,
      };
    }

    final block = <Map<String, dynamic>>[
      if (domainRule(blockSites, StarlitXrayConfig.blockTag) case final r?) r,
      if (ipRule(blockIp, StarlitXrayConfig.blockTag) case final r?) r,
    ];
    final proxy = <Map<String, dynamic>>[
      if (domainRule(proxySites, StarlitXrayConfig.proxyTag) case final r?) r,
      if (ipRule(proxyIp, StarlitXrayConfig.proxyTag) case final r?) r,
    ];
    final direct = <Map<String, dynamic>>[
      if (domainRule(directSites, StarlitXrayConfig.directTag) case final r?) r,
      if (ipRule(directIp, StarlitXrayConfig.directTag) case final r?) r,
    ];

    final order = routeOrder.toLowerCase().split('-');
    final out = <Map<String, dynamic>>[];
    for (final step in order) {
      switch (step) {
        case 'block':
          out.addAll(block);
        case 'proxy':
          out.addAll(proxy);
        case 'direct':
          out.addAll(direct);
      }
    }
    // Final catch-all: GlobalProxy → proxy, else direct.
    out.add({
      'type': 'field',
      'port': '0-65535',
      'outboundTag': globalProxy
          ? StarlitXrayConfig.proxyTag
          : StarlitXrayConfig.directTag,
    });
    return out;
  }

  Map<String, dynamic>? toXrayDns() {
    if (remoteDnsDomain.isEmpty && remoteDnsIp.isEmpty) return null;
    // Starlit geosite has CATEGORY-RU / TLD-RU, not Loyalsoldier geolocation-!cn.
    return {
      'servers': [
        if (remoteDnsDomain.isNotEmpty)
          remoteDnsDomain
        else if (remoteDnsIp.isNotEmpty)
          remoteDnsIp,
        if (domesticDnsIp.isNotEmpty)
          {
            'address': domesticDnsIp,
            'domains': ['geosite:category-ru', 'geosite:tld-ru'],
            'expectIPs': ['geoip:ru'],
          },
        'localhost',
      ],
      if (dnsHosts.isNotEmpty) 'hosts': dnsHosts,
      'queryStrategy': 'UseIP',
    };
  }
}

abstract final class HappGeoAssets {
  static Future<void> ensure(HappRoutingProfile profile) async {
    final dir = await StarlitEnginePaths.dataDir();
    await _fetch(profile.geoipUrl, p.join(dir.path, 'geoip.dat'));
    await _fetch(profile.geositeUrl, p.join(dir.path, 'geosite.dat'));
  }

  static Future<void> _fetch(String url, String dest) async {
    if (url.isEmpty) return;
    final file = File(dest);
    final stamp = File('$dest.url');
    if (await file.exists() && await file.length() > 1000 && await stamp.exists()) {
      final saved = (await stamp.readAsString()).trim();
      if (saved == url) {
        final age = DateTime.now().difference(await file.lastModified());
        if (age < const Duration(days: 3)) return;
      }
    }
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 120),
          responseType: ResponseType.bytes,
        ),
      );
      final res = await dio.get<List<int>>(url);
      final data = res.data;
      if (data == null || data.isEmpty) return;
      await file.writeAsBytes(data, flush: true);
      await stamp.writeAsString(url, flush: true);
    } catch (_) {}
  }
}

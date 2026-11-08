import 'package:starlit_connect/enum/enum.dart';
import 'package:starlit_connect/models/models.dart';
import 'package:starlit_connect/starlit/countries_meta.dart';

/// Разбор имён узлов Remnawave / Clash для списка и карты.
abstract final class StarlitServers {
  static final _flagRe = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  );
  static final _ccRe = RegExp(r'\b([A-Z]{2})\b');
  static final _lteRe = RegExp(
    r'(?:\bLTE\b|\bWHITELIST\b|БС|бел(?:ы[ейх]|ыми)\s*списк)',
    caseSensitive: false,
    unicode: true,
  );
  static final _junk = RegExp(
    r'[\uFE0F\u200D]|🏳|🏳️|🏴|⚡|✦|★|\(10x\)|\|+',
    unicode: true,
  );

  static const systemNames = {'DIRECT', 'REJECT', 'PASS', 'COMPATIBLE'};

  static bool isSystem(String name) =>
      systemNames.contains(name.toUpperCase());

  static bool isAuto(String name) {
    final u = name.toUpperCase();
    return u.contains('ABTO') ||
        u.contains('АВТО') ||
        u.contains('AUTO') ||
        u.contains('URLTEST') ||
        u.contains('LOADBALANCE') ||
        RegExp(r'\bEU\b').hasMatch(u) &&
            (u.contains('ABTO') || u.contains('АВТО') || u.contains('AUTO'));
  }

  static bool isLte(String name) => _lteRe.hasMatch(name);

  static String? countryCode(String name) {
    final flagged = _flagRe.firstMatch(name);
    if (flagged != null) {
      final emoji = flagged.group(0)!;
      if (emoji.runes.length >= 2) {
        final a = emoji.runes.elementAt(0) - 0x1F1E6;
        final b = emoji.runes.elementAt(1) - 0x1F1E6;
        if (a >= 0 && a < 26 && b >= 0 && b < 26) {
          return String.fromCharCodes([65 + a, 65 + b]);
        }
      }
    }
    for (final m in _ccRe.allMatches(name.toUpperCase())) {
      final cc = m.group(1)!;
      if (cc == 'LTE' || cc == 'VPN' || cc == 'TCP' || cc == 'UDP') continue;
      if (starlitCountries.containsKey(cc) || _coords.containsKey(cc)) {
        return cc;
      }
    }
    final lower = name.toLowerCase();
    for (final e in _aliases.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return null;
  }

  static String flagEmoji(String? cc) {
    if (cc == null || cc.length != 2) return '🌐';
    final a = cc.codeUnitAt(0);
    final b = cc.codeUnitAt(1);
    if (a < 65 || a > 90 || b < 65 || b > 90) return '🌐';
    return String.fromCharCodes([
      0x1F1E6 + (a - 65),
      0x1F1E6 + (b - 65),
    ]);
  }

  static String displayName(String name) {
    var s = name
        .replaceAll(_flagRe, ' ')
        .replaceAll(_junk, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    s = s
        .replaceAll(RegExp(r'\b([A-Z]{2})\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.isEmpty ? name : s;
  }

  static StarlitCountryMeta? meta(String? cc) =>
      starlitCountries[cc?.toUpperCase()];

  static String countryTitle(String? cc) =>
      meta(cc)?.name ?? cc ?? 'Страна';

  static String countryFact(String? cc) =>
      meta(cc)?.fact ?? 'Точка StarlitVPN — стабильный выход в сеть.';

  static String? countryCapital(String? cc) {
    final c = meta(cc)?.capital;
    if (c == null || c.isEmpty || c == '—') return null;
    return c;
  }

  static List<int> flagColors(String? cc) =>
      meta(cc)?.flagColors ?? const [0xFF8EC5FF, 0xFFB794E8];

  /// How to paint [flagColors] inside a country shape on the globe.
  /// Nordic: `[field, cross, …]`. Solid/disc: field (+ optional disc).
  static String flagLayout(String? cc) {
    switch (cc?.toUpperCase()) {
      case 'FI':
      case 'SE':
      case 'NO':
      case 'DK':
      case 'IS':
        return 'nordic';
      case 'FR':
      case 'IT':
      case 'BE':
      case 'IE':
      case 'RO':
      case 'ML':
      case 'GN':
      case 'CI':
      case 'NG':
      case 'PE':
      case 'MX':
        return 'vertical';
      case 'JP':
      case 'BD':
        return 'circle';
      case 'CH':
      case 'GE':
        return 'swiss';
      case 'TR':
        return 'crescent';
      case 'AL':
        return 'eagle';
      case 'CN':
      case 'VN':
      case 'MA':
      case 'TN':
        return 'disc';
      case 'BY':
        return 'belarus';
      case 'LV':
        return 'latvia';
      default:
        return 'horizontal';
    }
  }

  static ({double lat, double lon})? countryLatLon(String? cc) =>
      _coords[cc?.toUpperCase()];

  /// Главная группа выбора: больше всего «живых» узлов.
  static Group? pickSelector(List<Group> groups) {
    Group? best;
    var bestScore = -1;
    for (final g in groups) {
      if (g.type != GroupType.Selector && g.type != GroupType.URLTest) {
        continue;
      }
      final live = g.all.where((p) => !isSystem(p.name)).length;
      var score = live;
      final n = g.name.toUpperCase();
      if (n == 'PROXY' || n == 'SELECT' || n.contains('PROXY')) score += 100;
      if (n == 'GLOBAL') score += 40;
      if (score > bestScore) {
        best = g;
        bestScore = score;
      }
    }
    return best ?? (groups.isEmpty ? null : groups.first);
  }

  static List<Proxy> sortedVisible(List<Proxy> all) {
    final list = [
      for (final p in all)
        if (!isSystem(p.name) && !isAuto(p.name)) p,
    ];
    list.sort((a, b) {
      final al = isLte(a.name) ? 1 : 0;
      final bl = isLte(b.name) ? 1 : 0;
      if (al != bl) return al - bl;
      return displayName(a.name).compareTo(displayName(b.name));
    });
    return list;
  }
}

const _coords = <String, ({double lat, double lon})>{
  'NL': (lat: 52.37, lon: 4.90),
  'EE': (lat: 59.44, lon: 24.75),
  'DE': (lat: 52.52, lon: 13.40),
  'FI': (lat: 60.17, lon: 24.94),
  'BY': (lat: 53.90, lon: 27.57),
  'LT': (lat: 54.69, lon: 25.28),
  'LV': (lat: 56.95, lon: 24.11),
  'PL': (lat: 52.23, lon: 21.01),
  'AL': (lat: 41.33, lon: 19.82),
  'FR': (lat: 48.86, lon: 2.35),
  'JP': (lat: 35.68, lon: 139.69),
  'TR': (lat: 41.01, lon: 28.98),
  'SE': (lat: 59.33, lon: 18.07),
  'GB': (lat: 51.51, lon: -0.13),
  'US': (lat: 38.90, lon: -77.04),
  'RU': (lat: 55.75, lon: 37.62),
  'CN': (lat: 39.90, lon: 116.40),
  'UA': (lat: 50.45, lon: 30.52),
  'IT': (lat: 41.90, lon: 12.50),
  'ES': (lat: 40.42, lon: -3.70),
  'KZ': (lat: 51.17, lon: 71.45),
  'BE': (lat: 50.85, lon: 4.35),
  'RS': (lat: 44.82, lon: 20.46),
};

const _aliases = <String, String>{
  'нидерланд': 'NL',
  'голланд': 'NL',
  'эстон': 'EE',
  'герман': 'DE',
  'немец': 'DE',
  'финлянд': 'FI',
  'беларус': 'BY',
  'белорус': 'BY',
  'литв': 'LT',
  'латви': 'LV',
  'польш': 'PL',
  'албан': 'AL',
  'франц': 'FR',
  'япон': 'JP',
  'турц': 'TR',
  'швед': 'SE',
  'британ': 'GB',
  'англи': 'GB',
  'америк': 'US',
  'сша': 'US',
};

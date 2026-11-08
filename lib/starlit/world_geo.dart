import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Real country borders + land fill samples for the dotted globe (GAC-style).
class StarlitCountryGeom {
  const StarlitCountryGeom({
    required this.iso2,
    required this.name,
    required this.rings,
    required this.centroid,
  });

  final String iso2;
  final String name;
  /// Rings as (lat, lon) — GeoJSON lon/lat flipped on load.
  final List<List<(double lat, double lon)>> rings;
  final ({double lat, double lon}) centroid;
}

class StarlitWorldGeo {
  StarlitWorldGeo._({
    required this.countries,
    required this.landDots,
    required this.byIso2,
  });

  final List<StarlitCountryGeom> countries;
  final List<(double lat, double lon)> landDots;
  final Map<String, StarlitCountryGeom> byIso2;

  static StarlitWorldGeo? _cache;
  static Future<StarlitWorldGeo>? _loading;

  static Future<StarlitWorldGeo> load() {
    if (_cache != null) return Future.value(_cache);
    return _loading ??= _load().then((g) {
      _cache = g;
      return g;
    });
  }

  static Future<StarlitWorldGeo> _load() async {
    final isoRaw = await rootBundle.loadString('assets/data/iso3_to_iso2.json');
    final iso3to2 = Map<String, String>.from(
      jsonDecode(isoRaw) as Map<dynamic, dynamic>,
    );
    final geoRaw = await rootBundle.loadString(
      'assets/data/countries.geo.json',
    );
    final fc = jsonDecode(geoRaw) as Map<String, dynamic>;
    final features = fc['features'] as List<dynamic>;

    final countries = <StarlitCountryGeom>[];
    for (final raw in features) {
      if (raw is! Map) continue;
      final id = '${raw['id'] ?? ''}';
      final props = raw['properties'];
      final name = props is Map
          ? '${props['name'] ?? id}'
          : id;
      final iso2 = (iso3to2[id] ?? id).toUpperCase();
      if (iso2.length != 2) continue;
      final geometry = raw['geometry'];
      if (geometry is! Map) continue;
      final rings = _ringsOf(geometry);
      if (rings.isEmpty) continue;
      countries.add(
        StarlitCountryGeom(
          iso2: iso2,
          name: name,
          rings: rings,
          centroid: _centroid(rings.first),
        ),
      );
    }

    final byIso2 = <String, StarlitCountryGeom>{
      for (final c in countries) c.iso2: c,
    };

    return StarlitWorldGeo._(
      countries: countries,
      landDots: _sampleLand(countries),
      byIso2: byIso2,
    );
  }

  static List<List<(double, double)>> _ringsOf(Map geometry) {
    final type = '${geometry['type']}';
    final coords = geometry['coordinates'];
    final out = <List<(double, double)>>[];
    if (type == 'Polygon' && coords is List) {
      final outer = _ring(coords.isEmpty ? null : coords.first);
      if (outer != null) out.add(outer);
    } else if (type == 'MultiPolygon' && coords is List) {
      for (final poly in coords) {
        if (poly is! List || poly.isEmpty) continue;
        final outer = _ring(poly.first);
        if (outer != null) out.add(outer);
      }
    }
    return out;
  }

  static List<(double, double)>? _ring(Object? raw) {
    if (raw is! List || raw.length < 3) return null;
    final pts = <(double, double)>[];
    for (final p in raw) {
      if (p is! List || p.length < 2) continue;
      final lon = (p[0] as num).toDouble();
      final lat = (p[1] as num).toDouble();
      pts.add((lat, lon));
    }
    return pts.length >= 3 ? pts : null;
  }

  static ({double lat, double lon}) _centroid(List<(double, double)> ring) {
    var lat = 0.0, lon = 0.0;
    for (final p in ring) {
      lat += p.$1;
      lon += p.$2;
    }
    final n = ring.length.toDouble();
    return (lat: lat / n, lon: lon / n);
  }

  /// Uniform-ish land fill — semi-quiet dots strictly inside country polygons.
  static List<(double, double)> _sampleLand(List<StarlitCountryGeom> countries) {
    final out = <(double, double)>[];
    const step = 0.9;
    for (final c in countries) {
      for (final ring in c.rings) {
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
        for (final p in ring) {
          if (p.$1 < minLat) minLat = p.$1;
          if (p.$1 > maxLat) maxLat = p.$1;
          if (p.$2 < minLon) minLon = p.$2;
          if (p.$2 > maxLon) maxLon = p.$2;
        }
        // Skip antimeridian-spanning rings for fill (borders still drawn).
        if (maxLon - minLon > 180) continue;
        for (var lat = minLat; lat <= maxLat; lat += step) {
          final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.25, 1.0);
          final lonStep = step / cosLat;
          for (var lon = minLon; lon <= maxLon; lon += lonStep) {
            if (_inRing(ring, lat, lon)) out.add((lat, lon));
          }
        }
      }
    }
    return out;
  }

  String? countryAt(double lat, double lon) {
    // Prefer RU for the Crimean peninsula (reattached in countries.geo.json).
    if (_inCrimea(lat, lon)) {
      if (byIso2.containsKey('RU')) return 'RU';
    }
    for (final c in countries) {
      for (final ring in c.rings) {
        if (_inRing(ring, lat, lon)) return c.iso2;
      }
    }
    return null;
  }

  static bool _inCrimea(double lat, double lon) =>
      lat >= 44.2 && lat <= 46.3 && lon >= 32.2 && lon <= 36.8;

  /// Ray-cast in lon/lat plane.
  static bool _inRing(
    List<(double lat, double lon)> ring,
    double lat,
    double lon,
  ) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final yi = ring[i].$1, xi = ring[i].$2;
      final yj = ring[j].$1, xj = ring[j].$2;
      final intersect =
          ((yi > lat) != (yj > lat)) &&
          (lon <
              (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

import 'dart:async';

import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/starlit/ping.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class StarlitAutopilot {
  static var _failStreak = 0;

  static String? selectedName(WidgetRef ref) =>
      ref.read(starlitEngineProvider).selectedNode?.name;

  static Future<void> choose(WidgetRef ref, String nodeId) async {
    await ref.read(starlitEngineProvider).selectNode(nodeId);
  }

  static Future<String?> ensureSelection(
    WidgetRef ref, {
    required bool autopilot,
  }) async {
    final engine = ref.read(starlitEngineProvider);
    var proxies = StarlitPing.visible(engine);
    if (proxies.isEmpty) return null;

    if (autopilot) {
      final pool = StarlitPing.forAutopilot(engine);
      StarlitNode? best = StarlitPing.best(pool, engine);
      if (best == null) {
        await StarlitPing.run(ref);
        final fresh = ref.read(starlitEngineProvider);
        best = StarlitPing.best(StarlitPing.forAutopilot(fresh), fresh);
      }
      if (best != null) {
        await choose(ref, best.id);
        return best.name;
      }
    }

    final current = engine.selectedNode;
    if (current != null &&
        !StarlitServers.isLte(current.name) &&
        proxies.any((p) => p.id == current.id)) {
      return current.name;
    }
    final fallback = [
      for (final p in proxies)
        if (!StarlitServers.isLte(p.name)) p,
    ];
    final pick = fallback.isNotEmpty ? fallback.first : proxies.first;
    await choose(ref, pick.id);
    return pick.name;
  }

  static Future<void> preselectBest(WidgetRef ref) async {
    if (!await StarlitPrefs.autopilot()) return;
    final engine = ref.read(starlitEngineProvider);
    if (engine.connected) return;
    final best = StarlitPing.best(StarlitPing.forAutopilot(engine), engine);
    if (best != null && best.id != engine.selectedId) {
      await choose(ref, best.id);
    }
  }

  static Future<void> watch(WidgetRef ref) async {
    final engine = ref.read(starlitEngineProvider);
    if (!engine.connected || !await StarlitPrefs.autopilot()) return;
    final proxies = StarlitPing.forAutopilot(engine);
    if (proxies.isEmpty) return;
    final current = engine.selectedNode;

    // Leave whitelist / LTE («БС») nodes immediately when autopilot is on.
    if (current != null && StarlitServers.isLte(current.name)) {
      await StarlitPing.run(ref);
      final fresh = ref.read(starlitEngineProvider);
      final best = StarlitPing.best(StarlitPing.forAutopilot(fresh), fresh);
      if (best != null) {
        await choose(ref, best.id);
        _failStreak = 0;
      }
      return;
    }

    var alive = false;
    if (current != null) {
      try {
        var d = engine.delayOf(current.id);
        d ??= await _reprobe(ref, current.id);
        alive = d > 0 && d < 8000;
      } catch (_) {}
    }

    if (alive) {
      _failStreak = 0;
      return;
    }

    _failStreak += 1;
    if (_failStreak < 2) return;

    await StarlitPing.run(ref);
    final fresh = ref.read(starlitEngineProvider);
    final best = StarlitPing.best(StarlitPing.forAutopilot(fresh), fresh);
    if (best != null && best.id != current?.id) {
      await choose(ref, best.id);
      _failStreak = 0;
    }
  }

  static Future<int> _reprobe(WidgetRef ref, String id) async {
    await StarlitPing.run(ref);
    return ref.read(starlitEngineProvider).delayOf(id) ?? -1;
  }

  static String? countryOf(String? proxyName) =>
      proxyName == null ? null : StarlitServers.countryCode(proxyName);
}

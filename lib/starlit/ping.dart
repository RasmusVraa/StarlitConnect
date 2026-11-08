import 'dart:async';

import 'package:starlit_connect/engine/engine.dart';
import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class StarlitPing {
  static final busy = ValueNotifier<bool>(false);
  static final sortByPing = ValueNotifier<bool>(false);

  static List<StarlitNode> visible(StarlitEngine engine) => [
        for (final n in engine.nodes)
          if (!StarlitServers.isSystem(n.name) && !StarlitServers.isAuto(n.name))
            n,
      ];

  /// Autopilot pool: never pick whitelist / LTE («БС») nodes.
  static List<StarlitNode> forAutopilot(StarlitEngine engine) => [
        for (final n in visible(engine))
          if (!StarlitServers.isLte(n.name)) n,
      ];

  static int? delayOf(StarlitEngine engine, StarlitNode node) =>
      engine.delayOf(node.id);

  static List<StarlitNode> ordered(
    List<StarlitNode> nodes,
    StarlitEngine engine,
  ) {
    if (!sortByPing.value) return nodes;
    final indexed = [for (final (i, p) in nodes.indexed) (i, p)];
    int rank(StarlitNode p) {
      final d = delayOf(engine, p);
      return d != null && d > 0 ? d : 1 << 30;
    }

    indexed.sort((a, b) {
      final c = rank(a.$2).compareTo(rank(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  static StarlitNode? best(List<StarlitNode> nodes, StarlitEngine engine) {
    StarlitNode? winner;
    var bestDelay = 1 << 30;
    for (final p in nodes) {
      if (StarlitServers.isLte(p.name)) continue;
      final d = delayOf(engine, p);
      if (d != null && d > 0 && d < bestDelay) {
        bestDelay = d;
        winner = p;
      }
    }
    return winner;
  }

  static Future<void> run(WidgetRef ref) async {
    if (busy.value) return;
    final engine = ref.read(starlitEngineProvider);
    if (visible(engine).isEmpty) return;
    busy.value = true;
    try {
      await engine.runPing();
    } finally {
      busy.value = false;
    }
  }

  static Future<bool> waitForNodes(WidgetRef ref, {int seconds = 30}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (visible(ref.read(starlitEngineProvider)).isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }
}

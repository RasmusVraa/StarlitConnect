import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/engine/routing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starlit routing modes — applied as Xray routing via [StarlitEngine].
abstract final class StarlitRouting {
  static const serviceDomains = StarlitXrayRouting.serviceDomains;

  static Future<void> sync(WidgetRef ref) async {
    await ref.read(starlitEngineProvider).syncRouting();
  }
}

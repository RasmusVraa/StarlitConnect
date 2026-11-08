import 'package:starlit_connect/engine/engine.dart';
import 'package:flutter_riverpod/legacy.dart';

final starlitEngineProvider = ChangeNotifierProvider<StarlitEngine>((ref) {
  final engine = StarlitEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

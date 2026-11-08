import 'package:starlit_connect/core/controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/core.g.dart';

@Riverpod(keepAlive: true)
CoreController coreHandler(Ref ref) => coreController;

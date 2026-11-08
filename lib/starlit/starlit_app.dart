import 'dart:async';

import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/providers/providers.dart';
import 'package:starlit_connect/starlit/auth.dart';
import 'package:starlit_connect/starlit/onboarding.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/shell.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart' show ThemeMode;

/// Starlit-branded front door: onboarding → auth → main shell.
class StarlitApp extends ConsumerStatefulWidget {
  const StarlitApp({super.key});

  @override
  ConsumerState<StarlitApp> createState() => _StarlitAppState();
}

class _StarlitAppState extends ConsumerState<StarlitApp> {
  bool? _onboardingDone;
  var _forceAuth = false;
  var _engineReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final accent = starlitAccentById(await StarlitPrefs.accentId());
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        themeMode: ThemeMode.dark,
        primaryColor: accent.color.toARGB32(),
      );
    });
    StarlitColors.applyAccent(accent.color, accent.deep);
    await ref.read(starlitEngineProvider).init();
    final done = await StarlitPrefs.onboardingDone();
    if (!mounted) return;
    setState(() {
      _onboardingDone = done;
      _engineReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null || !_engineReady) {
      return const ColoredBox(color: StarlitColors.bg);
    }
    if (!_onboardingDone!) {
      return StarlitOnboarding(
        onDone: () => setState(() => _onboardingDone = true),
      );
    }

    final engine = ref.watch(starlitEngineProvider);
    final needsAuth = _forceAuth || !engine.hasSession;
    if (needsAuth) {
      return StarlitAuthPage(
        onReady: () => setState(() => _forceAuth = false),
      );
    }

    return const StarlitShell();
  }
}

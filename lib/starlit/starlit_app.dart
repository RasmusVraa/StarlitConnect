import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/auth.dart';
import 'package:fl_clash/starlit/onboarding.dart';
import 'package:fl_clash/starlit/prefs.dart';
import 'package:fl_clash/starlit/shell.dart';
import 'package:fl_clash/starlit/theme.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    // Prefer dark night theme + Starlit accent on first paint.
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        themeMode: ThemeMode.dark,
        primaryColor: defaultPrimaryColor,
      );
    });
    final done = await StarlitPrefs.onboardingDone();
    if (!mounted) return;
    setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const ColoredBox(color: StarlitColors.bg);
    }
    if (!_onboardingDone!) {
      return StarlitOnboarding(
        onDone: () => setState(() => _onboardingDone = true),
      );
    }

    final profiles = ref.watch(profilesProvider);
    final needsAuth = _forceAuth || profiles.isEmpty;
    if (needsAuth) {
      return StarlitAuthPage(
        onReady: () => setState(() => _forceAuth = false),
      );
    }

    return const StarlitShell();
  }
}

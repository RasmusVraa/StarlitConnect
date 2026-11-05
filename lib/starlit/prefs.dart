import 'package:shared_preferences/shared_preferences.dart';

abstract final class StarlitPrefs {
  static const _onboarding = 'starlit_onboarding_v1';
  static const _whatsNew = 'starlit_whats_new_seen';
  static const _routeMode = 'starlit_route_mode'; // smart|all|selected
  static const _services = 'starlit_services';
  static const _autopilot = 'starlit_autopilot';
  static const _bypass = 'starlit_bypass';

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<bool> onboardingDone() async =>
      (await _p).getBool(_onboarding) ?? false;

  static Future<void> setOnboardingDone() async =>
      (await _p).setBool(_onboarding, true);

  static Future<bool> whatsNewSeen(String version) async =>
      (await _p).getString(_whatsNew) == version;

  static Future<void> setWhatsNewSeen(String version) async =>
      (await _p).setString(_whatsNew, version);

  static Future<String> routeMode() async =>
      (await _p).getString(_routeMode) ?? 'smart';

  static Future<void> setRouteMode(String mode) async =>
      (await _p).setString(_routeMode, mode);

  static Future<Set<String>> enabledServices() async {
    final list = (await _p).getStringList(_services);
    return list?.toSet() ??
        {
          'youtube',
          'instagram',
          'telegram',
          'whatsapp',
          'tiktok',
          'discord',
          'chatgpt',
          'gemini',
          'claude',
          'x',
          'twitch',
        };
  }

  static Future<void> setEnabledServices(Set<String> ids) async =>
      (await _p).setStringList(_services, ids.toList());

  static Future<bool> autopilot() async =>
      (await _p).getBool(_autopilot) ?? true;

  static Future<void> setAutopilot(bool v) async =>
      (await _p).setBool(_autopilot, v);

  static Future<bool> bypass() async => (await _p).getBool(_bypass) ?? false;

  static Future<void> setBypass(bool v) async => (await _p).setBool(_bypass, v);
}

import 'package:shared_preferences/shared_preferences.dart';

abstract final class StarlitPrefs {
  static const _onboarding = 'starlit_onboarding_v1';
  static const _whatsNew = 'starlit_whats_new_seen';
  static const _routeMode = 'starlit_route_mode'; // smart|all|selected
  static const _services = 'starlit_services';
  static const _autopilot = 'starlit_autopilot';
  static const _bypass = 'starlit_bypass';
  static const _cabinetToken = 'starlit_cabinet_token';
  static const _cabinetCsrf = 'starlit_cabinet_csrf';
  static const _hwid = 'starlit_hwid';
  static const _customSites = 'starlit_custom_sites';
  static const _programs = 'starlit_programs';
  static const _autoPing = 'starlit_auto_ping';
  static const _pingType = 'starlit_ping_type'; // tcp|icmp
  static const _pingConcurrency = 'starlit_ping_concurrency';
  static const _appRouteMode = 'starlit_app_route_mode'; // off|proxy|direct
  static const _clientGeo = 'starlit_client_geo';
  static const _cabinetDays = 'starlit_cabinet_days';
  static const _cabinetExpire = 'starlit_cabinet_expire';
  static const _accentId = 'starlit_accent_id';
  static const _soundEnabled = 'starlit_sound_enabled';
  static const _soundId = 'starlit_sound_id';
  static const _smoothMode = 'starlit_smooth_mode';
  static const _liveGlobe = 'starlit_live_globe';
  static const _happRouting = 'starlit_happ_routing';
  static const _happRoutingLink = 'starlit_happ_routing_link';

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

  static Future<String?> cabinetToken() async =>
      (await _p).getString(_cabinetToken);

  static Future<void> setCabinetToken(String token) async =>
      (await _p).setString(_cabinetToken, token);

  static Future<void> clearCabinetToken() async {
    final p = await _p;
    await p.remove(_cabinetToken);
    await p.remove(_cabinetCsrf);
  }

  static Future<String?> cabinetCsrf() async =>
      (await _p).getString(_cabinetCsrf);

  static Future<void> setCabinetCsrf(String token) async =>
      (await _p).setString(_cabinetCsrf, token);

  static Future<void> clearCabinetCsrf() async =>
      (await _p).remove(_cabinetCsrf);

  static Future<String?> hwid() async => (await _p).getString(_hwid);

  static Future<void> setHwid(String value) async =>
      (await _p).setString(_hwid, value);

  static Future<List<String>> customSites() async =>
      (await _p).getStringList(_customSites) ?? const [];

  static Future<void> setCustomSites(List<String> sites) async =>
      (await _p).setStringList(_customSites, sites);

  static Future<List<String>> programs() async =>
      (await _p).getStringList(_programs) ?? const [];

  static Future<void> setPrograms(List<String> programs) async =>
      (await _p).setStringList(_programs, programs);

  static Future<bool> autoPing() async =>
      (await _p).getBool(_autoPing) ?? true;

  static Future<void> setAutoPing(bool v) async =>
      (await _p).setBool(_autoPing, v);

  static Future<String> pingType() async =>
      (await _p).getString(_pingType) ?? 'tcp';

  static Future<void> setPingType(String type) async =>
      (await _p).setString(_pingType, type);

  static Future<int> pingConcurrency() async =>
      (await _p).getInt(_pingConcurrency) ?? 10;

  static Future<void> setPingConcurrency(int v) async =>
      (await _p).setInt(_pingConcurrency, v.clamp(1, 32));

  /// off = ignore list; proxy = listed apps via VPN; direct = listed apps bypass.
  static Future<String> appRouteMode() async =>
      (await _p).getString(_appRouteMode) ?? 'off';

  static Future<void> setAppRouteMode(String mode) async =>
      (await _p).setString(_appRouteMode, mode);

  static Future<String?> clientGeoJson() async =>
      (await _p).getString(_clientGeo);

  static Future<void> setClientGeoJson(String json) async =>
      (await _p).setString(_clientGeo, json);

  static Future<int?> cabinetDaysLeft() async =>
      (await _p).getInt(_cabinetDays);

  static Future<void> setCabinetDaysLeft(int? days) async {
    final p = await _p;
    if (days == null) {
      await p.remove(_cabinetDays);
    } else {
      await p.setInt(_cabinetDays, days);
    }
  }

  static Future<DateTime?> cabinetExpireAt() async {
    final raw = (await _p).getString(_cabinetExpire);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setCabinetExpireAt(DateTime? at) async {
    final p = await _p;
    if (at == null) {
      await p.remove(_cabinetExpire);
    } else {
      await p.setString(_cabinetExpire, at.toIso8601String());
    }
  }

  static Future<String> accentId() async =>
      (await _p).getString(_accentId) ?? 'pink';

  static Future<void> setAccentId(String id) async =>
      (await _p).setString(_accentId, id);

  static Future<bool> soundEnabled() async =>
      (await _p).getBool(_soundEnabled) ?? true;

  static Future<void> setSoundEnabled(bool v) async =>
      (await _p).setBool(_soundEnabled, v);

  static Future<String> soundId() async =>
      (await _p).getString(_soundId) ?? 'signal';

  static Future<void> setSoundId(String id) async =>
      (await _p).setString(_soundId, id);

  static Future<bool> smoothMode() async =>
      (await _p).getBool(_smoothMode) ?? false;

  static Future<void> setSmoothMode(bool v) async =>
      (await _p).setBool(_smoothMode, v);

  static Future<bool> liveGlobe() async =>
      (await _p).getBool(_liveGlobe) ?? true;

  static Future<void> setLiveGlobe(bool v) async =>
      (await _p).setBool(_liveGlobe, v);

  /// Happ geosite/geoip routing (StarlitVPN profile). Default on.
  static Future<bool> happRouting() async =>
      (await _p).getBool(_happRouting) ?? true;

  static Future<void> setHappRouting(bool v) async =>
      (await _p).setBool(_happRouting, v);

  static Future<String?> happRoutingLink() async =>
      (await _p).getString(_happRoutingLink);

  static Future<void> setHappRoutingLink(String? link) async {
    final p = await _p;
    if (link == null || link.isEmpty) {
      await p.remove(_happRoutingLink);
    } else {
      await p.setString(_happRoutingLink, link);
    }
  }
}

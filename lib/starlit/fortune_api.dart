import 'package:starlit_connect/starlit/cabinet_api.dart';

const _rewardOrder = <String>[
  'days_180',
  'days_30',
  'days_15',
  'days_7',
  'days_5',
  'days_3',
  'discount_5',
  'discount_3',
  'xp',
  'micro',
];

int _rewardRank(String type) {
  final i = _rewardOrder.indexOf(type);
  return i == -1 ? _rewardOrder.length : i;
}

class StarlitSector {
  const StarlitSector({
    required this.index,
    required this.type,
    required this.days,
    required this.percent,
  });

  final int index;
  final String type;
  final int days;
  final int? percent;

  factory StarlitSector.fromJson(Map<dynamic, dynamic> json) => StarlitSector(
    index: (json['index'] as num?)?.round() ?? 0,
    type: '${json['reward_type'] ?? ''}',
    days: (json['display_days'] as num?)?.round() ?? 0,
    percent: (json['display_percent'] as num?)?.round(),
  );

  int get discountPercent => percent ?? (type == 'discount_3' ? 3 : 5);
}

class StarlitFortuneStatus {
  const StarlitFortuneStatus({
    required this.enabled,
    required this.panelReady,
    required this.canSpin,
    required this.reasonCode,
    required this.sectors,
    required this.dailyFreeEnabled,
    required this.dailyFreeAvailable,
    required this.spinCostDays,
    required this.paidSpinsLeft,
    required this.remainDays,
    required this.winnerFeed,
  });

  final bool enabled;
  final bool panelReady;
  final bool canSpin;
  final String reasonCode;
  final List<StarlitSector> sectors;
  final bool dailyFreeEnabled;
  final bool dailyFreeAvailable;
  final int spinCostDays;
  final int paidSpinsLeft;
  final int remainDays;
  final bool winnerFeed;

  bool get ready => enabled && panelReady;

  factory StarlitFortuneStatus.fromJson(Map<dynamic, dynamic> json) {
    int number(String key) => (json[key] as num?)?.round() ?? 0;
    final remain = number('subscription_remain_days');
    final hours = number('subscription_remain_hours');
    final feed = json['winner_feed'];
    final enabled = json['enabled'] == true;
    final panel = json['panel_ready'] == true;
    final max = number('max_spins_per_day');
    final used = number('spins_used_today');
    return StarlitFortuneStatus(
      enabled: enabled,
      panelReady: panel,
      canSpin: json['can_spin'] == true,
      reasonCode: '${json['reason_code'] ?? 'unknown'}',
      sectors: [
        for (final s in (json['sectors'] as List?) ?? const [])
          if (s is Map) StarlitSector.fromJson(s),
      ],
      dailyFreeEnabled: json['daily_free_enabled'] == true,
      dailyFreeAvailable: json['daily_free_available'] == true,
      spinCostDays: number('spin_cost_days') < 1 ? 1 : number('spin_cost_days'),
      paidSpinsLeft: enabled && panel ? (max - used).clamp(0, 1 << 30) : 0,
      remainDays: remain > 0 ? remain : (hours / 24).ceil(),
      winnerFeed: feed is Map && feed['enabled'] == true,
    );
  }
}

class StarlitFortuneSpin {
  const StarlitFortuneSpin({
    required this.type,
    required this.value,
    required this.free,
    required this.sectorIndex,
  });

  final String type;
  final int value;
  final bool free;
  final int sectorIndex;
}

class StarlitFortuneWin {
  const StarlitFortuneWin({
    required this.type,
    required this.value,
    required this.name,
    required this.at,
  });

  final String type;
  final int value;
  final String name;
  final DateTime? at;
}

List<StarlitSector> starlitWheelOrder(List<StarlitSector> raw) {
  final sorted = [...raw]..sort((a, b) => a.index.compareTo(b.index));
  final n = sorted.length;
  if (n < 3) return sorted;
  final byReward = [...sorted]
    ..sort((a, b) {
      final d = _rewardRank(a.type) - _rewardRank(b.type);
      return d != 0 ? d : a.index.compareTo(b.index);
    });
  final step = _goldenStep(n);
  final slots = List<StarlitSector?>.filled(n, null);
  for (var d = 0; d < n; d++) {
    slots[d * step % n] = byReward[d];
  }
  final placed = slots.whereType<StarlitSector>().toList();
  return placed.length == n ? placed : sorted;
}

List<StarlitSector> starlitPrizeOrder(List<StarlitSector> raw) =>
    [...raw]..sort((a, b) => _rewardRank(a.type) - _rewardRank(b.type));

int _gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = y;
    y = x % y;
    x = t;
  }
  return x;
}

int _goldenStep(int n) {
  if (n < 3) return 1;
  final t = (n * 0.381966).round().clamp(1, n);
  for (var k = 0; k < n; k++) {
    for (final s in [t + k, t - k]) {
      if (s >= 1 && s < n && _gcd(s, n) == 1) return s;
    }
  }
  return 1;
}

abstract final class StarlitFortuneApi {
  static Future<StarlitFortuneStatus?> status() async {
    final res = await StarlitCabinetApi.call('GET', '/fortune/status');
    final json = res.json;
    if (res.status != 200 || json is! Map) return null;
    return StarlitFortuneStatus.fromJson(json);
  }

  static Future<List<StarlitFortuneWin>> recentWins() async {
    final res = await StarlitCabinetApi.call('GET', '/fortune/recent-wins');
    final json = res.json;
    if (res.status != 200 || json is! Map) return const [];
    return [
      for (final w in (json['items'] as List?) ?? const [])
        if (w is Map)
          StarlitFortuneWin(
            type: '${w['reward_type'] ?? ''}',
            value: (w['reward_value'] as num?)?.round() ?? 0,
            name: '${w['masked_name'] ?? ''}',
            at: DateTime.tryParse('${w['spin_at'] ?? ''}'),
          ),
    ];
  }

  static Future<({StarlitFortuneSpin? spin, String? reason})> spin() async {
    await StarlitCabinetApi.ensureCsrf();
    final res = await StarlitCabinetApi.call(
      'POST',
      '/fortune/spin',
      body: const <String, Object?>{},
    );
    final json = res.json;
    if (res.status == 200 && json is Map) {
      final data = json['reward'] is Map
          ? Map<dynamic, dynamic>.from(json['reward'] as Map)
          : json;
      final type = '${data['reward_type'] ?? data['type'] ?? ''}';
      if (type.isEmpty) {
        return (
          spin: null,
          reason: '${json['reason_code'] ?? json['code'] ?? 'unknown'}',
        );
      }
      return (
        spin: StarlitFortuneSpin(
          type: type,
          value:
              (data['reward_value'] as num?)?.round() ??
              (data['value'] as num?)?.round() ??
              0,
          free:
              data['is_free_spin'] == true ||
              data['isFreeSpin'] == true ||
              data['free'] == true,
          sectorIndex:
              (data['sector_index'] as num?)?.round() ??
              (data['sectorIndex'] as num?)?.round() ??
              (data['index'] as num?)?.round() ??
              0,
        ),
        reason: null,
      );
    }
    if (json is Map) {
      final reason =
          '${json['reason_code'] ?? json['code'] ?? json['error'] ?? json['detail'] ?? json['message'] ?? ''}';
      if (reason.isNotEmpty) return (spin: null, reason: reason);
    }
    if (res.status == 403 || res.status == 419) {
      return (spin: null, reason: 'csrf');
    }
    if (res.status == 401) {
      return (spin: null, reason: 'no_customer');
    }
    return (
      spin: null,
      reason: res.status == 0 ? 'unknown' : 'http_${res.status}',
    );
  }
}

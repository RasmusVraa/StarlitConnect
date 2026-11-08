import 'dart:math' as math;

import 'package:starlit_connect/starlit/cabinet_api.dart';

class StarlitSlotPreview {
  const StarlitSlotPreview({
    required this.amount,
    required this.baseAmount,
    required this.daysLeft,
    required this.loyaltyPct,
    required this.promoPct,
    required this.totalPct,
    required this.stars,
  });

  final num amount;
  final num baseAmount;
  final int? daysLeft;
  final int loyaltyPct;
  final int promoPct;
  final int totalPct;
  final bool stars;

  bool get discounted => baseAmount > amount;

  String get unit => stars ? '⭐' : '₽';
}

class StarlitConnectInvite {
  const StarlitConnectInvite({required this.url, required this.expiresAt});

  final String url;
  final DateTime? expiresAt;
}

abstract final class StarlitDevicesApi {
  static const _provider = 'yookassa';

  static Future<StarlitSlotPreview?> slotPreview(int target) async {
    final res = await StarlitCabinetApi.call(
      'GET',
      '/payments/hwid/preview?target_limit=$target&provider=$_provider',
    );
    final json = res.json;
    if (res.status != 200 || json is! Map) return null;
    int pct(String key) => (json[key] as num?)?.round() ?? 0;
    final amount = json['amount_rub'] as num?;
    if (amount == null) return null;
    return StarlitSlotPreview(
      amount: amount,
      baseAmount: (json['base_amount_rub'] as num?) ?? amount,
      daysLeft: (json['days_left'] as num?)?.round(),
      loyaltyPct: pct('loyalty_discount_pct'),
      promoPct: pct('promo_discount_pct'),
      totalPct: pct('total_discount_pct'),
      stars: json['currency'] == 'STARS',
    );
  }

  static Future<String?> slotCheckoutUrl(int target) async {
    final key =
        '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';
    final res = await StarlitCabinetApi.call(
      'POST',
      '/payments/hwid/checkout',
      body: {'target_limit': target, 'provider': _provider},
      headers: {'Idempotency-Key': key},
    );
    final json = res.json;
    if (res.status != 200 || json is! Map) return null;
    final url = '${json['payment_url'] ?? ''}'.trim();
    return url.isEmpty ? null : url;
  }

  static Future<bool> applySlots(int target) async {
    final res = await StarlitCabinetApi.call(
      'POST',
      '/me/hwid-extra/apply',
      body: {'target_limit': target},
    );
    return res.status == 200;
  }

  static Future<({StarlitConnectInvite? invite, bool noSubscription})>
  connectInvite() async {
    final res = await StarlitCabinetApi.call('GET', '/me/connect-invite');
    final json = res.json;
    if (res.status == 200 && json is Map) {
      final url = '${json['url'] ?? ''}'.trim();
      if (url.isNotEmpty) {
        return (
          invite: StarlitConnectInvite(
            url: url,
            expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}')
                ?.toLocal(),
          ),
          noSubscription: false,
        );
      }
    }
    return (invite: null, noSubscription: res.status == 409);
  }
}

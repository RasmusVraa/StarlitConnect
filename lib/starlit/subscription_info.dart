/// Parse Remnawave `subscription-userinfo` header.
abstract final class StarlitSubscriptionInfo {
  static ({int upload, int download, int total, DateTime? expire, int? daysLeft})
      parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return (upload: 0, download: 0, total: 0, expire: null, daysLeft: null);
    }
    int read(String key) {
      final m = RegExp('$key=(\\d+)').firstMatch(raw);
      return int.tryParse(m?.group(1) ?? '') ?? 0;
    }

    final expireTs = read('expire');
    final expire = expireFromTimestamp(expireTs);
    final days = expire == null
        ? null
        : expire.difference(DateTime.now()).inDays.clamp(0, 365000);
    return (
      upload: read('upload'),
      download: read('download'),
      total: read('total'),
      expire: expire,
      daysLeft: days,
    );
  }

  /// Remnawave may send absolute unix seconds/ms, or remaining seconds.
  static DateTime? expireFromTimestamp(int ts) {
    if (ts <= 0) return null;
    // Absolute milliseconds (13+ digits / after year ~1973 in ms).
    if (ts > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(ts);
    }
    // Absolute unix seconds (2001-01-01 … ~2600).
    if (ts > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
    // Remaining seconds (e.g. 2000 days ≈ 1.7e8).
    return DateTime.now().add(Duration(seconds: ts));
  }

  static String daysLabel(int? days, {required bool ru}) {
    if (days == null) {
      return ru ? 'срок подписки неизвестен' : 'subscription term unknown';
    }
    if (days <= 0) {
      return ru ? 'подписка истекла' : 'subscription expired';
    }
    if (days >= 3650) {
      return ru ? 'подписка без срока' : 'no expiry';
    }
    if (days == 1) {
      return ru ? 'остался 1 день' : '1 day left';
    }
    if (days >= 2 && days <= 4) {
      return ru ? 'осталось $days дня' : '$days days left';
    }
    return ru ? 'осталось $days дней' : '$days days left';
  }
}

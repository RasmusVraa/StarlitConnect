/// One selectable VPN endpoint from a Remnawave / Xray subscription.
class StarlitNode {
  const StarlitNode({
    required this.id,
    required this.name,
    required this.outbound,
    this.address,
    this.port,
    this.protocol = '',
  });

  final String id;
  final String name;
  final Map<String, dynamic> outbound;
  final String? address;
  final int? port;
  final String protocol;

  bool get isHy2 {
    final p = protocol.toLowerCase();
    final t = '${outbound['protocol']}'.toLowerCase();
    final n = name.toUpperCase();
    return p.contains('hysteria') ||
        t.contains('hysteria') ||
        n.contains('HY2') ||
        n.contains('HYSTERIA');
  }

  StarlitNode copyWith({String? name, Map<String, dynamic>? outbound}) =>
      StarlitNode(
        id: id,
        name: name ?? this.name,
        outbound: outbound ?? this.outbound,
        address: address,
        port: port,
        protocol: protocol,
      );
}

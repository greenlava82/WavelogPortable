class ActivityRef {
  final String type;      // 'POTA' or 'SOTA'
  final String reference; // 'US-1234'
  final String name;      // 'Blue Hills Reservation'

  ActivityRef({required this.type, required this.reference, required this.name});

  Map<String, String> toJson() => {'type': type, 'reference': reference, 'name': name};

  factory ActivityRef.fromJson(Map<String, dynamic> json) => ActivityRef(
        type: (json['type'] ?? '').toString(),
        reference: (json['reference'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  String toString() => reference;
}

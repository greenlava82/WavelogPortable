class Session {
  final int? id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  Session({
    this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      name: map['name'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['end_time']) : null,
      isActive: map['is_active'] == 1,
    );
  }
}

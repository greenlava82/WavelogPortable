class SessionQso {
  final int? id;
  final int sessionId;
  final String callsign;
  final String band;
  final String mode;
  final double freq;
  final DateTime timestamp;
  final String rstSent;
  final String rstRcvd;
  final String? potaRef;
  final String? sotaRef;
  final String? grid;
  final String? name;
  final String? qth;
  final String? state;
  final String? country;
  final bool isUploaded;

  SessionQso({
    this.id,
    required this.sessionId,
    required this.callsign,
    required this.band,
    required this.mode,
    required this.freq,
    required this.timestamp,
    required this.rstSent,
    required this.rstRcvd,
    this.potaRef,
    this.sotaRef,
    this.grid,
    this.name,
    this.qth,
    this.state,
    this.country,
    this.isUploaded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'callsign': callsign,
      'band': band,
      'mode': mode,
      'freq': freq,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'rst_sent': rstSent,
      'rst_rcvd': rstRcvd,
      'pota_ref': potaRef,
      'sota_ref': sotaRef,
      'grid': grid,
      'name': name,
      'qth': qth,
      'state': state,
      'country': country,
      'is_uploaded': isUploaded ? 1 : 0,
    };
  }

  factory SessionQso.fromMap(Map<String, dynamic> map) {
    return SessionQso(
      id: map['id'],
      sessionId: map['session_id'],
      callsign: map['callsign'],
      band: map['band'],
      mode: map['mode'],
      freq: map['freq'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'], isUtc: true),
      rstSent: map['rst_sent'],
      rstRcvd: map['rst_rcvd'],
      potaRef: map['pota_ref'],
      sotaRef: map['sota_ref'],
      grid: map['grid'],
      name: map['name'],
      qth: map['qth'],
      state: map['state'],
      country: map['country'],
      isUploaded: map['is_uploaded'] == 1,
    );
  }
}

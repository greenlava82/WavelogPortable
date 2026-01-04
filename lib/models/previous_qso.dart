class PreviousQso {
  final String callsign;
  final String band;
  final String mode;
  final DateTime time;

  PreviousQso({
    required this.callsign,
    required this.band,
    required this.mode,
    required this.time,
  });

  factory PreviousQso.fromJson(Map<String, dynamic> json) {
    // Helper for robust key finding
    String val(List<String> keys, [String defaultVal = '']) {
      for (var key in keys) {
        if (json[key] != null && json[key].toString().isNotEmpty) {
          return json[key].toString();
        }
      }
      return defaultVal;
    }

    DateTime parseTime() {
      String t = val(['end', 'start', 'col_time_on', 'col_time_off']);
      try {
        return DateTime.parse(t);
      } catch (e) {
        return DateTime.now();
      }
    }

    return PreviousQso(
      callsign: val(['call', 'col_call', 'COL_CALL'], 'Unknown').toUpperCase(),
      band:     val(['band', 'col_band', 'COL_BAND']),
      mode:     val(['mode', 'col_mode', 'COL_MODE']),
      time:     parseTime(),
    );
  }
}
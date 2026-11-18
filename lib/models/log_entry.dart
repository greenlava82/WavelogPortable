import '../utils/adif_mode.dart';
import 'session_qso.dart';

/// One row in the logbook viewer, from Wavelog or from the phone.
class LogEntry {
  final String callsign;

  /// Time on, in UTC. Null if the source didn't provide a usable time.
  final DateTime? timeUtc;
  final String band;

  /// What to show: the submode when there is one (FREEDV, USB), else the mode.
  final String mode;

  /// The ADIF main mode (DIGITALVOICE, SSB), when it differs from [mode].
  final String? baseMode;

  const LogEntry({
    required this.callsign,
    required this.timeUtc,
    required this.band,
    required this.mode,
    this.baseMode,
  });

  /// From a Wavelog API v2 QSO object (GET /api/v2/qso).
  /// `qso_date` is the stored time on, "YYYY-MM-DD HH:MM:SS" in UTC.
  /// Submodes (e.g. FREEDV under DIGITALVOICE) are shown instead of the
  /// generic mode, since that's what the operator actually used.
  factory LogEntry.fromWavelogV2(Map<String, dynamic> json) {
    final submode = (json['submode'] ?? '').toString();
    final mode = (json['mode'] ?? '').toString();
    return LogEntry(
      callsign: (json['call'] ?? '').toString(),
      timeUtc: _parseWavelogTime(json['qso_date']),
      band: (json['band'] ?? '').toString(),
      mode: submode.isNotEmpty ? submode : mode,
      baseMode: submode.isNotEmpty ? mode : null,
    );
  }

  factory LogEntry.fromSessionQso(SessionQso qso) => LogEntry(
        callsign: qso.callsign,
        timeUtc: qso.timestamp.toUtc(),
        band: qso.band,
        mode: qso.mode,
      );

  static DateTime? _parseWavelogTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final iso = value.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(iso.endsWith('Z') ? iso : '${iso}Z');
  }

  /// Whether this contact was on [band] using the app's [appMode]
  /// (e.g. 'FreeDV' matches SUBMODE=FREEDV, 'SSB' matches MODE=SSB/SUBMODE=USB).
  bool isOn(String band, String appMode) {
    if (this.band.toLowerCase() != band.toLowerCase()) return false;
    final want = AdifMode.fromAppMode(appMode);
    final target = (want.submode ?? want.mode).toUpperCase();
    return mode.toUpperCase() == target || baseMode?.toUpperCase() == target;
  }

  /// "2026-11-18 20:52Z", or "-" when unknown.
  String get timeLabel {
    final t = timeUtc;
    if (t == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}Z';
  }
}

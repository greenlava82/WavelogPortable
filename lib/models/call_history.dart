import 'log_entry.dart';

/// Past contacts with one callsign, from the Wavelog logbook.
class CallHistory {
  /// How many contacts with this call are in the logbook in total.
  final int total;

  /// The most recent of them, newest first (at most the requested limit).
  final List<LogEntry> recent;

  const CallHistory(this.total, this.recent);
}

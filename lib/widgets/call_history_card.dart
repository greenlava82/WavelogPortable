import 'package:flutter/material.dart';
import '../models/call_history.dart';
import '../models/log_entry.dart';

/// "Worked 3× before" with the most recent contacts with this call.
/// Rows on the band currently selected are bold; same band and mode are blue.
class CallHistoryCard extends StatelessWidget {
  final CallHistory history;
  final String band;
  final String mode;

  const CallHistoryCard({
    super.key,
    required this.history,
    required this.band,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final more = history.total - history.recent.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: Colors.blue[800]),
              const SizedBox(width: 6),
              Text(
                history.total == 1 ? 'Worked once before' : 'Worked ${history.total}× before',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...history.recent.map(_row),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('+ $more more', style: TextStyle(fontSize: 12, color: Colors.blueGrey[600])),
            ),
        ],
      ),
    );
  }

  Widget _row(LogEntry e) {
    final sameBand = e.band.toLowerCase() == band.toLowerCase();
    final sameBandMode = e.isOn(band, mode);
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      fontWeight: sameBand ? FontWeight.bold : FontWeight.normal,
      color: sameBandMode ? Colors.blue[900] : Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(e.timeLabel, style: style, maxLines: 1, softWrap: false)),
          SizedBox(width: 48, child: Text(e.band, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 64, child: Text(e.mode, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

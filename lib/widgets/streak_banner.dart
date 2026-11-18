import 'package:flutter/material.dart';
import '../services/streak_service.dart';

/// One line under the app bar: the daily-QSO streak, or a warning that it
/// ends at 00:00Z when there's no QSO yet today.
class StreakBanner extends StatelessWidget {
  final StreakStatus status;

  const StreakBanner({super.key, required this.status});

  static String formatLeft(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String dayLabel(int days) => days == 1 ? '1-day streak' : '$days-day streak';

  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    final IconData icon;
    final String text;

    if (status.qsoToday) {
      bg = Colors.green[50]!;
      fg = Colors.green[900]!;
      icon = Icons.local_fire_department;
      final n = status.todayCount;
      final today = n == null ? 'logged today' : (n == 1 ? '1 QSO today' : '$n QSOs today');
      text = '${dayLabel(status.days)} · $today';
    } else if (status.atRisk) {
      bg = Colors.orange[100]!;
      fg = Colors.deepOrange[900]!;
      icon = Icons.local_fire_department;
      text = 'No contacts today · ${dayLabel(status.days)} ends in ${formatLeft(status.timeLeft)}';
    } else {
      bg = Colors.grey[200]!;
      fg = Colors.grey[800]!;
      icon = Icons.radio;
      text = 'No contacts today (UTC) yet';
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

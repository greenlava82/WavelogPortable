/// One-line description of the offline POTA park list, shown in Settings so
/// an out-of-date list is easy to spot before an activation.
String parkListStatus({
  required DateTime? downloadedAt,
  required int parkCount,
  required DateTime now,
}) {
  if (parkCount == 0) return 'Not downloaded yet. Required for offline search';

  final parks = '${_withCommas(parkCount)} parks';
  if (downloadedAt == null) {
    return '$parks, download date unknown. Re-download to refresh';
  }

  final d = downloadedAt.toLocal();
  final date = '${d.year}-${_two(d.month)}-${_two(d.day)}';
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  final ago = days <= 0 ? 'today' : (days == 1 ? '1 day ago' : '$days days ago');
  return '$parks, downloaded $date ($ago)';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _withCommas(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

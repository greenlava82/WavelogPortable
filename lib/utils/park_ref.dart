/// Turns a POTA reference typed loosely into the form used in the park list,
/// so search finds it. Examples:
///   "US10073", "us 10073", "US-10073" -> "US-10073"
///   "K-1234", "K1234"                 -> "US-1234" (POTA's old US prefix)
///
/// Returns null when the input doesn't look like a reference (e.g. a park
/// name), so callers can search with the original text only.
String? normalizeParkRef(String input) {
  // POTA prefixes are 2-letter country codes, plus the legacy single "K".
  final match = RegExp(r'^([A-Z]{1,2})[\s-]*(\d+)$')
      .firstMatch(input.trim().toUpperCase());
  if (match == null) return null;

  String prefix = match.group(1)!;
  final number = match.group(2)!;

  // POTA replaced the "K" prefix with "US" for United States parks.
  if (prefix == 'K') prefix = 'US';

  return '$prefix-$number';
}

/// Which Wavelog API a key belongs to.
///
/// Wavelog has two separate APIs with separate keys:
///  - v1: RPC style under /index.php/api/..., key sent in the JSON body.
///  - v2: REST style under /index.php/api/v2/..., key sent as a Bearer token.
///    v2 keys start with "wl2_" and carry scopes (e.g. qso:write).
/// Neither API accepts the other's keys.
enum WavelogApiVersion { v1, v2 }

/// Scopes a v2 key needs for everything the app currently does.
const List<String> wavelogV2RequiredScopes = ['station:read', 'qso:write', 'lookup:read'];

/// A Wavelog server plus API key, and how to talk to it.
class WavelogEndpoint {
  static const String v2KeyPrefix = 'wl2_';

  /// Root of the Wavelog install, e.g. "https://log.example.com".
  final String baseUrl;
  final String apiKey;

  WavelogEndpoint(String baseUrl, String apiKey)
      : baseUrl = normalizeBaseUrl(baseUrl),
        apiKey = apiKey.trim();

  static WavelogApiVersion versionForKey(String apiKey) =>
      apiKey.trim().startsWith(v2KeyPrefix) ? WavelogApiVersion.v2 : WavelogApiVersion.v1;

  WavelogApiVersion get version => versionForKey(apiKey);
  bool get isV2 => version == WavelogApiVersion.v2;
  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  /// Reduces whatever the user pasted to the install root, so both
  /// "https://log.example.com/" and ".../index.php/api/v2" work.
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    const suffixes = ['/', '/v2', '/api', '/index.php'];
    var changed = true;
    while (changed) {
      changed = false;
      for (final s in suffixes) {
        if (url.toLowerCase().endsWith(s)) {
          url = url.substring(0, url.length - s.length);
          changed = true;
        }
      }
    }
    return url;
  }

  /// Base of the API this key works with.
  String get apiRoot =>
      isV2 ? '$baseUrl/index.php/api/v2' : '$baseUrl/index.php/api';

  /// Full URL for an API path, e.g. uri('station') or uri('lookup', {...}).
  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$apiRoot/$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  /// Request headers. v2 authenticates with a Bearer token; v1 keys travel
  /// in the JSON body instead.
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (isV2) 'Authorization': 'Bearer $apiKey',
      };
}

/// Line shown under the API key field in Settings: which API the key is for,
/// the endpoint the app will call, and (for v2) the scopes the key needs.
String describeWavelogKey(String baseUrl, String apiKey) {
  if (apiKey.trim().isEmpty) return '';
  final ep = WavelogEndpoint(baseUrl, apiKey);
  final lines = <String>[ep.isV2 ? 'API v2 key' : 'API v1 key'];
  if (ep.baseUrl.isNotEmpty) lines.add('Endpoint: ${ep.apiRoot}');
  if (ep.isV2) lines.add('Needs scopes: ${wavelogV2RequiredScopes.join(', ')}');
  return lines.join('\n');
}

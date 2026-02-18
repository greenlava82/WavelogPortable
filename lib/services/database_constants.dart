class DatabaseConstants {
  // Table Names
  static const String tableSessions = 'sessions';
  static const String tableSessionQsos = 'session_qsos';
  static const String tableOfflineQsos = 'offline_qsos';
  static const String tableCallsignCache = 'callsign_cache';
  static const String tablePota = 'pota';
  static const String tableSota = 'sota';

  // Common Columns
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colTimestamp = 'timestamp';

  // Sessions Columns
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colIsActive = 'is_active';

  // Session QSO Columns
  static const String colSessionId = 'session_id';
  static const String colCallsign = 'callsign';
  static const String colBand = 'band';
  static const String colMode = 'mode';
  static const String colFreq = 'freq';
  static const String colRstSent = 'rst_sent';
  static const String colRstRcvd = 'rst_rcvd';
  static const String colPotaRef = 'pota_ref';
  static const String colSotaRef = 'sota_ref';
  static const String colGrid = 'grid';
  static const String colQth = 'qth';
  static const String colState = 'state';
  static const String colCountry = 'country';
  static const String colComment = 'comment';
  static const String colIsUploaded = 'is_uploaded';

  // Offline QSO Columns
  static const String colPayload = 'payload';

  // Search/Lookup Columns
  static const String colReference = 'reference';
  static const String colLocation = 'location';
  static const String colRegion = 'region';
}

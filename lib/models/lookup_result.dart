class LookupResult {
  final bool isWorked;      // Worked ever?
  final bool isWorkedBand;  // Worked on this band?
  final bool isWorkedMode;  // Worked on this band/mode?
  final bool isSessionDuplicate; // Duplicate in current session?

  LookupResult({
    this.isWorked = false, 
    this.isWorkedBand = false, 
    this.isWorkedMode = false,
    this.isSessionDuplicate = false,
  });
}
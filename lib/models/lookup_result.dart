class LookupResult {
  final bool isWorked;      // Worked ever?
  final bool isWorkedBand;  // Worked on this band?
  final bool isWorkedMode;  // Worked on this band/mode?

  LookupResult({
    this.isWorked = false, 
    this.isWorkedBand = false, 
    this.isWorkedMode = false
  });
}
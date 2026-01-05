class RstReport {
  double r = 5;
  double s = 9;
  double t = 9;

  String formatted(bool isCW) => "${r.toInt()}${s.toInt()}${isCW ? t.toInt() : ''}";
  
  void reset() { 
    r = 5; 
    s = 9; 
    t = 9; 
  }
}
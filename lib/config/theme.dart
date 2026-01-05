import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16, 
    fontWeight: FontWeight.bold, 
    color: Colors.black87
  );
  
  static BoxDecoration activeCard = BoxDecoration(
    color: Colors.blue[50],
    border: Border.all(color: primaryColor, width: 2),
    borderRadius: BorderRadius.circular(8),
  );

  static BoxDecoration inactiveCard = BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.grey[300]!),
    borderRadius: BorderRadius.circular(8),
  );
}

// [Min Freq, Max Freq, Default Freq]
const Map<String, List<double>> bandPlan = {
  '160m': [1.800, 2.000, 1.840],
  '80m':  [3.500, 4.000, 3.573],
  '60m':  [5.330, 5.405, 5.357],
  '40m':  [7.000, 7.300, 7.074],
  '30m':  [10.100, 10.150, 10.136],
  '20m':  [14.000, 14.350, 14.074],
  '17m':  [18.068, 18.168, 18.100],
  '15m':  [21.000, 21.450, 21.074],
  '12m':  [24.890, 24.990, 24.915],
  '10m':  [28.000, 29.700, 28.074],
  '6m':   [50.000, 54.000, 50.313],
  '2m':   [144.000, 148.000, 144.174],
  '70cm': [420.000, 450.000, 432.174],
};

const List<String> masterModeList = [
  'SSB', 'CW', 'FM', 'AM', 
  'DMR', 'C4FM', 'D-STAR', 
  'FT8', 'FT4', 'JS8', 'RTTY', 'PSK31', 
  'SSTV'
];

const List<String> defaultModes = [
  'SSB', 'CW', 'FM', 'AM', 'DMR'
];
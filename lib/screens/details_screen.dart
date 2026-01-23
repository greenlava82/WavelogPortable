// FILE: lib/screens/details_screen.dart
// ==============================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../models/rst_report.dart';
import '../models/lookup_result.dart';
import '../models/activity_ref.dart';
import '../widgets/radio_dial.dart';
import '../widgets/location_map_dialog.dart';
import '../widgets/activity_selection_dialog.dart';
import '../services/callsign_lookup.dart';
import '../services/wavelog_service.dart';
import '../services/settings_service.dart';
import '../utils/maidenhead.dart';

class QsoDetailsScreen extends StatefulWidget {
  final String callsign;
  const QsoDetailsScreen({super.key, required this.callsign});

  @override
  State<QsoDetailsScreen> createState() => _QsoDetailsScreenState();
}

class _QsoDetailsScreenState extends State<QsoDetailsScreen> {
  // Band & Freq
  final List<String> _bandList = bandPlan.keys.toList();
  double _bandSliderValue = 5.0; // Default to 20m
  String _selectedBand = '20m';
  double _currentFreq = 14.074;
  
  // Mode
  List<String> _activeModes = [];
  String _selectedMode = 'SSB';

   // Activity
  List<ActivityRef> _activeActivations = [];

  // Time
  DateTime _logTime = DateTime.now();
  bool _isManualTime = false;
  Timer? _timer;

  // Profile Data
  String _opName = "Loading..."; 
  String _opClass = "...";
  String _opCity = "Loading...";
  String _opState = "";
  String _opCountry = "";
  String _opGrid = "Loading...";
  double? _opLat;
  double? _opLon;

  // History & Reports
  bool _isLoadingHistory = true;
  LookupResult _historyStatus = LookupResult(); 
  final RstReport _sentRst = RstReport();
  final RstReport _rcvdRst = RstReport();

  @override
  void initState() {
    super.initState();
    _performLookup(); 
    _loadPreferences(); 
    
    Future.delayed(Duration.zero, () => _checkHistory()); 
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isManualTime && mounted) {
        setState(() {
          _logTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- 1. LOAD SETTINGS & RADIO STATE ---
  Future<void> _loadPreferences() async {
    List<String> savedModes = await AppSettings.getModes();
    Map<String, dynamic> lastState = await AppSettings.getLastRadioState();
    
    if (mounted) {
      setState(() {
        _activeModes = savedModes;
        
        if (lastState['band'] != null && _bandList.contains(lastState['band'])) {
          _selectedBand = lastState['band'];
          _bandSliderValue = _bandList.indexOf(_selectedBand).toDouble();
        }
        if (lastState['freq'] != null) {
          _currentFreq = lastState['freq'];
        }

        if (lastState['mode'] != null && _activeModes.contains(lastState['mode'])) {
          _selectedMode = lastState['mode'];
        } else if (!_activeModes.contains(_selectedMode) && _activeModes.isNotEmpty) {
          _selectedMode = _activeModes.first;
        }
      });
      _checkHistory();
    }
  }

  // --- 2. LOGIC: DUPE CHECK ---
  Future<void> _checkHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);

    var result = await WavelogService.checkDupe(
      widget.callsign, 
      _selectedBand, 
      _selectedMode
    );

    if (mounted) {
      setState(() {
        _historyStatus = result;
        _isLoadingHistory = false;
      });
    }
  }

  // --- 3. LOGIC: CALLSIGN LOOKUP ---
  Future<void> _performLookup() async {
    setState(() {
      _opName = "Looking up...";
      _opClass = "...";
      _opCity = "...";
      _opGrid = "...";
    });

    HamProfile profile = await CallsignLookup.fetch(widget.callsign);

    if (mounted) {
      setState(() {
        _opName = profile.name;
        _opClass = profile.licenseClass;
        _opCity = profile.city;
        _opState = profile.state;
        _opCountry = profile.country;
        _opGrid = profile.grid;
        // Store coordinates
        _opLat = profile.lat;
        _opLon = profile.lon;
      });
    }
  }

  // --- 4. LOGIC: LOG SUBMISSION (UPDATED FOR OFFLINE) ---
  Future<void> _submitLog() async {
    double cleanFreq = double.parse(_currentFreq.toStringAsFixed(3));
    DateTime utcTime = _logTime.toUtc();

    // 1. Save Radio State for next time
    await AppSettings.saveRadioState(_selectedBand, _currentFreq, _selectedMode);

    if (!mounted) return; 

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving Contact...'), duration: Duration(milliseconds: 500)),
    );

    // 2. Prepare References
    List<String> potaRefs = _activeActivations.where((a) => a.type == 'POTA').map((a) => a.reference).toList();
    List<String> sotaRefs = _activeActivations.where((a) => a.type == 'SOTA').map((a) => a.reference).toList();

    // 3. Post (or Queue)
    // Note: This method now returns FALSE if queued offline, but TRUE if uploaded live.
    bool liveUploadSuccess = await WavelogService.postQso(
      callsign: widget.callsign,
      band: _selectedBand,
      mode: _selectedMode,
      freq: cleanFreq,
      timeOn: utcTime,
      rstSent: _sentRst,
      rstRcvd: _rcvdRst,
      grid: _opGrid,
      name: _opName,
      qth: _opCity,
      state: _opState,
      country: _opCountry,
      potaList: potaRefs.join(','), 
      sotaRef: sotaRefs.isNotEmpty ? sotaRefs.first : null,
    );

    if (!mounted) return;

    if (liveUploadSuccess) {
      // ONLINE SUCCESS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log Uploaded Successfully!'), backgroundColor: Colors.green),
      );
    } else {
      // OFFLINE / QUEUED
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Signal? Saved to Offline Queue.'), 
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // In both cases, we return 'true' to clear the input screen and move on
    Navigator.pop(context, true); 
  }

  // --- UI HELPERS ---

  void _updateBandFromDial(double sliderValue) {
    int index = sliderValue.round();
    String newBand = _bandList[index];
    setState(() {
      _bandSliderValue = sliderValue;
      _selectedBand = newBand;
      _currentFreq = bandPlan[newBand]![2]; 
    });
    _checkHistory();
  }

  void _stepFreq(double sign) {
    double min = bandPlan[_selectedBand]![0];
    double max = bandPlan[_selectedBand]![1];
    double stepSize = 0.001; 

    double newFreq = _currentFreq + (sign * stepSize);
    newFreq = double.parse(newFreq.toStringAsFixed(3));

    if (newFreq < min) newFreq = min;
    if (newFreq > max) newFreq = max;

    setState(() => _currentFreq = newFreq);
  }

  String? _getBandForFreq(double freq) {
    for (var entry in bandPlan.entries) {
      if (freq >= entry.value[0] && freq <= entry.value[1]) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _logTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_logTime),
    );
    if (pickedTime == null) return;

    setState(() {
      _logTime = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute, 0 
      );
      _isManualTime = true; 
    });
  }

  void _resetToLiveTime() {
    setState(() {
      _isManualTime = false;
      _logTime = DateTime.now();
    });
  }

  void _showFrequencyInput() {
    String buffer = ""; 
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildKey(String label, {Color? color, Color? txtColor, int flex = 1}) {
              return Expanded(
                flex: flex,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color ?? Colors.grey[100],
                      foregroundColor: txtColor ?? Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (label == 'DEL') {
                        if (buffer.isNotEmpty) {
                          setDialogState(() => buffer = buffer.substring(0, buffer.length - 1));
                        }
                      } else if (label == 'ENT') {
                        if (buffer.isEmpty) return;
                        double? newFreq = double.tryParse(buffer);
                        if (newFreq != null) {
                          if (newFreq > 1000) newFreq = newFreq / 1000;
                          String? targetBand = _getBandForFreq(newFreq);
                          if (targetBand != null) {
                            setState(() {
                              _selectedBand = targetBand;
                              _bandSliderValue = _bandList.indexOf(targetBand).toDouble();
                              _currentFreq = newFreq!;
                            });
                            _checkHistory(); 
                            Navigator.pop(context);
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$newFreq MHz is outside supported bands'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      } else {
                        if (label == '.' && buffer.contains('.')) return;
                        setDialogState(() => buffer += label);
                      }
                    },
                    child: label == 'DEL' 
                      ? const Icon(Icons.backspace_outlined) 
                      : (label == 'ENT' ? const Icon(Icons.arrow_forward, size: 28) : Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(buffer.isEmpty ? "MHz / kHz" : buffer, textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: buffer.isEmpty ? Colors.grey : Colors.black)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [buildKey('1'), buildKey('2'), buildKey('3')]),
                    Row(children: [buildKey('4'), buildKey('5'), buildKey('6')]),
                    Row(children: [buildKey('7'), buildKey('8'), buildKey('9')]),
                    Row(children: [buildKey('.'), buildKey('0'), buildKey('DEL', color: Colors.red[50], txtColor: Colors.red)]),
                    const SizedBox(height: 8),
                    Row(children: [buildKey('ENT', color: AppTheme.primaryColor, txtColor: Colors.white)]),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showModePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Mode'),
          children: _activeModes.map((mode) {
            return SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              onPressed: () {
                setState(() => _selectedMode = mode);
                Navigator.pop(context);
                _checkHistory();
              },
              child: Text(mode, style: const TextStyle(fontSize: 18)),
            );
          }).toList(),
        );
      },
    );
  }

  void _showRstEditor(String title, RstReport report) {
    bool isCW = _selectedMode == 'CW';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("$title Report"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(report.formatted(isCW), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  const SizedBox(height: 20),
                  Row(children: [const SizedBox(width: 20, child: Text("R", style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Slider(value: report.r, min: 1, max: 5, divisions: 4, onChanged: (v) => setDialogState(() => report.r = v)))]),
                  Row(children: [const SizedBox(width: 20, child: Text("S", style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Slider(value: report.s, min: 1, max: 9, divisions: 8, onChanged: (v) => setDialogState(() => report.s = v)))]),
                  if (isCW) Row(children: [const SizedBox(width: 20, child: Text("T", style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Slider(value: report.t, min: 1, max: 9, divisions: 8, onChanged: (v) => setDialogState(() => report.t = v)))]),
                ],
              ),
              actions: [
                TextButton(onPressed: () => setDialogState(() => report.reset()), child: const Text("Reset 59")),
                ElevatedButton(onPressed: () { Navigator.pop(context); setState(() {}); }, child: const Text("Done"))
              ],
            );
          }
        );
      }
    );
  }

  void _showProfileEditor() {
    final nameCtrl = TextEditingController(text: (_opName == "Loading..." || _opName == "Looking up...") ? "" : _opName);
    final gridCtrl = TextEditingController(text: (_opGrid == "Loading..." || _opGrid == "...") ? "" : _opGrid);
    final cityCtrl = TextEditingController(text: (_opCity == "Loading..." || _opCity == "...") ? "" : _opCity);
    final stateCtrl = TextEditingController(text: (_opState == "..." || _opState == "---") ? "" : _opState);
    final countryCtrl = TextEditingController(text: (_opCountry == "..." || _opCountry == "---") ? "" : _opCountry);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Contact Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: gridCtrl, decoration: const InputDecoration(labelText: "Grid Square", border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City (QTH)", border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: "Country", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _opName = nameCtrl.text;
                _opGrid = gridCtrl.text;
                _opCity = cityCtrl.text;
                _opState = stateCtrl.text;
                _opCountry = countryCtrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- UPDATED MAP LOGIC ---
  void _showMap() {
    LatLng? target;
    
    // 1. Try exact coordinates (if Lookup provided them)
    if (_opLat != null && _opLon != null) {
      target = LatLng(_opLat!, _opLon!);
    } 
    // 2. Fallback to Grid Square
    else {
      target = MaidenheadLocator.toLatLng(_opGrid);
    }
    
    if (target != null) {
      showDialog(
        context: context,
        builder: (context) => LocationMapDialog(
          center: target!, 
          callsign: widget.callsign, 
          grid: _opGrid
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No location data for Map")),
      );
    }
  }

  Future<void> _showActivityDialog() async {
    final result = await showDialog<List<ActivityRef>>(
      context: context,
      builder: (context) => ActivitySelectionDialog(selected: _activeActivations),
    );

    if (result != null) {
      setState(() {
        _activeActivations = result;
      });
    }
  }

  Widget _buildHistoryBadge() {
    if (_isLoadingHistory) {
      return const SizedBox(
        width: 16, height: 16, 
        child: CircularProgressIndicator(strokeWidth: 2)
      );
    }

    const EdgeInsets badgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    const double fontSize = 12.0;
    
    if (_historyStatus.isWorked) {
      return Container(
        padding: badgePadding,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue)
        ),
        child: Text(
          "WORKED", 
          style: TextStyle(
            color: Colors.blue[900], 
            fontSize: fontSize, 
            fontWeight: FontWeight.bold
          )
        ),
      );
    } else {
      return Container(
        padding: badgePadding,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "NEW", 
          style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold)
        ),
      );
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    // Check if we have enough info to show the map button
    bool canShowMap = (_opLat != null && _opLon != null) || (_opGrid.length >= 4 && _opGrid != "Loading...");

    bool isCW = _selectedMode == 'CW';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Contact"), 
        backgroundColor: AppTheme.primaryColor, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _submitLog,
            icon: const Icon(Icons.save, size: 30),
            tooltip: "Save Contact",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER CARD
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: _showProfileEditor,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.callsign, 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: Icon(Icons.cancel, color: Colors.grey[400], size: 28),
                            tooltip: "Clear and Return",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),

                        const Spacer(), 

                        _buildHistoryBadge(),
                        
                        const SizedBox(width: 8), 

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100], 
                            borderRadius: BorderRadius.circular(8), 
                            border: Border.all(color: Colors.orange)
                          ),
                          child: Text(
                            _opClass.toUpperCase(), 
                            style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(_opName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                    const Divider(height: 20),
                    
                    // --- NEW LAYOUT: MAP ICON LEFT OF LOCATION ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Map Button (Left side)
                        if (canShowMap) ...[
                          SizedBox(
                            height: 36, // Slightly taller container
                            width: 36,
                            child: IconButton.filledTonal(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: const Icon(Icons.map_outlined),
                              onPressed: _showMap,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue[50],
                                foregroundColor: Colors.blue[800]
                              )
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Location Text (Right side)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_opState == "---" || _opState.isEmpty)
                                  ? "$_opCity, $_opCountry"
                                  : "$_opCity, $_opState, $_opCountry",
                                style: const TextStyle(color: Colors.black87, fontSize: 15),
                                overflow: TextOverflow.ellipsis
                              ),
                              const SizedBox(height: 4),
                              Text("Grid: $_opGrid", style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
            
            const SizedBox(height: 10),

            // BAND DIAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Band", style: AppTheme.sectionHeader),
                Text(_selectedBand, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 5),
            RadioDial(
              value: _bandSliderValue,
              min: 0,
              max: (_bandList.length - 1).toDouble(),
              divisions: _bandList.length - 1, 
              onChanged: _updateBandFromDial,
              activeColor: Colors.orange,
            ),
            
            const SizedBox(height: 20),

            // FREQ DIAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Frequency", style: AppTheme.sectionHeader),
                InkWell(
                  onTap: _showFrequencyInput,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(children: [const Icon(Icons.keyboard, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 6), Text("${_currentFreq.toStringAsFixed(3)} MHz", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.green[100], foregroundColor: Colors.green[900]),
                  onPressed: () => _stepFreq(-1.0), 
                  icon: const Icon(Icons.remove), 
                  tooltip: "-1 kHz"
                ),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: RadioDial(value: _currentFreq, min: bandPlan[_selectedBand]![0], max: bandPlan[_selectedBand]![1], divisions: ((bandPlan[_selectedBand]![1] - bandPlan[_selectedBand]![0]) * 1000).toInt(), onChanged: (v) => setState(() => _currentFreq = v), activeColor: Colors.redAccent))),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.green[100], foregroundColor: Colors.green[900]),
                  onPressed: () => _stepFreq(1.0), 
                  icon: const Icon(Icons.add), 
                  tooltip: "+1 kHz"
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: [
                const Text("Mode / Activity", style: AppTheme.sectionHeader),
                
                if (_activeActivations.isNotEmpty)
                  Expanded(
                    child: Text(
                      _activeActivations.map((e) => e.reference).join(', '),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.green[800], 
                        fontWeight: FontWeight.bold, 
                        fontSize: 13
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onTap: _showModePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedMode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryColor)
                        ]
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 10),
                
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _showActivityDialog,
                    child: Container(
                      height: 50, 
                      decoration: BoxDecoration(
                        color: _activeActivations.isNotEmpty ? Colors.green[100] : Colors.white,
                        border: Border.all(
                          color: _activeActivations.isNotEmpty ? Colors.green : Colors.grey[400]!
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.terrain, 
                        color: _activeActivations.isNotEmpty ? Colors.green[800] : Colors.grey[600]
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 40),

            const Text("Signal Report", style: AppTheme.sectionHeader),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showRstEditor("Sent", _sentRst),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: AppTheme.activeCard.copyWith(color: Colors.blue[50]),
                      child: Column(children: [const Text("SENT", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(_sentRst.formatted(isCW), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blue)), const SizedBox(height: 5), const Text("Tap to Edit", style: TextStyle(fontSize: 10, color: Colors.blueGrey))]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _showRstEditor("Received", _rcvdRst),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: AppTheme.activeCard.copyWith(color: Colors.green[50], border: Border.all(color: Colors.green, width: 2)),
                      child: Column(children: [const Text("RCVD", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(_rcvdRst.formatted(isCW), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)), const SizedBox(height: 5), const Text("Tap to Edit", style: TextStyle(fontSize: 10, color: Colors.blueGrey))]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), 

            Card(
              color: _isManualTime ? Colors.amber[50] : Colors.green[50], 
              elevation: 0,
              shape: RoundedRectangleBorder(
                  side: BorderSide(
                   color: _isManualTime ? Colors.amber[200]! : Colors.green[200]!
                  ), 
                  borderRadius: BorderRadius.circular(12)
              ),
              child: InkWell(
                onTap: _pickDateTime, 
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, 
                          color: _isManualTime ? Colors.amber[900] : AppTheme.primaryColor
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_formatDateTime(_logTime, isUtc: true)} UTC",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                            Text(
                              "${_formatDateTime(_logTime, isUtc: false)} Local",
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      if (_isManualTime)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          onPressed: _resetToLiveTime,
                          tooltip: "Reset to Live Clock",
                        )
                      else
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt, {bool isUtc = false}) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    DateTime t = isUtc ? dt.toUtc() : dt;
    return "${t.year}-${twoDigits(t.month)}-${twoDigits(t.day)} ${twoDigits(t.hour)}:${twoDigits(t.minute)}:${twoDigits(t.second)}";
  }
}
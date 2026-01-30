import 'package:flutter/material.dart';
import 'details_screen.dart';
import 'settings_screen.dart';
import 'sessions_list_screen.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../services/session_service.dart';
import '../services/wavelog_service.dart'; // For Station fetching in Sync Dialog


class CallsignInputScreen extends StatefulWidget {
  const CallsignInputScreen({super.key});
  @override
  State<CallsignInputScreen> createState() => _CallsignInputScreenState();
}

class _CallsignInputScreenState extends State<CallsignInputScreen> {
  final TextEditingController _callsignController = TextEditingController();
  
  final List<List<String>> _keyboardRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['DEL', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '/', 'ENT']
  ];

  @override
  void initState() {
    super.initState();
    SessionService().init(); // Init Service
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSettings());
  }

  Future<void> _checkSettings() async {
    String call = await AppSettings.getString(AppSettings.keyMyCallsign);
    String grid = await AppSettings.getString(AppSettings.keyMyGrid);

    if (call.isEmpty || grid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please configure your Station first"), duration: Duration(seconds: 3)),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      }
    }
  }

  void _handleKeyTap(String value) {
    setState(() {
      if (value == 'DEL') {
        if (_callsignController.text.isNotEmpty) {
          _callsignController.text = _callsignController.text.substring(0, _callsignController.text.length - 1);
        }
      } else if (value == 'ENT') {
        if (_callsignController.text.isEmpty) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => QsoDetailsScreen(callsign: _callsignController.text)),
        ).then((result) {
          // Clear only if contact was logged successfully
          if (result == true) {
            setState(() {
              _callsignController.clear();
            });
          }
        });
        
      } else {
        _callsignController.text += value;
      }
    });
  }

  Widget _buildButtonContent(String key) {
    if (key == 'DEL') return const Icon(Icons.backspace_outlined, size: 24);
    if (key == 'ENT') return const Icon(Icons.arrow_forward, size: 28);
    return Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  // --- DRAWER ACTIONS ---
  
  void _toggleOffline(bool value) {
    SessionService().setOfflineMode(value);

    // If turning OFF offline mode (going online), prompt to sync
    if (!value) {
      // Close drawer first if open? The switch is in the drawer. 
      // User might toggle and stay in drawer. 
      // But typically we want to show the dialog over the screen.
      // Navigator.pop(context); // Close drawer to show dialog clearly? 
      // Actually, let's keep drawer open or closed depending on user pref, 
      // but showing a dialog on top works.
      
      // Wait a tick for state to update
      Future.delayed(Duration.zero, () {
        if (mounted) _showSyncDialog(isFromToggle: true);
      });
    }
  }

  Future<void> _startSessionDialog() async {
    TextEditingController nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Start Session"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: "Session Name (e.g. POTA K-1234)"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                SessionService().startSession(nameCtrl.text);
                Navigator.pop(context);
              }
            }, 
            child: const Text("Start")
          )
        ],
      )
    );
  }

  void _stopSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("End Session?"),
        content: Text("Stop logging to '${SessionService().currentSession?.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              SessionService().stopSession();
              Navigator.pop(context);
            }, 
            child: const Text("End Session")
          )
        ],
      )
    );
  }

  Future<void> _showSyncDialog({bool isFromToggle = false}) async {
    // 1. Fetch stations first (assume online now)
    String url = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String key = await AppSettings.getString(AppSettings.keyWavelogKey);
    
    // Check if we are actually online (unless we just toggled it off)
    if (SessionService().isOfflineMode && !isFromToggle) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Must be Online to Sync! Disable Offline Mode first.")));
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, String>> stations = await WavelogService.fetchStations(url, key);
    
    if (!mounted) return;
    Navigator.pop(context); // Close spinner

    if (stations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to fetch stations. Check settings/internet.")));
      // If failed and came from toggle, maybe revert?
      if (isFromToggle) {
         SessionService().setOfflineMode(true);
      }
      return;
    }

    // 2. Show Picker
    String? selectedStationId;
    
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Sync Pending QSOs"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select the Station Profile to upload to:"),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Select Station"),
                  value: selectedStationId,
                  items: stations.map((s) => DropdownMenuItem(
                    value: s['id'],
                    child: Text(s['name'] ?? "Unknown"),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedStationId = v),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // If canceled and came from toggle, revert to offline
                  if (isFromToggle) {
                    SessionService().setOfflineMode(true);
                  }
                }, 
                child: const Text("Cancel")
              ),
              ElevatedButton(
                onPressed: selectedStationId == null ? null : () {
                  Navigator.pop(context);
                  _performSync(int.parse(selectedStationId!));
                },
                child: const Text("Sync Now"),
              )
            ],
          );
        }
      )
    );
  }

  Future<void> _performSync(int stationId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()), // Simple loader
    );

    await SessionService().flushQueue(stationId, (current, total) {
       // Optional: Update progress UI
    });

    if (!mounted) return;
    Navigator.pop(context); // Close loader
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Complete!")));
  }

  @override
  Widget build(BuildContext context) {
    bool showClear = _callsignController.text.isNotEmpty;

    return ListenableBuilder(
      listenable: SessionService(),
      builder: (context, child) {
        final sessionService = SessionService();
        bool isOffline = sessionService.isOfflineMode;
        String? sessionName = sessionService.currentSession?.name;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Wavelog Portable'), 
            backgroundColor: isOffline ? Colors.grey[800] : AppTheme.primaryColor, 
            foregroundColor: Colors.white,
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: isOffline ? Colors.grey[800] : AppTheme.primaryColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
                      const SizedBox(height: 8),
                      if (sessionName != null) 
                        Text("Active Session:\n$sessionName", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text("Offline Mode"),
                  subtitle: const Text("Queue contacts locally"),
                  value: isOffline,
                  secondary: Icon(isOffline ? Icons.cloud_off : Icons.cloud_queue),
                  onChanged: _toggleOffline,
                ),
                const Divider(),
                ListTile(
                  title: Text(sessionName == null ? "Start Session" : "End Session"),
                  subtitle: Text(sessionName == null ? "Group contacts (e.g. POTA)" : "Current: $sessionName"),
                  leading: Icon(sessionName == null ? Icons.play_arrow : Icons.stop, color: sessionName == null ? Colors.green : Colors.red),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    if (sessionName == null) {
                      _startSessionDialog();
                    } else {
                      _stopSession();
                    }
                  },
                ),
                ListTile(
                  title: const Text("Manage Sessions"),
                  subtitle: const Text("View history, resume, or delete"),
                  leading: const Icon(Icons.history),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionsListScreen()));
                  },
                ),
                ListTile(
                  title: const Text("Sync Queue"),
                  subtitle: FutureBuilder<List<Map<String, dynamic>>>(
                    future: sessionService.getQueue(),
                    builder: (context, snapshot) {
                      int count = snapshot.data?.length ?? 0;
                      return Text("$count QSOs pending");
                    },
                  ),
                  leading: const Icon(Icons.sync),
                  onTap: () {
                     Navigator.pop(context);
                     _showSyncDialog();
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text("Settings"),
                  leading: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                  },
                )
              ],
            ),
          ),
          body: Column(
            children: [
              // STATUS BANNER
              if (isOffline || sessionName != null)
                Container(
                  width: double.infinity,
                  color: isOffline ? Colors.orange[800] : Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(isOffline ? Icons.cloud_off : Icons.check_circle, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        isOffline 
                          ? (sessionName != null ? "OFFLINE • Session: $sessionName" : "OFFLINE MODE")
                          : "Session: $sessionName",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: TextField(
                      controller: _callsignController,
                      readOnly: true, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 2),
                      decoration: InputDecoration(
                        hintText: "CALLSIGN",
                        hintStyle: TextStyle(color: Colors.grey[300]),
                        border: InputBorder.none,
                        suffixIcon: showClear 
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.grey, size: 30),
                              onPressed: () {
                                setState(() {
                                  _callsignController.clear();
                                });
                              },
                            )
                          : null,
                      ),
                    ),
                  ),
                ),
              ),
              
              SafeArea(
                top: false, bottom: true,
                child: Container(
                  color: Colors.grey[300],
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: _keyboardRows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: row.map((key) => Expanded(
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _handleKeyTap(key),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: (key == 'DEL' || key == 'ENT') ? Colors.blueGrey[200] : Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 1,
                            ),
                            child: _buildButtonContent(key),
                          ),
                        ))
                      )).toList()),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
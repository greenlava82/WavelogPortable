import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/wavelog_service.dart';
import '../services/settings_service.dart';
import '../config/theme.dart';
import '../screens/settings_screen.dart';
import '../screens/sessions_list_screen.dart';

class SessionDrawer extends StatefulWidget {
  const SessionDrawer({super.key});

  @override
  State<SessionDrawer> createState() => _SessionDrawerState();
}

class _SessionDrawerState extends State<SessionDrawer> {
  // Flutter removes the drawer from the tree once it closes, so dialogs and
  // async follow-up work must use the screen's (Scaffold's) context, which
  // stays mounted. Capture it before closing the drawer.
  BuildContext get _hostContext => Scaffold.of(context).context;

  void _toggleOffline(bool value) {
    final host = _hostContext;
    SessionService().setOfflineMode(value);

    // If turning OFF offline mode (going online), prompt to sync
    if (!value) {
      // Wait a tick for state to update
      Future.delayed(Duration.zero, () {
        if (host.mounted) _showSyncDialog(host, isFromToggle: true);
      });
    }
  }

  Future<void> _startSessionDialog(BuildContext host) async {
    TextEditingController nameCtrl = TextEditingController();
    await showDialog(
      context: host,
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

  void _stopSession(BuildContext host) {
    showDialog(
      context: host,
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

  Future<void> _showSyncDialog(BuildContext host, {bool isFromToggle = false}) async {
    // 1. Fetch stations first (assume online now)
    String url = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String key = await AppSettings.getString(AppSettings.keyWavelogKey);
    
    // Check if we are actually online (unless we just toggled it off)
    if (SessionService().isOfflineMode && !isFromToggle) {
      if (!host.mounted) return;
      ScaffoldMessenger.of(host).showSnackBar(const SnackBar(content: Text("Must be Online to Sync! Disable Offline Mode first.")));
      return;
    }

    if (!host.mounted) return;
    showDialog(
      context: host,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, String>> stations = await WavelogService.fetchStations(url, key);
    
    if (!host.mounted) return;
    Navigator.pop(host); // Close spinner

    if (stations.isEmpty) {
      ScaffoldMessenger.of(host).showSnackBar(const SnackBar(content: Text("Failed to fetch stations. Check settings/internet.")));
      // If failed and came from toggle, maybe revert?
      if (isFromToggle) {
         SessionService().setOfflineMode(true);
      }
      return;
    }

    // 2. Show Picker
    String? selectedStationId;
    
    await showDialog(
      context: host,
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
                  _performSync(host, int.parse(selectedStationId!));
                },
                child: const Text("Sync Now"),
              )
            ],
          );
        }
      )
    );
  }

  Future<void> _performSync(BuildContext host, int stationId) async {
    showDialog(
      context: host,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()), // Simple loader
    );

    await SessionService().flushQueue(stationId, (current, total) {
       // Optional: Update progress UI
    });

    if (!host.mounted) return;
    Navigator.pop(host); // Close loader
    ScaffoldMessenger.of(host).showSnackBar(const SnackBar(content: Text("Sync Complete!")));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionService(),
      builder: (context, child) {
        final sessionService = SessionService();
        bool isOffline = sessionService.isOfflineMode;
        String? sessionName = sessionService.currentSession?.name;

        return Drawer(
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
                  final host = _hostContext;
                  Navigator.pop(context); // Close drawer
                  if (sessionName == null) {
                    _startSessionDialog(host);
                  } else {
                    _stopSession(host);
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
                   final host = _hostContext;
                   Navigator.pop(context);
                   _showSyncDialog(host);
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
        );
      }
    );
  }
}

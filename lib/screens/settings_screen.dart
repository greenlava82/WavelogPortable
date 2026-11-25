import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../services/streak_reminder.dart';
import '../services/wavelog_service.dart';
import '../services/wavelog_endpoint.dart';
import '../services/database_service.dart';
import '../widgets/app_about_dialog.dart';
import '../utils/park_list_status.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _callsignCtrl = TextEditingController();
  final _gridCtrl = TextEditingController();
  final _wavelogUrlCtrl = TextEditingController();
  final _wavelogKeyCtrl = TextEditingController();
  final _hamqthUserCtrl = TextEditingController();
  final _hamqthPassCtrl = TextEditingController();

  List<String> _activeModes = [];
  
  String? _selectedStationId;
  List<Map<String, String>> _availableStations = [];
  bool _isLoadingStations = false;
  String _parkListStatus = '';
  bool _streakReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadParkListStatus();
  }

  Future<void> _loadParkListStatus() async {
    final count = await DatabaseService().getPotaCount();
    final stamp = await AppSettings.getString(AppSettings.keyPotaDownloadedAt);
    final status = parkListStatus(
      downloadedAt: DateTime.tryParse(stamp),
      parkCount: count,
      now: DateTime.now(),
    );
    if (mounted) setState(() => _parkListStatus = status);
  }

  Future<void> _loadSettings() async {
    String call = await AppSettings.getString(AppSettings.keyMyCallsign);
    String grid = await AppSettings.getString(AppSettings.keyMyGrid);
    String url = await AppSettings.getString(AppSettings.keyWavelogUrl);

    // Migration: keep only the install root (strips /index.php/api, /api/v2, ...)
    final normalized = WavelogEndpoint.normalizeBaseUrl(url);
    if (normalized != url) {
      url = normalized;
      await AppSettings.saveString(AppSettings.keyWavelogUrl, url);
    }

    String key = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stId = await AppSettings.getString(AppSettings.keyWavelogStationId);
    String hUser = await AppSettings.getString(AppSettings.keyHamQthUser);
    String hPass = await AppSettings.getString(AppSettings.keyHamQthPass);
    List<String> modes = await AppSettings.getModes();
    bool streakReminderEnabled = await AppSettings.getStreakReminderEnabled();

    setState(() {
      _callsignCtrl.text = call;
      _gridCtrl.text = grid;
      _wavelogUrlCtrl.text = url;
      _wavelogKeyCtrl.text = key;
      _hamqthUserCtrl.text = hUser;
      _hamqthPassCtrl.text = hPass;
      _activeModes = modes;
      _streakReminderEnabled = streakReminderEnabled;
      
      if (stId.isNotEmpty) {
        _selectedStationId = stId;
        _availableStations = [{'id': stId, 'name': 'Saved ID: $stId (Tap Refresh)'}];
      }
    });
  }

  Future<void> _fetchStationList() async {
    if (_wavelogUrlCtrl.text.isEmpty || _wavelogKeyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter URL and Key first")));
      return;
    }

    setState(() => _isLoadingStations = true);

    final (stations, error) = await WavelogService.fetchStationsWithError(
      _wavelogUrlCtrl.text,
      _wavelogKeyCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _isLoadingStations = false;
      if (stations.isNotEmpty) {
        _availableStations = stations;
        
        bool found = stations.any((s) => s['id'] == _selectedStationId);
        if (!found) {
          _selectedStationId = stations.first['id'];
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${stations.length} profiles"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No profiles found: ${error ?? 'check URL/Key'}"), backgroundColor: Colors.orange));
      }
    });
  }

  Future<void> _saveAll() async {
    await AppSettings.saveString(AppSettings.keyMyCallsign, _callsignCtrl.text.toUpperCase());
    await AppSettings.saveString(AppSettings.keyMyGrid, _gridCtrl.text.toUpperCase());
    _wavelogUrlCtrl.text = WavelogEndpoint.normalizeBaseUrl(_wavelogUrlCtrl.text);
    _wavelogKeyCtrl.text = _wavelogKeyCtrl.text.trim();
    await AppSettings.saveString(AppSettings.keyWavelogUrl, _wavelogUrlCtrl.text);
    await AppSettings.saveString(AppSettings.keyWavelogKey, _wavelogKeyCtrl.text);
    await AppSettings.saveString(AppSettings.keyWavelogStationId, _selectedStationId ?? "");
    await AppSettings.saveString(AppSettings.keyHamQthUser, _hamqthUserCtrl.text);
    await AppSettings.saveString(AppSettings.keyHamQthPass, _hamqthPassCtrl.text);
    await AppSettings.saveModes(_activeModes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings Saved'), backgroundColor: Colors.green),
      );
    }
  }

  void _toggleMode(String mode, bool isActive) {
    setState(() {
      if (isActive) {
        _activeModes.add(mode);
      } else {
        _activeModes.remove(mode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveAll,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.save, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader("My Station"),
          _buildTextField("My Callsign", _callsignCtrl, icon: Icons.face),
          _buildTextField("My Grid Square", _gridCtrl, icon: Icons.grid_4x4),

          _buildHeader("Active Modes"),
          Card(
            child: ExpansionTile(
              title: Text("${_activeModes.length} Modes Selected"),
              children: masterModeList.map((mode) {
                return CheckboxListTile(
                  title: Text(mode),
                  value: _activeModes.contains(mode),
                  onChanged: (val) => _toggleMode(mode, val!),
                  dense: true,
                );
              }).toList(),
            ),
          ),

          _buildHeader("Wavelog Integration"),
          _buildTextField("Wavelog URL", _wavelogUrlCtrl, hint: "https://log.mysite.com", icon: Icons.link),
          _buildTextField("API Key (v1 or v2 wl2_...)", _wavelogKeyCtrl, icon: Icons.vpn_key),
          ListenableBuilder(
            listenable: Listenable.merge([_wavelogUrlCtrl, _wavelogKeyCtrl]),
            builder: (context, _) {
              final info = describeWavelogKey(_wavelogUrlCtrl.text, _wavelogKeyCtrl.text);
              if (info.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(info, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              );
            },
          ),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Station Profile",
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStationId,
                        isExpanded: true,
                        hint: const Text("Tap Refresh to Load"),
                        items: _availableStations.map((station) {
                          return DropdownMenuItem<String>(
                            value: station['id'],
                            child: Text(station['name']!, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedStationId = val),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isLoadingStations 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.refresh, color: Colors.blue),
                    onPressed: _fetchStationList,
                    tooltip: "Fetch Profiles from Wavelog",
                  ),
                ],
              ),
            ),
          ),

          _buildHeader("QRZ Login (optional)"),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              "With a QRZ login, lookups come straight from QRZ: full names and licence class. Without one, they come from the callbook set up on your Wavelog server (with HamQTH that's usually a first name only).",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          _buildTextField("Username", _hamqthUserCtrl, icon: Icons.person),
          _buildTextField("Password", _hamqthPassCtrl, obscure: true, icon: Icons.lock),
          

          _buildHeader("Daily Streak"),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Streak reminder"),
            subtitle: const Text(
                "Notifies you at 21:45 UTC if you have no contact today. The streak always shows on the main screen with an API v2 (wl2_) key."),
            value: _streakReminderEnabled,
            onChanged: (on) async {
              setState(() => _streakReminderEnabled = on);
              await AppSettings.setStreakReminderEnabled(on);
              if (on) {
                await StreakReminder.allowPermissionPrompt();
                await StreakReminder.schedule();
              } else {
                await StreakReminder.cancel();
              }
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text("Send test reminder"),
              subtitle: const Text("Development builds only: shows the 21:45 UTC warning now."),
              onTap: StreakReminder.showTest,
            ),

          _buildHeader("Databases"),
          ListTile(
            title: const Text("Download POTA/SOTA Databases"),
            subtitle: Text(_parkListStatus.isEmpty ? "Required for offline search" : "Parks: $_parkListStatus"),
            leading: const Icon(Icons.cloud_download),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Starting Download... Check Debug Console"), duration: Duration(seconds: 2))
              );
              
              await DatabaseService().updateAllDatabases((status) {
                // Status updates are handled via SnackBar notifications
              });
              await _loadParkListStatus();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Database Update Complete!"), backgroundColor: Colors.green)
                );
              }
            },
          ),
          _buildHeader("About"),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
            title: const Text("App Info & Version"),
            subtitle: const Text("Developer credits and links"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const AppAboutDialog(),
              );
            },
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {String? hint, bool obscure = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
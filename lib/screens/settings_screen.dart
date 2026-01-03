// FILE: lib/screens/settings_screen.dart
// ==============================
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers for text fields
  final _callsignCtrl = TextEditingController();
  final _gridCtrl = TextEditingController();
  final _wavelogUrlCtrl = TextEditingController();
  final _wavelogKeyCtrl = TextEditingController();
  final _wavelogStationIdCtrl = TextEditingController(); // <--- NEW
  final _hamqthUserCtrl = TextEditingController();
  final _hamqthPassCtrl = TextEditingController();

  // Mode State
  List<String> _activeModes = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load all data from disk
    String call = await AppSettings.getString(AppSettings.keyMyCallsign);
    String grid = await AppSettings.getString(AppSettings.keyMyGrid);
    String url = await AppSettings.getString(AppSettings.keyWavelogUrl);
    String key = await AppSettings.getString(AppSettings.keyWavelogKey);
    String stId = await AppSettings.getString(AppSettings.keyWavelogStationId); // <--- NEW
    String hUser = await AppSettings.getString(AppSettings.keyHamQthUser);
    String hPass = await AppSettings.getString(AppSettings.keyHamQthPass);
    List<String> modes = await AppSettings.getModes();

    setState(() {
      _callsignCtrl.text = call;
      _gridCtrl.text = grid;
      _wavelogUrlCtrl.text = url;
      _wavelogKeyCtrl.text = key;
      _wavelogStationIdCtrl.text = stId; // <--- NEW
      _hamqthUserCtrl.text = hUser;
      _hamqthPassCtrl.text = hPass;
      _activeModes = modes;
    });
  }

  Future<void> _saveAll() async {
    await AppSettings.saveString(AppSettings.keyMyCallsign, _callsignCtrl.text.toUpperCase());
    await AppSettings.saveString(AppSettings.keyMyGrid, _gridCtrl.text.toUpperCase());
    await AppSettings.saveString(AppSettings.keyWavelogUrl, _wavelogUrlCtrl.text);
    await AppSettings.saveString(AppSettings.keyWavelogKey, _wavelogKeyCtrl.text);
    await AppSettings.saveString(AppSettings.keyWavelogStationId, _wavelogStationIdCtrl.text); // <--- NEW
    await AppSettings.saveString(AppSettings.keyHamQthUser, _hamqthUserCtrl.text);
    await AppSettings.saveString(AppSettings.keyHamQthPass, _hamqthPassCtrl.text);
    await AppSettings.saveModes(_activeModes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings Saved'), backgroundColor: Colors.green),
      );
    }
  }

  // Helper to toggle modes in the list
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
      // Save Button FAB
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
          _buildTextField("Wavelog URL", _wavelogUrlCtrl, hint: "https://log.mysite.com/index.php/api", icon: Icons.link),
          _buildTextField("API Key", _wavelogKeyCtrl, icon: Icons.vpn_key),
          _buildTextField("Station Profile ID", _wavelogStationIdCtrl, hint: "e.g. 1 (Find in Wavelog URL)", icon: Icons.location_on), // <--- NEW

          _buildHeader("Lookup Credentials (QRZ / HamQTH)"),
          _buildTextField("Username", _hamqthUserCtrl, icon: Icons.person),
          _buildTextField("Password", _hamqthPassCtrl, obscure: true, icon: Icons.lock),
          
          const SizedBox(height: 80), // Space for FAB
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
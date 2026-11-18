import 'package:flutter/material.dart';
import 'details_screen.dart';
import 'settings_screen.dart';
import 'logbook_screen.dart';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../services/session_service.dart';
import '../widgets/keypad.dart';
import '../widgets/session_drawer.dart';
import '../widgets/status_banner.dart';


class CallsignInputScreen extends StatefulWidget {
  const CallsignInputScreen({super.key});
  @override
  State<CallsignInputScreen> createState() => _CallsignInputScreenState();
}

class _CallsignInputScreenState extends State<CallsignInputScreen> {
  final TextEditingController _callsignController = TextEditingController();
  
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
            actions: [
              IconButton(
                tooltip: 'Logbook',
                icon: const Icon(Icons.menu_book),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogbookScreen()),
                ),
              ),
            ],
          ),
          drawer: const SessionDrawer(),
          body: Column(
            children: [
              StatusBanner(isOffline: isOffline, sessionName: sessionName),

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
                child: KeypadWidget(onKeyTap: _handleKeyTap),
              ),
            ],
          ),
        );
      }
    );
  }
}
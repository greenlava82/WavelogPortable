import 'package:flutter/material.dart';
import 'details_screen.dart';
import 'settings_screen.dart';
import '../config/theme.dart';


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

  @override
  Widget build(BuildContext context) {
    bool showClear = _callsignController.text.isNotEmpty;

    return Scaffold(
    appBar: AppBar(
        title: const Text('Wavelog Portable'), 
        backgroundColor:  AppTheme.primaryColor, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
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
}
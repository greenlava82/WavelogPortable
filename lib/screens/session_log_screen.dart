import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/session_qso.dart';
import '../services/session_service.dart';
import '../config/theme.dart';
import 'edit_qso_screen.dart';

class SessionLogScreen extends StatefulWidget {
  final Session session;
  const SessionLogScreen({super.key, required this.session});

  @override
  State<SessionLogScreen> createState() => _SessionLogScreenState();
}

class _SessionLogScreenState extends State<SessionLogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<SessionQso> _qsos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQsos();
  }

  Future<void> _loadQsos() async {
    if (widget.session.id == null) return;
    
    setState(() => _isLoading = true);
    
    List<SessionQso> results;
    if (_searchCtrl.text.isEmpty) {
      results = await SessionService().getSessionQsos(widget.session.id!);
    } else {
      results = await SessionService().searchSessionQsos(widget.session.id!, _searchCtrl.text);
    }

    if (mounted) {
      setState(() {
        _qsos = results;
        _isLoading = false;
      });
    }
  }

  void _editQso(SessionQso qso) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditQsoScreen(qso: qso)),
    );
    _loadQsos(); // Refresh after edit
  }

  String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(dt.hour)}:${twoDigits(dt.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search callsign, name, comment...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _loadQsos(); })
                  : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _loadQsos(),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _qsos.isEmpty 
                ? const Center(child: Text("No QSOs found."))
                : ListView.builder(
                    itemCount: _qsos.length,
                    itemBuilder: (context, index) {
                      final q = _qsos[index];
                      return ListTile(
                        onTap: () => _editQso(q),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(q.band, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(q.mode, style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                        title: Text(q.callsign, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(
                          "${_formatDate(q.timestamp)} • ${q.rstSent} / ${q.rstRcvd}${q.name != null ? ' • ${q.name}' : ''}"
                        ),
                        trailing: q.isUploaded 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cloud_upload_outlined, color: Colors.grey),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

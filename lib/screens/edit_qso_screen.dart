import 'package:flutter/material.dart';
import '../models/session_qso.dart';
import '../models/rst_report.dart';
import '../services/session_service.dart';
import '../config/theme.dart';

class EditQsoScreen extends StatefulWidget {
  final SessionQso qso;
  const EditQsoScreen({super.key, required this.qso});

  @override
  State<EditQsoScreen> createState() => _EditQsoScreenState();
}

class _EditQsoScreenState extends State<EditQsoScreen> {
  late TextEditingController _callsignCtrl;
  late TextEditingController _freqCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _gridCtrl;
  late TextEditingController _commentCtrl;
  
  late String _selectedBand;
  late String _selectedMode;
  late DateTime _timestamp;
  
  late double _rstSentR;
  late double _rstSentS;
  late double _rstSentT;

  late double _rstRcvdR;
  late double _rstRcvdS;
  late double _rstRcvdT;
  
  final List<String> _bands = bandPlan.keys.toList();
  final List<String> _modes = ['SSB', 'CW', 'FM', 'AM', 'FT8', 'FT4', 'JS8', 'PSK31', 'RTTY'];

  @override
  void initState() {
    super.initState();
    _callsignCtrl = TextEditingController(text: widget.qso.callsign);
    _freqCtrl = TextEditingController(text: widget.qso.freq.toString());
    _nameCtrl = TextEditingController(text: widget.qso.name ?? "");
    _gridCtrl = TextEditingController(text: widget.qso.grid ?? "");
    _commentCtrl = TextEditingController(text: widget.qso.comment ?? "");
    
    _selectedBand = widget.qso.band;
    _selectedMode = widget.qso.mode;
    _timestamp = widget.qso.timestamp;
    
    // Parse RST
    final rstS = _parseRst(widget.qso.rstSent);
    _rstSentR = rstS.r; _rstSentS = rstS.s; _rstSentT = rstS.t;
    
    final rstR = _parseRst(widget.qso.rstRcvd);
    _rstRcvdR = rstR.r; _rstRcvdS = rstR.s; _rstRcvdT = rstR.t;
  }

  RstReport _parseRst(String rst) {
    RstReport r = RstReport();
    // Simple parse, assuming 59 or 599 format mainly.
    // If complex, we might default.
    try {
      if (rst.length >= 2) {
        r.r = double.parse(rst[0]);
        r.s = double.parse(rst[1]);
        if (rst.length >= 3) r.t = double.parse(rst[2]);
      }
    } catch (e) {
      // ignore
    }
    return r;
  }
  
  String _formatRst(double r, double s, double t, bool isCW) {
    String res = "${r.toInt()}${s.toInt()}";
    if (isCW) res += "${t.toInt()}";
    return res;
  }

  Future<void> _save() async {
    // Reconstruct RST strings
    bool isCW = _selectedMode == 'CW';
    String sent = _formatRst(_rstSentR, _rstSentS, _rstSentT, isCW);
    String rcvd = _formatRst(_rstRcvdR, _rstRcvdS, _rstRcvdT, isCW);

    final updatedQso = SessionQso(
      id: widget.qso.id,
      sessionId: widget.qso.sessionId,
      callsign: _callsignCtrl.text,
      band: _selectedBand,
      mode: _selectedMode,
      freq: double.tryParse(_freqCtrl.text) ?? widget.qso.freq,
      timestamp: _timestamp,
      rstSent: sent,
      rstRcvd: rcvd,
      grid: _gridCtrl.text,
      name: _nameCtrl.text,
      comment: _commentCtrl.text,
      // Preserve others
      potaRef: widget.qso.potaRef,
      sotaRef: widget.qso.sotaRef,
      qth: widget.qso.qth,
      state: widget.qso.state,
      country: widget.qso.country,
      isUploaded: widget.qso.isUploaded // Keep status, or reset to false if edited? 
      // Typically if edited, we might want to re-upload. 
      // But simple edit might just be local correction. 
      // Let's keep it as is for now, user can delete and re-log if major.
    );

    await SessionService().updateQso(updatedQso);
    if (mounted) Navigator.pop(context);
  }
  
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context, 
      initialDate: _timestamp, 
      firstDate: DateTime(2000), 
      lastDate: DateTime.now()
    );
    if (date == null) return;
    
    if (mounted) {
      final time = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.fromDateTime(_timestamp)
      );
      if (time == null) return;
      
      setState(() {
        _timestamp = DateTime(
          date.year, date.month, date.day, 
          time.hour, time.minute, _timestamp.second
        );
      });
    }
  }

  Future<void> _delete() async {
    if (widget.qso.id == null) return;
    
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete QSO?"),
        content: Text("Delete contact with ${widget.qso.callsign}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete")
          )
        ],
      )
    );

    if (confirm == true) {
      await SessionService().deleteQso(widget.qso.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit QSO"),
        backgroundColor: AppTheme.primaryColor, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
          IconButton(icon: const Icon(Icons.save), onPressed: _save)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _callsignCtrl,
              decoration: const InputDecoration(labelText: "Callsign", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBand,
                    decoration: const InputDecoration(labelText: "Band", border: OutlineInputBorder()),
                    items: _bands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _selectedBand = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMode,
                    decoration: const InputDecoration(labelText: "Mode", border: OutlineInputBorder()),
                    items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _selectedMode = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _freqCtrl,
              decoration: const InputDecoration(labelText: "Frequency (MHz)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: "Date & Time", border: OutlineInputBorder()),
                child: Text("${_timestamp.toLocal()}"),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Signal Report (Sent / Rcvd)", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: Column(
                  children: [
                    const Text("Sent"),
                    Slider(value: _rstSentR, min: 1, max: 5, divisions: 4, label: "R: ${_rstSentR.toInt()}", onChanged: (v) => setState(() => _rstSentR = v)),
                    Slider(value: _rstSentS, min: 1, max: 9, divisions: 8, label: "S: ${_rstSentS.toInt()}", onChanged: (v) => setState(() => _rstSentS = v)),
                    if (_selectedMode == 'CW') Slider(value: _rstSentT, min: 1, max: 9, divisions: 8, label: "T: ${_rstSentT.toInt()}", onChanged: (v) => setState(() => _rstSentT = v)),
                  ],
                )),
                const VerticalDivider(),
                Expanded(child: Column(
                  children: [
                    const Text("Rcvd"),
                    Slider(value: _rstRcvdR, min: 1, max: 5, divisions: 4, label: "R: ${_rstRcvdR.toInt()}", onChanged: (v) => setState(() => _rstRcvdR = v)),
                    Slider(value: _rstRcvdS, min: 1, max: 9, divisions: 8, label: "S: ${_rstRcvdS.toInt()}", onChanged: (v) => setState(() => _rstRcvdS = v)),
                    if (_selectedMode == 'CW') Slider(value: _rstRcvdT, min: 1, max: 9, divisions: 8, label: "T: ${_rstRcvdT.toInt()}", onChanged: (v) => setState(() => _rstRcvdT = v)),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gridCtrl,
              decoration: const InputDecoration(labelText: "Grid", border: OutlineInputBorder()),
            ),
             const SizedBox(height: 10),
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(labelText: "Comment", border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }
}

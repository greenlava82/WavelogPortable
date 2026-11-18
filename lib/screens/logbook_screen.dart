import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/log_entry.dart';
import '../services/logbook_service.dart';
import '../services/session_service.dart';

/// Read-only list of the most recent contacts.
class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  static const List<int> _limits = [10, 25, 50, 100];

  int _limit = 25;
  bool _loading = true;
  LogbookResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await LogbookService.recent(
      _limit,
      offline: SessionService().isOfflineMode,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text('Last $_limit Contacts'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<int>(
            tooltip: 'How many',
            icon: const Icon(Icons.format_list_numbered),
            initialValue: _limit,
            onSelected: (n) {
              _limit = n;
              _load();
            },
            itemBuilder: (_) => _limits
                .map((n) => PopupMenuItem(value: n, child: Text('Show last $n')))
                .toList(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading && result == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (result != null) _SourceBanner(result: result),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: (result == null || result.entries.isEmpty)
                        ? ListView(children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('No contacts yet')),
                            ),
                          ])
                        : ListView.separated(
                            itemCount: result.entries.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) => _LogRow(entry: result.entries[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SourceBanner extends StatelessWidget {
  final LogbookResult result;
  const _SourceBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final fromWavelog = result.source == LogbookSource.wavelog;
    return Container(
      width: double.infinity,
      color: fromWavelog ? Colors.green[50] : Colors.orange[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(fromWavelog ? Icons.cloud_done : Icons.phone_android,
              size: 16, color: fromWavelog ? Colors.green[800] : Colors.orange[900]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fromWavelog ? 'From your Wavelog logbook' : (result.note ?? 'Contacts logged on this phone'),
              style: TextStyle(fontSize: 12, color: fromWavelog ? Colors.green[900] : Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        entry.callsign,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
      subtitle: Text(entry.timeLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tag(entry.band, Colors.blueGrey),
          const SizedBox(width: 6),
          _Tag(entry.mode, AppTheme.primaryColor),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

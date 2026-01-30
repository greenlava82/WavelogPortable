import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../config/theme.dart';
import 'session_log_screen.dart';

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  late Future<List<Session>> _sessionsFuture;
  final Map<int, int> _qsoCounts = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _sessionsFuture = _loadSessions();
    });
  }

  Future<List<Session>> _loadSessions() async {
    final sessions = await SessionService().getSessions();
    for (var s in sessions) {
      if (s.id != null) {
        _qsoCounts[s.id!] = await SessionService().getQsoCount(s.id!);
      }
    }
    return sessions;
  }

  String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} "
           "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }

  Future<void> _deleteSession(Session session) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Session?"),
        content: Text("Delete '${session.name}' and all its logs? This cannot be undone."),
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
      await SessionService().deleteSession(session);
      _refresh();
    }
  }

  Future<void> _resumeSession(Session session) async {
    // If it's already the current session, do nothing or show info
    if (SessionService().currentSession?.id == session.id) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resume Session?"),
        content: Text("Set '${session.name}' as the active session? This will close any currently active session."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Resume")
          )
        ],
      )
    );

    if (confirm == true) {
      await SessionService().resumeSession(session);
      if (mounted) {
        Navigator.pop(context); // Go back to input screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch session service to update if current session changes (e.g. deleted)
    return ListenableBuilder(
      listenable: SessionService(),
      builder: (context, child) {
        final currentSessionId = SessionService().currentSession?.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Manage Sessions"),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: FutureBuilder<List<Session>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No sessions found."));
              }
              
              final sessions = snapshot.data!;

              return ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isActive = session.id == currentSessionId;
                  final count = _qsoCounts[session.id] ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? Colors.green : Colors.grey,
                      child: Icon(isActive ? Icons.play_arrow : Icons.history, color: Colors.white),
                    ),
                    title: Text(session.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text("${_formatDate(session.startTime)} $count QSOs"),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'resume') _resumeSession(session);
                        if (value == 'delete') _deleteSession(session);
                      },
                      itemBuilder: (context) => [
                        if (!isActive)
                          const PopupMenuItem(value: 'resume', child: Text("Resume / Activate")),
                        const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SessionLogScreen(session: session)),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      }
    );
  }
}

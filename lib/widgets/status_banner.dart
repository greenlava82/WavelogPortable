import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  final bool isOffline;
  final String? sessionName;

  const StatusBanner({
    super.key,
    required this.isOffline,
    this.sessionName,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline && sessionName == null) return const SizedBox.shrink();

    return Container(
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
    );
  }
}

// FILE: lib/widgets/activity_selection_dialog.dart
// ==============================
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/activity_ref.dart';
import '../config/theme.dart';

class ActivitySelectionDialog extends StatefulWidget {
  final List<ActivityRef> selected;

  const ActivitySelectionDialog({super.key, required this.selected});

  @override
  State<ActivitySelectionDialog> createState() => _ActivitySelectionDialogState();
}

class _ActivitySelectionDialogState extends State<ActivitySelectionDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  late List<ActivityRef> _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = List.from(widget.selected);
  }

  Future<void> _doSearch(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    var pota = await DatabaseService().searchPota(query);
    var sota = await DatabaseService().searchSota(query);

    if (mounted) {
      setState(() {
        _searchResults = [...pota, ...sota];
      });
    }
  }

  void _toggleSelection(Map<String, String> item) {
    setState(() {
      final String ref = item['ref']!;
      final existingIndex = _currentSelection.indexWhere((element) => element.reference == ref);
      
      if (existingIndex >= 0) {
        _currentSelection.removeAt(existingIndex);
      } else {
        _currentSelection.add(ActivityRef(
          type: item['type']!,
          reference: ref,
          name: item['name']!,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate a height that is slightly shorter than default
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // INSET PADDING: This controls how close the dialog is to the screen edge.
      // Increasing vertical padding effectively shrinks the max height of the dialog.
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 50.0), 
      child: Container(
        // Set a max height explicitly if you want it strictly shorter
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.6, // Limits dialog to 60% of screen height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.terrain, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Select Activity", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Chips
            if (_currentSelection.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8.0,
                  children: _currentSelection.map((act) {
                    return Chip(
                      label: Text("${act.type}: ${act.reference}"),
                      backgroundColor: act.type == 'POTA' ? Colors.green[100] : Colors.blue[100],
                      onDeleted: () {
                        setState(() {
                          _currentSelection.remove(act);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),

            // Search Field
            Padding(
              padding: const EdgeInsets.all(12.0), // Reduced padding slightly
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: "Search (e.g. K-1234 or Blue Hills)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  isDense: true, // Compacts the text field
                ),
                onChanged: _doSearch,
              ),
            ),

            // Results List
            Expanded(
              child: _searchResults.isEmpty 
                ? const Center(child: Text("Type 3+ characters to search"))
                : ListView.separated(
                    padding: EdgeInsets.zero, // Remove internal list padding
                    itemCount: _searchResults.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      final isSelected = _currentSelection.any((x) => x.reference == item['ref']);
                      
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact, // Compact list items
                        leading: Icon(
                          item['type'] == 'POTA' ? Icons.park : Icons.landscape,
                          color: item['type'] == 'POTA' ? Colors.green : Colors.blue
                        ),
                        title: Text("${item['ref']} - ${item['name']}"),
                        subtitle: Text(item['loc'] ?? ""),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
                        onTap: () => _toggleSelection(item),
                      );
                    },
                  ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.all(12.0), // Reduced padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _currentSelection),
                    child: const Text("Save Selection"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
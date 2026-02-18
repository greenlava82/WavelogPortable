import 'package:flutter/material.dart';

class KeypadWidget extends StatelessWidget {
  final Function(String) onKeyTap;

  const KeypadWidget({super.key, required this.onKeyTap});

  static const List<List<String>> _keyboardRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['DEL', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '/', 'ENT']
  ];

  Widget _buildButtonContent(String key) {
    if (key == 'DEL') return const Icon(Icons.backspace_outlined, size: 24);
    if (key == 'ENT') return const Icon(Icons.arrow_forward, size: 28);
    return Text(key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(4),
      child: Column(
        children: _keyboardRows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: row.map((key) => Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => onKeyTap(key),
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
    );
  }
}

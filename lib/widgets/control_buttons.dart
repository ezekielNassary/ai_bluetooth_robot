import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final Function(String) onCommand;

  const ControlButtons({required this.onCommand});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildButton("↑", () => onCommand("forward")),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildButton("←", () => onCommand("left")),
          _buildButton("⏺", () => onCommand("stop")),
          _buildButton("→", () => onCommand("right")),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildButton("↓", () => onCommand("backward")),
        ]),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.blue,
        ),
        child: Text(label, style: TextStyle(fontSize: 20, color: Colors.white)),
      ),
    );
  }
}

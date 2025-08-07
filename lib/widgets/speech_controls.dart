import 'package:flutter/material.dart';

class SpeechControls extends StatelessWidget {
  final bool isListening;
  final bool isAvailable;
  final String langCode;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;
  final String transcription;

  const SpeechControls({
    required this.isListening,
    required this.isAvailable,
    required this.langCode,
    this.onStart,
    this.onStop,
    this.onCancel,
    required this.transcription,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.green),
      child: Column(
        children: [
          _buildButton(
            label: isListening ? 'Listening...' : 'Listen ($langCode)',
            onPressed: isAvailable && !isListening ? onStart : null,
          ),
          _buildButton(
              label: 'Cancel', onPressed: isListening ? onCancel : null),
          _buildButton(label: 'Stop', onPressed: isListening ? onStop : null),
          Text(transcription),
        ],
      ),
    );
  }

  Widget _buildButton({required String label, VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: Colors.green)),
      ),
    );
  }
}

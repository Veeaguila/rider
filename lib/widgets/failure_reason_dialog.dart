import 'package:flutter/material.dart';

class FailureReasonDialog extends StatefulWidget {
  const FailureReasonDialog({super.key});

  @override
  State<FailureReasonDialog> createState() => _FailureReasonDialogState();
}

class _FailureReasonDialogState extends State<FailureReasonDialog> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get isValid => controller.text.trim().length >= 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Mark Delivery as Failed',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for the failed delivery:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Address not found, Recipient unavailable...',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (controller.text.isNotEmpty && !isValid)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Reason must be at least 5 characters.',
                  style: TextStyle(color: Color(0xffdc3545), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isValid ? () => Navigator.of(context).pop(controller.text.trim()) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xffdc3545),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: const Text('Confirm Failed'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

Future<void> showCloudAccountCreatedDialog(
  BuildContext context, {
  required String publicUserId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cloud account ready'),
      content: Text('Your TrailLink ID: $publicUserId'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

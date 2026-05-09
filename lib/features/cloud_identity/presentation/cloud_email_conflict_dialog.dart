import 'package:flutter/material.dart';

Future<bool?> showCloudEmailConflictDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Email already linked'),
      content: const Text(
        'This email is already connected to another TrailLink cloud profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continue Offline'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Try another email'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

enum P2PSessionSwitchAction {
  disconnectAndSwitch,
  createInactive,
  cancel,
}

Future<P2PSessionSwitchAction> showP2PSessionSwitchDialog({
  required BuildContext context,
  required String currentTripName,
  required String newTripName,
  bool allowCreateInactive = true,
}) async {
  final result = await showDialog<P2PSessionSwitchAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Disconnect current trip?'),
      content: Text(
        'You are currently connected to $currentTripName. To use $newTripName, TrailLink must disconnect from the current trip first.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, P2PSessionSwitchAction.cancel),
          child: const Text('Cancel'),
        ),
        if (allowCreateInactive)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, P2PSessionSwitchAction.createInactive),
            child: const Text('Create as Inactive'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            P2PSessionSwitchAction.disconnectAndSwitch,
          ),
          child: const Text('Disconnect & Switch'),
        ),
      ],
    ),
  );
  return result ?? P2PSessionSwitchAction.cancel;
}

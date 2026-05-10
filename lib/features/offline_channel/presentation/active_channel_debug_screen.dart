import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_channel_controller.dart';

class ActiveChannelDebugScreen extends ConsumerWidget {
  const ActiveChannelDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(activeOfflineChannelResolverProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Active Channel Diagnostics')),
      body: FutureBuilder<Map<String, Object?>>(
        future: resolver.diagnostics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!.entries.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              Text(
                'Resolver result - trip offline_channel_id',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...rows.map(
                (row) => Column(
                  children: [
                    ListTile(
                      title: Text(row.key),
                      subtitle: Text(row.value?.toString() ?? 'null'),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

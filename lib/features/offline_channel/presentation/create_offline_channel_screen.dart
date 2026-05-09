import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';
import 'offline_channel_controller.dart';

class CreateOfflineChannelScreen extends ConsumerStatefulWidget {
  const CreateOfflineChannelScreen({super.key});

  @override
  ConsumerState<CreateOfflineChannelScreen> createState() =>
      _CreateOfflineChannelScreenState();
}

class _CreateOfflineChannelScreenState
    extends ConsumerState<CreateOfflineChannelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    final channel =
        await ref.read(offlineChannelControllerProvider.notifier).createChannel(
              user: user,
              channelName: _nameController.text,
              description: _descriptionController.text,
              customCode: _codeController.text,
            );
    if (channel != null && mounted) {
      ref.invalidate(offlineChannelListProvider);
      ref.invalidate(activeOfflineChannelProvider);
      context.go('/offline-channel/${channel.channelId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineChannelControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Offline Channel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local channel setup',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Channel name',
                          prefixIcon: Icon(Icons.hub_rounded),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 3 || text.length > 50) {
                            return 'Channel name must be 3-50 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Description optional',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Custom channel code optional',
                          hintText: 'TL-OFF-8K2P',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          if (!RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(text)) {
                            return 'Use letters, numbers, and hyphens only';
                          }
                          return null;
                        },
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: state.isLoading ? null : _submit,
                        icon: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_rounded),
                        label: const Text('Create Channel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

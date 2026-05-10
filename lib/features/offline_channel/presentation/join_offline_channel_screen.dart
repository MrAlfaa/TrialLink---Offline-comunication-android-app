import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../../trip/data/trip_session_service.dart';
import 'offline_channel_controller.dart';

class JoinOfflineChannelScreen extends ConsumerStatefulWidget {
  const JoinOfflineChannelScreen({super.key});

  @override
  ConsumerState<JoinOfflineChannelScreen> createState() =>
      _JoinOfflineChannelScreenState();
}

class _JoinOfflineChannelScreenState
    extends ConsumerState<JoinOfflineChannelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    final channel =
        await ref.read(offlineChannelControllerProvider.notifier).joinChannel(
              user: user,
              channelCode: _codeController.text,
            );
    if (channel != null && mounted) {
      ref.invalidate(offlineChannelListProvider);
      ref.invalidate(activeOfflineChannelProvider);
      ref.invalidate(activeUsableOfflineChannelProvider);
      ref.invalidate(activeTripChannelProvider);
      ref.invalidate(activeTripContextProvider);
      ref.invalidate(activeTripProvider);
      context.go('/offline-channel/${channel.channelId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineChannelControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Offline Channel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Channel membership will be verified with nearby devices in the peer discovery phase.',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Channel Code',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Channel Code',
                          hintText: 'HIKER-25',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (!RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(text)) {
                            return 'Invalid channel code. Use letters, numbers, and hyphens only.';
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
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Join Channel'),
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

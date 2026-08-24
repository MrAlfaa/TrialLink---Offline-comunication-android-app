import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../trip/data/trip_session_service.dart';
import '../../trip_context/data/cloud_prepared_trip_repository.dart';
import 'group_controller.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final metadata = await ref
        .read(cloudPreparedTripRepositoryProvider)
        .joinCloudPreparedTrip(
          _codeController.text.trim(),
        );

    ref.invalidate(myGroupsProvider);
    ref.invalidate(modeScopedActiveTripProvider);
    await ref
        .read(modeControllerProvider.notifier)
        .setManualCommunicationMode(ManualCommunicationMode.online);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nearby-phone support ready')),
    );
    context.go('/groups/${metadata.group.id}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupMutationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Online Trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Join with trip code',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the trip owner for a TrailLink code such as TL-ONLI-8F3K2.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Trip code',
                          prefixIcon: Icon(Icons.confirmation_number_rounded),
                        ),
                        validator: (value) {
                          final code = value?.trim().toUpperCase() ?? '';
                          if (!RegExp(r'^TL-(?:[A-Z0-9]{5}|ONLI-[A-Z0-9]{5})$')
                              .hasMatch(code)) {
                            return 'Enter a valid code like TL-ONLI-8F3K2';
                          }
                          return null;
                        },
                      ),
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Join Trip',
                        icon: Icons.login_rounded,
                        isLoading: state.isLoading,
                        onPressed: _submit,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
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

    final group =
        await ref.read(groupMutationControllerProvider.notifier).joinGroup(
              groupCode: _codeController.text.trim(),
            );

    if (group != null) {
      ref.invalidate(myGroupsProvider);
      if (mounted) context.go('/groups/${group.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupMutationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Join with group code',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the group owner for a TrailLink code such as TL-8F3K2.',
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
                          labelText: 'Group code',
                          prefixIcon: Icon(Icons.confirmation_number_rounded),
                        ),
                        validator: (value) {
                          final code = value?.trim().toUpperCase() ?? '';
                          if (!RegExp(r'^TL-[A-Z0-9]{5}$').hasMatch(code)) {
                            return 'Enter a valid code like TL-8F3K2';
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
                        label: 'Join Group',
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

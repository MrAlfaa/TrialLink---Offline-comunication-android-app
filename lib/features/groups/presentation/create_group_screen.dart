import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import 'group_controller.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final group =
        await ref.read(groupMutationControllerProvider.notifier).createGroup(
              groupName: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
            );

    if (group != null) {
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group code: ${group.groupCode}')),
      );
      context.go('/groups/${group.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupMutationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Start a trip group',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a private code for your hiking or camping team.',
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Group name',
                          prefixIcon: Icon(Icons.groups_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Group name is required'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
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
                        label: 'Create Group',
                        icon: Icons.add_rounded,
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

class GroupCodeCopyButton extends StatelessWidget {
  const GroupCodeCopyButton({
    required this.groupCode,
    super.key,
  });

  final String groupCode;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy group code',
      onPressed: () {
        Clipboard.setData(ClipboardData(text: groupCode));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group code copied')),
        );
      },
      icon: const Icon(Icons.copy_rounded),
    );
  }
}

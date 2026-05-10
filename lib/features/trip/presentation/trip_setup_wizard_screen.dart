import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/auth_access_state.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/settings/settings_service.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../groups/presentation/group_controller.dart';
import '../../nearby/data/nearby_permission_service.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../../ptt/data/ptt_audio_service.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../data/trip_session_repository.dart';
import '../data/trip_session_service.dart';

enum TripWizardType { cloudBackup, offlineOnly, joinExisting }

class TripSetupWizardScreen extends ConsumerStatefulWidget {
  const TripSetupWizardScreen({this.initialIntent, super.key});

  final String? initialIntent;

  @override
  ConsumerState<TripSetupWizardScreen> createState() =>
      _TripSetupWizardScreenState();
}

class _TripSetupWizardScreenState extends ConsumerState<TripSetupWizardScreen> {
  static const _steps = [
    'Choose Trip Type',
    'Create or Join',
    'Communication Preparation',
    'Readiness Check',
    'Start Trip',
  ];

  final _formKey = GlobalKey<FormState>();
  final _tripNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customCodeController = TextEditingController();
  final _joinCodeController = TextEditingController();

  late TripWizardType _type;
  int _step = 0;
  bool _loadingReadiness = true;
  bool _submitting = false;
  List<_ReadinessItem> _readiness = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final access = ref.read(authAccessControllerProvider).accessState;
    _type = widget.initialIntent == 'join'
        ? TripWizardType.joinExisting
        : access.canUseBackendFeatures
            ? TripWizardType.cloudBackup
            : TripWizardType.offlineOnly;
    if (widget.initialIntent == 'join') _step = 1;
    _loadReadiness();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _descriptionController.dispose();
    _customCodeController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadReadiness() async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    final settings = ref.read(settingsServiceProvider);
    final nearbyPermission = await NearbyPermissionService().check();
    final locationPermission = await Geolocator.checkPermission();
    final micReady = await PttAudioService().hasPermission();
    final sosEnabled = await settings.getBool('enable_offline_sos', true);
    final voiceEnabled = await settings.getBool('voice_note_ptt_enabled', true);
    final cloudReady = ref
        .read(authAccessControllerProvider)
        .accessState
        .canUseBackendFeatures;
    if (!mounted) return;
    setState(() {
      _loadingReadiness = false;
      _readiness = [
        _ReadinessItem(
          label: 'Local identity ready',
          state: identity == null
              ? _ReadinessState.missing
              : _ReadinessState.ready,
          actionLabel: identity == null ? 'Open setup' : null,
          onFix: identity == null ? () => context.go('/setup/identity') : null,
        ),
        const _ReadinessItem(
          label: 'Local storage ready',
          state: _ReadinessState.ready,
        ),
        _ReadinessItem(
          label: 'Cloud group ready / not required',
          state: _type == TripWizardType.offlineOnly
              ? _ReadinessState.optional
              : cloudReady
                  ? _ReadinessState.ready
                  : _ReadinessState.optional,
        ),
        const _ReadinessItem(
          label: 'Offline channel ready',
          state: _ReadinessState.ready,
        ),
        _ReadinessItem(
          label: 'Nearby permission',
          state: _nearbyReadinessState(nearbyPermission),
          actionLabel: nearbyPermission.granted ? null : 'Grant Permission',
          onFix: nearbyPermission.granted ? null : _grantNearbyPermission,
        ),
        _ReadinessItem(
          label: 'Location permission',
          state: locationPermission == LocationPermission.always ||
                  locationPermission == LocationPermission.whileInUse
              ? _ReadinessState.ready
              : _ReadinessState.optional,
          actionLabel: 'Grant Location',
          onFix: _requestLocationPermission,
        ),
        _ReadinessItem(
          label: 'Microphone permission',
          state: micReady ? _ReadinessState.ready : _ReadinessState.optional,
        ),
        _ReadinessItem(
          label: 'SOS enabled',
          state: sosEnabled ? _ReadinessState.ready : _ReadinessState.missing,
          actionLabel: 'Open Safety',
          onFix: sosEnabled ? null : () => context.go('/settings/safety'),
        ),
        _ReadinessItem(
          label: 'Voice-note PTT enabled',
          state:
              voiceEnabled ? _ReadinessState.ready : _ReadinessState.optional,
          actionLabel: 'Open Voice',
          onFix: voiceEnabled ? null : () => context.go('/settings/voice'),
        ),
      ];
    });
  }

  Future<void> _grantNearbyPermission() async {
    await NearbyPermissionService().checkAndRequest();
    await _loadReadiness();
  }

  Future<void> _requestLocationPermission() async {
    await Geolocator.requestPermission();
    await _loadReadiness();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 112),
          children: [
            _StepHeader(step: _step, steps: _steps),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey('trip-wizard-step-$_step-${_type.name}'),
                child: _bodyForStep(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _errorMessage!),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => setState(() => _step -= 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _next,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_step == 4
                            ? Icons.flag_rounded
                            : Icons.chevron_right_rounded),
                    label: Text(
                      _submitting
                          ? 'Starting...'
                          : _step == 4
                              ? 'Start Trip'
                              : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyForStep() {
    return switch (_step) {
      0 => _ChooseTypeStep(
          selected: _type,
          onChanged: (value) => setState(() => _type = value),
        ),
      1 => _CreateJoinStep(
          key: const ValueKey('create-join'),
          type: _type,
          formKey: _formKey,
          tripNameController: _tripNameController,
          descriptionController: _descriptionController,
          customCodeController: _customCodeController,
          joinCodeController: _joinCodeController,
        ),
      2 => _PreparationStep(
          loading: _loadingReadiness,
          items: _readiness,
        ),
      3 => _ReadinessStep(
          type: _type,
          items: _readiness,
        ),
      _ => _StartTripStep(
          type: _type,
          tripName: _tripNameController.text,
          joinCode: _joinCodeController.text,
          offlineCode: _customCodeController.text,
          readiness: _readiness,
        ),
    };
  }

  Future<void> _next() async {
    setState(() => _errorMessage = null);
    if (_step == 1 && !_formKey.currentState!.validate()) return;
    if (_step < 4) {
      setState(() => _step += 1);
      if (_step == 2 || _step == 3) await _loadReadiness();
      return;
    }
    await _startTrip();
  }

  Future<void> _startTrip() async {
    setState(() => _submitting = true);
    try {
      final identity =
          await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
      if (identity == null) {
        throw StateError('Create your local profile before starting a trip.');
      }
      final repo = ref.read(tripSessionRepositoryProvider);
      final access = ref
          .read(authAccessControllerProvider)
          .accessState
          .canUseBackendFeatures;
      switch (_type) {
        case TripWizardType.cloudBackup:
          await repo.createCloudBackupTrip(
            tripName: _tripNameController.text,
            description: _descriptionController.text,
            identity: identity,
            groupRepository: access ? ref.read(groupRepositoryProvider) : null,
            customChannelCode: _blankToNull(_customCodeController.text),
          );
        case TripWizardType.offlineOnly:
          await repo.createOfflineOnlyTrip(
            tripName: _tripNameController.text,
            identity: identity,
            customChannelCode: _blankToNull(_customCodeController.text),
          );
        case TripWizardType.joinExisting:
          await ref
              .read(tripContextServiceProvider)
              .joinOfflineChannelAsActiveTrip(_joinCodeController.text);
      }
      final settings = ref.read(settingsServiceProvider);
      await settings.setBool('tutorial_seen', true);
      await settings.setBool('coach_marks_seen', true);
      await ref
          .read(authAccessControllerProvider.notifier)
          .refreshFromIdentity();
      ref.invalidate(activeTripContextProvider);
      ref.invalidate(activeOfflineChannelProvider);
      ref.invalidate(activeUsableOfflineChannelProvider);
      ref.invalidate(activeTripChannelProvider);
      ref.invalidate(activeTripProvider);
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.steps});

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(steps[step], style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'TrailLink works best when communication tools are connected to one trip.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mutedText,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color:
                        i <= step ? AppColors.deepForest : AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChooseTypeStep extends StatelessWidget {
  const _ChooseTypeStep({required this.selected, required this.onChanged});

  final TripWizardType selected;
  final ValueChanged<TripWizardType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('choose-type'),
      children: [
        _TripTypeCard(
          title: 'Cloud + Offline Backup',
          badge: 'Recommended',
          message:
              'Use cloud chat when online and offline channel when signal is lost.',
          icon: Icons.cloud_sync_rounded,
          selected: selected == TripWizardType.cloudBackup,
          onTap: () => onChanged(TripWizardType.cloudBackup),
        ),
        _TripTypeCard(
          title: 'Offline Only',
          message:
              'For remote areas without internet. Uses nearby phones and channel code.',
          icon: Icons.hub_rounded,
          selected: selected == TripWizardType.offlineOnly,
          onTap: () => onChanged(TripWizardType.offlineOnly),
        ),
        _TripTypeCard(
          title: 'Join Existing Trip',
          message: 'Join using a teammate’s trip or channel code.',
          icon: Icons.login_rounded,
          selected: selected == TripWizardType.joinExisting,
          onTap: () => onChanged(TripWizardType.joinExisting),
        ),
      ],
    );
  }
}

class _CreateJoinStep extends StatelessWidget {
  const _CreateJoinStep({
    super.key,
    required this.type,
    required this.formKey,
    required this.tripNameController,
    required this.descriptionController,
    required this.customCodeController,
    required this.joinCodeController,
  });

  final TripWizardType type;
  final GlobalKey<FormState> formKey;
  final TextEditingController tripNameController;
  final TextEditingController descriptionController;
  final TextEditingController customCodeController;
  final TextEditingController joinCodeController;

  @override
  Widget build(BuildContext context) {
    final joining = type == TripWizardType.joinExisting;
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                joining ? 'Join Existing Trip' : 'Create Trip',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (joining)
                TextFormField(
                  controller: joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Trip code / channel code',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: _validateCode,
                )
              else ...[
                TextFormField(
                  controller: tripNameController,
                  decoration: const InputDecoration(
                    labelText: 'Trip name',
                    prefixIcon: Icon(Icons.hiking_rounded),
                  ),
                  validator: _validateTripName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Optional description',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: customCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Optional offline channel code',
                    helperText: 'Example: TL-OFF-8K2P',
                    prefixIcon: Icon(Icons.hub_rounded),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    return _validateCode(value);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparationStep extends StatelessWidget {
  const _PreparationStep({required this.loading, required this.items});

  final bool loading;
  final List<_ReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return _ReadinessList(
      title: 'Communication Preparation',
      message: 'Fix missing items now, or continue with optional items later.',
      items: items,
    );
  }
}

class _ReadinessStep extends StatelessWidget {
  const _ReadinessStep({required this.type, required this.items});

  final TripWizardType type;
  final List<_ReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    return _ReadinessList(
      title: 'Readiness Check',
      message: type == TripWizardType.offlineOnly
          ? 'Offline readiness is enough to start this trip.'
          : 'Cloud can sync later. Offline backup keeps the trip usable now.',
      items: items,
    );
  }
}

class _StartTripStep extends StatelessWidget {
  const _StartTripStep({
    required this.type,
    required this.tripName,
    required this.joinCode,
    required this.offlineCode,
    required this.readiness,
  });

  final TripWizardType type;
  final String tripName;
  final String joinCode;
  final String offlineCode;
  final List<_ReadinessItem> readiness;

  @override
  Widget build(BuildContext context) {
    final name = type == TripWizardType.joinExisting
        ? 'Join ${joinCode.trim().toUpperCase()}'
        : tripName.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Trip', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryLine(
                label: 'Trip', value: name.isEmpty ? 'New Trip' : name),
            _SummaryLine(label: 'Mode', value: _typeLabel(type)),
            _SummaryLine(
              label: 'Offline channel',
              value: offlineCode.trim().isEmpty
                  ? 'Will be generated'
                  : offlineCode.trim().toUpperCase(),
            ),
            _SummaryLine(
              label: 'SOS',
              value: _stateText(readiness, 'SOS enabled'),
            ),
            _SummaryLine(
              label: 'Location',
              value: _stateText(readiness, 'Location permission'),
            ),
            _SummaryLine(
              label: 'PTT',
              value: _stateText(readiness, 'Voice-note PTT enabled'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessList extends StatelessWidget {
  const _ReadinessList({
    required this.title,
    required this.message,
    required this.items,
  });

  final String title;
  final String message;
  final List<_ReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message),
            const SizedBox(height: 14),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    CompactStatusChip(
                      label: item.state.label,
                      color: item.state.color,
                      dense: true,
                    ),
                    if (item.onFix != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: item.onFix,
                        child: Text(item.actionLabel ?? 'Fix'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TripTypeCard extends StatelessWidget {
  const _TripTypeCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.deepForest),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (badge != null)
                            const CompactStatusChip(
                              label: 'Recommended',
                              color: AppColors.success,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(message),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.deepForest : AppColors.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}

class _ReadinessItem {
  const _ReadinessItem({
    required this.label,
    required this.state,
    this.actionLabel,
    this.onFix,
  });

  final String label;
  final _ReadinessState state;
  final String? actionLabel;
  final VoidCallback? onFix;
}

enum _ReadinessState {
  ready('Ready', AppColors.success),
  optional('Optional', AppColors.warning),
  missing('Missing', AppColors.danger),
  blocked('Blocked', AppColors.danger);

  const _ReadinessState(this.label, this.color);
  final String label;
  final Color color;
}

_ReadinessState _nearbyReadinessState(NearbyPermissionState permission) {
  return switch (permission.readiness) {
    NearbyPermissionReadiness.ready => _ReadinessState.ready,
    NearbyPermissionReadiness.optional => _ReadinessState.optional,
    NearbyPermissionReadiness.blocked => _ReadinessState.blocked,
    NearbyPermissionReadiness.missing => _ReadinessState.missing,
  };
}

String? _validateTripName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length < 3 || trimmed.length > 60) {
    return 'Trip name must be 3-60 characters.';
  }
  return null;
}

String? _validateCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(code)) {
    return 'Use 4-20 uppercase letters, numbers, or hyphens.';
  }
  return null;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _typeLabel(TripWizardType type) {
  return switch (type) {
    TripWizardType.cloudBackup => 'Cloud + Offline Backup',
    TripWizardType.offlineOnly => 'Offline Only',
    TripWizardType.joinExisting => 'Join Existing Trip',
  };
}

String _stateText(List<_ReadinessItem> items, String label) {
  final matches = items.where((item) => item.label == label);
  return matches.isEmpty ? 'Optional' : matches.first.state.label;
}

String _friendlyError(Object error) {
  if (error is StateError) return error.message;
  return 'Trip setup could not be completed. Please check your details and try again.';
}

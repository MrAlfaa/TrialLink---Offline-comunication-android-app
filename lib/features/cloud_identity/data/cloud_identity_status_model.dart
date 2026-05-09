import '../../auth/data/models/user_model.dart';

class CloudBootstrapResult {
  const CloudBootstrapResult({
    required this.success,
    this.user,
    this.publicUserId,
    this.message,
    this.errorMessage,
    this.emailConflict = false,
    this.skipped = false,
  });

  final bool success;
  final UserModel? user;
  final String? publicUserId;
  final String? message;
  final String? errorMessage;
  final bool emailConflict;
  final bool skipped;

  factory CloudBootstrapResult.ready({
    required String? publicUserId,
    UserModel? user,
  }) {
    return CloudBootstrapResult(
      success: true,
      user: user,
      publicUserId: publicUserId,
      message: 'Cloud account ready.',
      skipped: true,
    );
  }

  factory CloudBootstrapResult.failure(
    String message, {
    bool emailConflict = false,
  }) {
    return CloudBootstrapResult(
      success: false,
      errorMessage: message,
      emailConflict: emailConflict,
    );
  }
}

class CloudSyncState {
  const CloudSyncState({
    this.isCreatingAccount = false,
    this.isGeneratingUid = false,
    this.isSyncingData = false,
    this.progressPercent = 0,
    this.currentStep = '',
    this.publicUserId,
    this.errorMessage,
    this.successMessage,
    this.emailConflict = false,
  });

  final bool isCreatingAccount;
  final bool isGeneratingUid;
  final bool isSyncingData;
  final int progressPercent;
  final String currentStep;
  final String? publicUserId;
  final String? errorMessage;
  final String? successMessage;
  final bool emailConflict;

  bool get isActive =>
      isCreatingAccount ||
      isGeneratingUid ||
      isSyncingData ||
      errorMessage != null ||
      successMessage != null;

  bool get isBlocking =>
      isCreatingAccount || isGeneratingUid || errorMessage != null;

  CloudSyncState copyWith({
    bool? isCreatingAccount,
    bool? isGeneratingUid,
    bool? isSyncingData,
    int? progressPercent,
    String? currentStep,
    String? publicUserId,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    bool? emailConflict,
  }) {
    return CloudSyncState(
      isCreatingAccount: isCreatingAccount ?? this.isCreatingAccount,
      isGeneratingUid: isGeneratingUid ?? this.isGeneratingUid,
      isSyncingData: isSyncingData ?? this.isSyncingData,
      progressPercent: progressPercent ?? this.progressPercent,
      currentStep: currentStep ?? this.currentStep,
      publicUserId: publicUserId ?? this.publicUserId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
      emailConflict: emailConflict ?? this.emailConflict,
    );
  }

  factory CloudSyncState.creatingAccount({
    int progressPercent = 25,
    String currentStep = 'Creating your TrailLink cloud account...',
  }) {
    return CloudSyncState(
      isCreatingAccount: true,
      isGeneratingUid: true,
      progressPercent: progressPercent,
      currentStep: currentStep,
    );
  }

  factory CloudSyncState.syncing({
    int progressPercent = 75,
    String currentStep = 'Syncing offline data...',
    String? publicUserId,
  }) {
    return CloudSyncState(
      isSyncingData: true,
      progressPercent: progressPercent,
      currentStep: currentStep,
      publicUserId: publicUserId,
    );
  }

  factory CloudSyncState.success(
    String publicUserId, {
    String successMessage = 'Cloud account ready',
  }) {
    return CloudSyncState(
      progressPercent: 100,
      currentStep: successMessage,
      publicUserId: publicUserId,
      successMessage: successMessage,
    );
  }

  factory CloudSyncState.error(
    String message, {
    bool emailConflict = false,
  }) {
    return CloudSyncState(
      errorMessage: message,
      currentStep: message,
      emailConflict: emailConflict,
    );
  }
}

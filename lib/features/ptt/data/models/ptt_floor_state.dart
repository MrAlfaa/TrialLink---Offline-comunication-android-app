class PttFloorState {
  const PttFloorState({
    required this.contextType,
    required this.contextId,
    this.currentSpeakerId,
    this.currentSpeakerName,
    this.lockedAt,
    this.currentUserId,
  });

  final String contextType;
  final String contextId;
  final String? currentSpeakerId;
  final String? currentSpeakerName;
  final DateTime? lockedAt;
  final String? currentUserId;

  bool get hasSpeaker => currentSpeakerId != null;
  bool get isCurrentUserSpeaker =>
      currentUserId != null && currentSpeakerId == currentUserId;
  bool get canCurrentUserSpeak =>
      currentSpeakerId == null || isCurrentUserSpeaker;

  PttFloorState copyWith({
    String? currentSpeakerId,
    String? currentSpeakerName,
    DateTime? lockedAt,
    String? currentUserId,
    bool clearSpeaker = false,
  }) {
    return PttFloorState(
      contextType: contextType,
      contextId: contextId,
      currentSpeakerId:
          clearSpeaker ? null : currentSpeakerId ?? this.currentSpeakerId,
      currentSpeakerName:
          clearSpeaker ? null : currentSpeakerName ?? this.currentSpeakerName,
      lockedAt: clearSpeaker ? null : lockedAt ?? this.lockedAt,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

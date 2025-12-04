class MeetingDetail {
  const MeetingDetail({
    required this.id,
    required this.teamId,
    required this.title,
    required this.status,
    this.date,
    this.startTime,
    this.endTime,
    this.duration,
    this.summary,
    this.recordingUrl,
    this.transcripts = const [],
    this.actionItems = const [],
    this.speakerStats = const [],
  });

  final String id;
  final String teamId;
  final String title;
  final String status;
  final String? date;
  final String? startTime;
  final String? endTime;
  final int? duration;
  final String? summary;
  final String? recordingUrl;
  final List<TranscriptSegment> transcripts;
  final List<MeetingActionItem> actionItems;
  final List<SpeakerStat> speakerStats;

  MeetingDetail copyWith({
    String? summary,
    List<TranscriptSegment>? transcripts,
    List<MeetingActionItem>? actionItems,
    List<SpeakerStat>? speakerStats,
    String? status,
  }) {
    return MeetingDetail(
      id: id,
      teamId: teamId,
      title: title,
      status: status ?? this.status,
      date: date,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      summary: summary ?? this.summary,
      recordingUrl: recordingUrl,
      transcripts: transcripts ?? this.transcripts,
      actionItems: actionItems ?? this.actionItems,
      speakerStats: speakerStats ?? this.speakerStats,
    );
  }

  factory MeetingDetail.fromJson(Map<String, dynamic> json) {
    final meetingJson = json['meeting'] as Map<String, dynamic>? ?? json;
    return MeetingDetail(
      id: meetingJson['id'] as String,
      teamId: meetingJson['teamId'] as String,
      title: meetingJson['title'] as String? ?? '회의',
      status: meetingJson['status'] as String? ?? 'scheduled',
      date: meetingJson['date'] as String?,
      startTime: meetingJson['startTime'] as String?,
      endTime: meetingJson['endTime'] as String?,
      duration: meetingJson['duration'] as int?,
      summary: meetingJson['summary'] as String?,
      recordingUrl: meetingJson['recordingUrl'] as String?,
      transcripts: (meetingJson['transcripts'] as List<dynamic>? ?? [])
          .map((item) => TranscriptSegment.fromJson(item as Map<String, dynamic>))
          .toList(),
      actionItems: (meetingJson['actionItems'] as List<dynamic>? ?? [])
          .map((item) => MeetingActionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      speakerStats: (meetingJson['speakerStats'] as List<dynamic>? ?? [])
          .map((item) => SpeakerStat.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.speaker,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String speaker;
  final String text;
  final String timestamp;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'] as String? ?? '',
      speaker: json['speaker'] as String? ?? '발언자',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class MeetingActionItem {
  const MeetingActionItem({
    required this.id,
    required this.meetingId,
    required this.type,
    required this.assignee,
    required this.content,
    required this.status,
    this.assigneeUserId,
    this.dueDate,
  });

  final String id;
  final String meetingId;
  final String type;
  final String assignee;
  final String content;
  final String status;
  final String? assigneeUserId;
  final String? dueDate;

  factory MeetingActionItem.fromJson(Map<String, dynamic> json) {
    return MeetingActionItem(
      id: json['id']?.toString() ?? '',
      meetingId: json['meetingId']?.toString() ?? '',
      type: json['type'] as String? ?? 'task',
      assignee: json['assignee'] as String? ?? 'Unassigned',
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      assigneeUserId: json['assigneeUserId']?.toString(),
      dueDate: json['dueDate']?.toString(),
    );
  }
}

class SpeakerStat {
  const SpeakerStat({
    required this.id,
    required this.speaker,
    required this.speakTime,
    required this.speakCount,
    this.participationRate,
    this.avgLength,
  });

  final String id;
  final String speaker;
  final int speakTime;
  final int speakCount;
  final double? participationRate;
  final double? avgLength;

  factory SpeakerStat.fromJson(Map<String, dynamic> json) {
    return SpeakerStat(
      id: json['id']?.toString() ?? '',
      speaker: json['speaker'] as String? ?? '발언자',
      speakTime: json['speakTime'] as int? ?? 0,
      speakCount: json['speakCount'] as int? ?? 0,
      participationRate: (json['participationRate'] as num?)?.toDouble(),
      avgLength: (json['avgLength'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker': speaker,
      'speak_time': speakTime,
      'speak_count': speakCount,
      if (participationRate != null) 'participation_rate': participationRate,
      if (avgLength != null) 'avg_length': avgLength,
    };
  }
}

class MeetingAttendee {
  const MeetingAttendee({
    required this.id,
    this.userId,
    this.userName,
    this.guestName,
    this.joinedAt,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String? guestName;
  final String? joinedAt;

  String get displayName {
    final name = (userName ?? '').trim();
    if (name.isNotEmpty) return name;
    final guest = (guestName ?? '').trim();
    if (guest.isNotEmpty) return guest;
    return '참여자';
  }

  factory MeetingAttendee.fromJson(Map<String, dynamic> json) {
    return MeetingAttendee(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      userName: json['userName'] as String?,
      guestName: json['guestName'] as String?,
      joinedAt: json['joinedAt']?.toString(),
    );
  }
}

class RecordingUploadInfo {
  const RecordingUploadInfo({
    required this.uploadUrl,
    required this.recordingUrl,
    required this.expiresAt,
  });

  final String uploadUrl;
  final String recordingUrl;
  final DateTime expiresAt;

  factory RecordingUploadInfo.fromJson(Map<String, dynamic> json) {
    return RecordingUploadInfo(
      uploadUrl: json['uploadUrl'] as String? ?? '',
      recordingUrl: json['recordingUrl'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ActionItemInput {
  const ActionItemInput({
    required this.type,
    required this.assignee,
    required this.content,
    this.status = 'pending',
    this.dueDate,
    this.assigneeUserId,
  });

  final String type;
  final String assignee;
  final String content;
  final String status;
  final String? dueDate;
  final String? assigneeUserId;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'assignee': assignee,
      'content': content,
      'status': status,
      if (dueDate != null && dueDate!.isNotEmpty) 'dueDate': dueDate,
      if (assigneeUserId != null) 'assigneeUserId': assigneeUserId,
    };
  }
}

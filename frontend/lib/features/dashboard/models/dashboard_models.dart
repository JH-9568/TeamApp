class DashboardMember {
  const DashboardMember({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.avatar,
  });

  final String id;
  final String name;
  final String? email;
  final String? role;
  final String? avatar;

  factory DashboardMember.fromJson(Map<String, dynamic> json) {
    return DashboardMember(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}

class DashboardActionItem {
  const DashboardActionItem({
    required this.id,
    required this.meetingId,
    required this.type,
    required this.assignee,
    required this.content,
    required this.status,
    this.meetingTitle,
    this.meetingDate,
    this.dueDate,
    this.assigneeUserId,
  });

  final String id;
  final String meetingId;
  final String type;
  final String assignee;
  final String content;
  final String status;
  final String? meetingTitle;
  final DateTime? meetingDate;
  final DateTime? dueDate;
  final String? assigneeUserId;

  factory DashboardActionItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    final meetingIdValue = json['meetingId']?.toString() ?? '';
    final parsedMeetingTitle = json['meetingTitle'] as String?;
    return DashboardActionItem(
      id: json['id'] as String,
      meetingId: json['meetingId'] as String,
      type: json['type'] as String,
      assignee: json['assignee'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      meetingTitle: (parsedMeetingTitle == null || parsedMeetingTitle.isEmpty)
          ? (meetingIdValue.isNotEmpty ? '회의 $meetingIdValue' : null)
          : parsedMeetingTitle,
      meetingDate: parseDate(json['meetingDate'] as String?),
      dueDate: parseDate(json['dueDate'] as String?),
      assigneeUserId: json['assigneeUserId'] as String?,
    );
  }
}

class DashboardMeeting {
  const DashboardMeeting({
    required this.id,
    required this.title,
    required this.status,
    required this.actionItemsCount,
    this.date,
    this.startTime,
    this.endTime,
    this.duration,
  });

  final String id;
  final String title;
  final String status;
  final int actionItemsCount;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final int? duration;

  factory DashboardMeeting.fromJson(Map<String, dynamic> json) {
    final dateValue = json['date'] as String?;
    return DashboardMeeting(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      actionItemsCount: json['actionItemsCount'] as int? ?? 0,
      date: dateValue == null ? null : DateTime.tryParse(dateValue),
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      duration: json['duration'] as int?,
    );
  }

  DateTime? get startDateTime {
    if (date == null) return null;
    if (startTime == null) return date;
    final parts = startTime!.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date!.year, date!.month, date!.day, hour, minute);
  }
}

class DashboardTeam {
  const DashboardTeam({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<DashboardMember> members;

  factory DashboardTeam.fromJson(Map<String, dynamic> json) {
    final memberList = (json['members'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DashboardMember.fromJson)
        .toList();
    return DashboardTeam(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      members: memberList,
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.team,
    required this.actionItems,
    required this.meetings,
  });

  final DashboardTeam team;
  final List<DashboardActionItem> actionItems;
  final List<DashboardMeeting> meetings;
}

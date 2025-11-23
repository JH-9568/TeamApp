class Team {
  const Team({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.memberCount,
  });

  final String id;
  final String name;
  final String inviteCode;
  final int? memberCount;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      memberCount: json['memberCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'inviteCode': inviteCode,
      if (memberCount != null) 'memberCount': memberCount,
    };
  }
}

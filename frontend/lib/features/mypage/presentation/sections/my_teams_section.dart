import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:frontend/features/team/models/team.dart';

class MyTeamsSection extends StatelessWidget {
  const MyTeamsSection({
    super.key,
    required this.teams,
    required this.onCreateTeam,
    required this.onJoinTeam,
    required this.onOpenTeam,
  });

  final List<Team> teams;
  final VoidCallback onCreateTeam;
  final VoidCallback onJoinTeam;
  final void Function(Team team) onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups_outlined, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    '내 팀',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  _smallOutlineButton(
                    context,
                    icon: Icons.add,
                    label: '새 팀',
                    onTap: onCreateTeam,
                  ),
                  const SizedBox(width: 8),
                  _smallOutlineButton(
                    context,
                    icon: Icons.person_add_alt_1_outlined,
                    label: '팀 가입',
                    onTap: onJoinTeam,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (teams.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEF2F6)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('가입된 팀이 없습니다.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            Column(
              children: teams
                  .map(
                    (team) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TeamItem(team: team, onOpenTeam: onOpenTeam),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _smallOutlineButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: Colors.grey.shade700),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _TeamItem extends StatelessWidget {
  const _TeamItem({required this.team, required this.onOpenTeam});

  final Team team;
  final void Function(Team team) onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.groups_outlined,
              size: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    team.memberCount != null
                        ? '${team.memberCount}명의 멤버'
                        : '멤버 정보 없음',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: team.inviteCode),
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('초대 코드가 복사되었습니다.')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        team.inviteCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => onOpenTeam(team),
            icon: const Icon(Icons.login, size: 14, color: Colors.black87),
            label: const Text(
              '바로가기',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

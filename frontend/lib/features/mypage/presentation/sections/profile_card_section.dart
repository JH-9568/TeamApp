import 'package:flutter/material.dart';

class ProfileCardSection extends StatelessWidget {
  const ProfileCardSection({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.isUpdating,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final bool isUpdating;
  final VoidCallback onEdit;

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name.characters.first : '?',
                    style: const TextStyle(fontSize: 20, color: Colors.black54),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: isUpdating ? null : onEdit,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(isUpdating ? '저장 중...' : '편집'),
          ),
        ],
      ),
    );
  }
}

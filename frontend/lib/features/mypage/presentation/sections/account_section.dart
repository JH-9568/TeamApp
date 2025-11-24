import 'package:flutter/material.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

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
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: Colors.black54),
              SizedBox(width: 8),
              Text(
                '계정 관리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AccountTile(
            icon: Icons.logout,
            text: '로그아웃',
            textColor: Colors.black87,
            onTap: onLogout,
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.delete_outline,
            text: '계정 삭제',
            textColor: Colors.red,
            onTap: onDeleteAccount,
            isDanger: true,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.text,
    required this.textColor,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String text;
  final Color textColor;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDanger ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDanger ? const Color(0xFFFECACA) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }
}

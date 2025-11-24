import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.pushEnabled,
    required this.onPushToggle,
    required this.language,
    required this.onLanguageChange,
  });

  final bool pushEnabled;
  final ValueChanged<bool> onPushToggle;
  final String language;
  final VoidCallback onLanguageChange;

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
              Icon(Icons.settings_outlined, size: 20, color: Colors.black54),
              SizedBox(width: 8),
              Text(
                '설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingTile(
            leadingIcon: Icons.notifications_active,
            leadingColor: const Color(0xFF4F46E5),
            leadingBackground: const Color(0xFFE0E7FF),
            title: '푸시 알림',
            subtitle: '회의 알림',
            trailing: Switch(value: pushEnabled, onChanged: onPushToggle),
          ),
          const SizedBox(height: 12),
          _SettingTile(
            leadingIcon: Icons.language,
            leadingColor: const Color(0xFF16A34A),
            leadingBackground: const Color(0xFFDCFCE7),
            title: '언어',
            subtitle: language,
            trailing: OutlinedButton(
              onPressed: onLanguageChange,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text('변경', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.leadingIcon,
    required this.leadingColor,
    required this.leadingBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData leadingIcon;
  final Color leadingColor;
  final Color leadingBackground;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: leadingBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, size: 16, color: leadingColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

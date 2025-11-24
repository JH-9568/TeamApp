import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/routes.dart';
import 'package:frontend/features/auth/providers.dart';
import 'package:frontend/features/mypage/presentation/sections/account_section.dart';
import 'package:frontend/features/mypage/presentation/sections/my_teams_section.dart';
import 'package:frontend/features/mypage/presentation/sections/profile_card_section.dart';
import 'package:frontend/features/mypage/presentation/sections/settings_section.dart';
import 'package:frontend/features/mypage/providers.dart';
import 'package:frontend/features/team/models/team.dart';
import 'package:frontend/features/team/providers.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  bool _pushEnabled = true;
  String _language = '한국어';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPageControllerProvider.notifier).loadProfile();
      final teamState = ref.read(teamSelectionControllerProvider);
      if (teamState.teams.isEmpty && !teamState.isLoading) {
        ref.read(teamSelectionControllerProvider.notifier).loadTeams();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final myPageState = ref.watch(myPageControllerProvider);
    final teamState = ref.watch(teamSelectionControllerProvider);

    final user = myPageState.user ?? authState.session?.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    void handleLogout() {
      ref.read(authControllerProvider.notifier).logout();
      ref.read(teamSelectionControllerProvider.notifier).reset();
      context.go(AppRoute.login.path);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Row(
        children: [
          _Sidebar(
            onNavigate: (route) => context.go(route.path),
            onLogout: handleLogout,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  color: Colors.white,
                  width: double.infinity,
                  child: const Text(
                    '마이페이지',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (myPageState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    child: _ErrorBanner(message: myPageState.errorMessage!),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final leftColumn = Column(
                            children: [
                              ProfileCardSection(
                                name: user.name,
                                email: user.email,
                                avatarUrl: user.avatar,
                                isUpdating: myPageState.isSaving,
                                onEdit: () => _showEditDialog(user.name),
                              ),
                              const SizedBox(height: 24),
                              MyTeamsSection(
                                teams: teamState.teams,
                                onCreateTeam: () =>
                                    context.go(AppRoute.teamSelection.path),
                                onJoinTeam: () =>
                                    context.go(AppRoute.teamSelection.path),
                                onOpenTeam: (team) => _handleOpenTeam(team),
                              ),
                            ],
                          );

                          final rightColumn = Column(
                            children: [
                              SettingsSection(
                                pushEnabled: _pushEnabled,
                                onPushToggle: (value) =>
                                    setState(() => _pushEnabled = value),
                                language: _language,
                                onLanguageChange: () {
                                  setState(() {
                                    _language = _language == '한국어'
                                        ? 'English'
                                        : '한국어';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '언어가 $_language(으)로 변경되었습니다.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              AccountSection(
                                onLogout: handleLogout,
                                onDeleteAccount: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('곧 지원될 기능입니다.'),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 24),
                              const _VersionInfo(),
                            ],
                          );

                          if (constraints.maxWidth > 1000) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: leftColumn),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: rightColumn),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              leftColumn,
                              const SizedBox(height: 24),
                              rightColumn,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('이름 편집'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    try {
      await ref
          .read(myPageControllerProvider.notifier)
          .updateProfile(name: result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 업데이트되었습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('업데이트 실패: $error')));
    }
  }

  void _handleOpenTeam(Team team) {
    ref.read(teamSelectionControllerProvider.notifier).selectTeam(team);
    context.go(AppRoute.dashboard.path);
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onNavigate, required this.onLogout});

  final void Function(AppRoute route) onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Team',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _SidebarItem(
            title: '대시보드',
            icon: Icons.home_outlined,
            isActive: false,
            onTap: () => onNavigate(AppRoute.dashboard),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            title: '마이페이지',
            icon: Icons.person,
            isActive: true,
            onTap: () {},
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('로그아웃'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Team Meeting App v1.0',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF111827) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
      ),
    );
  }
}

class _VersionInfo extends StatelessWidget {
  const _VersionInfo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('Team v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
        SizedBox(height: 4),
        Text(
          '개인정보 수집 및 민감한 데이터 보안을 위해 설계되지 않았습니다',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C))),
    );
  }
}

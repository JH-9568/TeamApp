import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/routes.dart';
import 'package:frontend/features/auth/providers.dart';
import 'package:frontend/features/dashboard/models/dashboard_models.dart';
import 'package:frontend/features/dashboard/providers.dart';
import 'package:frontend/features/team/models/team.dart';
import 'package:frontend/features/team/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final teamState = ref.watch(teamSelectionControllerProvider);
    final selectedTeam = teamState.selectedTeam;

    void handleLogout() {
      ref.read(authControllerProvider.notifier).logout();
      ref.read(teamSelectionControllerProvider.notifier).reset();
      context.go(AppRoute.login.path);
    }

    if (selectedTeam == null) {
      return _NoTeamSelectedView(
        onSelectTeam: () => context.go(AppRoute.teamSelection.path),
        onLogout: handleLogout,
      );
    }

    final teamId = selectedTeam.id;
    final dashboardState = ref.watch(dashboardControllerProvider(teamId));
    final data = dashboardState.data;

    Future<void> openTeamPicker() async {
      final controller =
          ref.read(teamSelectionControllerProvider.notifier);
      if (!teamState.isLoading && teamState.teams.isEmpty) {
        controller.loadTeams();
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _TeamPickerSheet(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Row(
        children: [
          _Sidebar(
            activeRoute: AppRoute.dashboard,
            onNavigate: (route) => context.go(route.path),
            onLogout: handleLogout,
          ),
          Expanded(
            child: Column(
              children: [
                _DashboardHeader(
                  teamName: data?.team.name ?? selectedTeam.name,
                  memberCount: data?.team.members.length ?? 0,
                  onTeamSwitch: openTeamPicker,
                  onMeetingStart: () =>
                      _handleStartMeeting(context, ref, selectedTeam.id, data),
                  isMeetingStarting:
                      dashboardState.isCreatingMeeting || dashboardState.isLoading,
                ),
                Expanded(
                  child: dashboardState.isLoading && data == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(
                                dashboardControllerProvider(teamId).notifier,
                              )
                              .refresh(teamId),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StatsRow(
                                    data: data,
                                    userId: authState.session?.user.id,
                                    userName: authState.session?.user.name,
                                  ),
                                  const SizedBox(height: 24),
                                  if (dashboardState.errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _ErrorBanner(
                                        message: dashboardState.errorMessage!,
                                      ),
                                    ),
                                  if (data != null)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth < 900) {
                                          return Column(
                                            children: [
                                              _ActionItemsSection(
                                                items: data.actionItems,
                                                isCreating: dashboardState
                                                    .isCreatingActionItem,
                                                onRequestAdd: () =>
                                                    _handleAddActionItem(
                                                      context,
                                                      ref,
                                                      data,
                                                      teamId,
                                                    ),
                                                onComplete: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .updateActionItemStatus(
                                                      id,
                                                      'done',
                                                    ),
                                                onReopen: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .updateActionItemStatus(
                                                      id,
                                                      'pending',
                                                    ),
                                                onDelete: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .deleteActionItem(id),
                                                onEdit: (item) =>
                                                    _handleEditActionItem(
                                                        context, ref, item, teamId),
                                              ),
                                              const SizedBox(height: 24),
                                              _RightPanelSection(
                                                members: data.team.members,
                                                meetings: data.meetings,
                                                actionItems: data.actionItems,
                                              ),
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _ActionItemsSection(
                                                items: data.actionItems,
                                                isCreating: dashboardState
                                                    .isCreatingActionItem,
                                                onRequestAdd: () =>
                                                    _handleAddActionItem(
                                                      context,
                                                      ref,
                                                      data,
                                                      teamId,
                                                    ),
                                                onComplete: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .updateActionItemStatus(
                                                      id,
                                                      'done',
                                                    ),
                                                onReopen: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .updateActionItemStatus(
                                                      id,
                                                      'pending',
                                                    ),
                                                onDelete: (id) => ref
                                                    .read(
                                                      dashboardControllerProvider(
                                                        teamId,
                                                      ).notifier,
                                                    )
                                                    .deleteActionItem(id),
                                                onEdit: (item) =>
                                                    _handleEditActionItem(
                                                        context, ref, item, teamId),
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              flex: 1,
                                              child: _RightPanelSection(
                                                members: data.team.members,
                                                meetings: data.meetings,
                                                actionItems: data.actionItems,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  else
                                    const _EmptyDashboardPlaceholder(),
                                ],
                              ),
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

  Future<void> _handleAddActionItem(
    BuildContext context,
    WidgetRef ref,
    DashboardData data,
    String teamId,
  ) async {
    if (data.meetings.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회의를 먼저 생성해주세요.')));
      return;
    }

    final result = await _showActionItemDialog(context, data.meetings);
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(dashboardControllerProvider(teamId).notifier)
          .createActionItem(
            meetingId: result.meetingId,
            type: result.type,
            assignee: result.assignee,
            content: result.content,
            status: result.status,
            dueDate: result.dueDate,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('액션 아이템이 추가되었습니다.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('추가에 실패했습니다: $error')));
    }
  }

  Future<void> _handleEditActionItem(
    BuildContext context,
    WidgetRef ref,
    DashboardActionItem item,
    String teamId,
  ) async {
    final result = await _showEditActionItemDialog(context, item);
    if (result == null) return;
    try {
      await ref.read(dashboardControllerProvider(teamId).notifier).editActionItem(
            item.id,
            type: result.type,
            assignee: result.assignee,
            content: result.content,
            status: result.status,
            dueDate: result.dueDate,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('액션 아이템이 수정되었습니다.')),
      );
    } catch (error, stack) {
      debugPrint('Failed to edit action item: $error\n$stack');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정에 실패했습니다: $error')),
      );
    }
  }

  Future<void> _handleStartMeeting(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    DashboardData? data,
  ) async {
    final defaultTitle = '${data?.team.name ?? '팀'} 회의';
    final title = await _showMeetingTitleDialog(context, defaultTitle);
    if (title == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(dashboardControllerProvider(teamId).notifier);
    try {
      final meeting = await controller.createMeeting(teamId: teamId, title: title);
      if (!context.mounted) {
        return;
      }
      context.go('${AppRoute.voiceMeeting.path}?meetingId=${meeting.id}');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('회의 생성에 실패했습니다: $error')),
      );
    }
  }

  Future<String?> _showMeetingTitleDialog(
    BuildContext context,
    String defaultTitle,
  ) async {
    final controller = TextEditingController(text: defaultTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('새 회의 시작'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '회의 제목',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('시작'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) {
      return null;
    }
    return result;
  }

  Future<_ActionItemFormResult?> _showActionItemDialog(
    BuildContext context,
    List<DashboardMeeting> meetings,
  ) {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: '할일');
    final assigneeController = TextEditingController();
    final contentController = TextEditingController();
    String? meetingId = meetings.isNotEmpty ? meetings.first.id : null;
    String status = 'pending';
    DateTime? dueDate;

    String? validateRequired(String? value, String label) {
      if (value == null || value.trim().isEmpty) {
        return '$label을(를) 입력해주세요.';
      }
      return null;
    }

    return showDialog<_ActionItemFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '액션 아이템 추가',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: meetingId,
                          decoration: const InputDecoration(
                            labelText: '회의 선택',
                            border: OutlineInputBorder(),
                          ),
                          items: meetings
                              .map(
                                (meeting) => DropdownMenuItem(
                                  value: meeting.id,
                                  child: Text(meeting.title),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => meetingId = value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: typeController,
                          decoration: const InputDecoration(
                            labelText: '타입',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '타입'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: assigneeController,
                          decoration: const InputDecoration(
                            labelText: '담당자',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '담당자'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: contentController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '내용',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '내용'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: dueDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => dueDate = picked);
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  dueDate == null
                                      ? '마감일 선택'
                                      : '마감일: ${dueDate!.year}.${dueDate!.month}.${dueDate!.day}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('진행'),
                                ),
                                DropdownMenuItem(
                                  value: 'done',
                                  child: Text('완료'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => status = value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }
                              if (meetingId == null) {
                                return;
                              }
                              Navigator.of(context).pop(
                                _ActionItemFormResult(
                                  meetingId: meetingId!,
                                  type: typeController.text.trim(),
                                  assignee: assigneeController.text.trim(),
                                  content: contentController.text.trim(),
                                  status: status,
                                  dueDate: dueDate,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B5563),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('추가하기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_ActionItemFormResult?> _showEditActionItemDialog(
    BuildContext context,
    DashboardActionItem item,
  ) {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: item.type);
    final assigneeController = TextEditingController(text: item.assignee);
    final contentController = TextEditingController(text: item.content);
    String status = item.status;
    DateTime? dueDate = item.dueDate;

    String? validateRequired(String? value, String label) {
      if (value == null || value.trim().isEmpty) {
        return '$label을(를) 입력해주세요.';
      }
      return null;
    }

    return showDialog<_ActionItemFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '액션 아이템 수정',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: typeController,
                          decoration: const InputDecoration(
                            labelText: '타입',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '타입'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: assigneeController,
                          decoration: const InputDecoration(
                            labelText: '담당자',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '담당자'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: contentController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '내용',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => validateRequired(value, '내용'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: dueDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => dueDate = picked);
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  dueDate == null
                                      ? '마감일 선택'
                                      : '마감일: ${dueDate!.year}.${dueDate!.month}.${dueDate!.day}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('진행'),
                                ),
                                DropdownMenuItem(
                                  value: 'done',
                                  child: Text('완료'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => status = value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }
                              Navigator.of(context).pop(
                                _ActionItemFormResult(
                                  meetingId: item.meetingId,
                                  type: typeController.text.trim(),
                                  assignee: assigneeController.text.trim(),
                                  content: contentController.text.trim(),
                                  status: status,
                                  dueDate: dueDate,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B5563),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('수정하기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeRoute,
    required this.onNavigate,
    required this.onLogout,
  });

  final AppRoute activeRoute;
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
            icon: Icons.home_filled,
            isActive: activeRoute == AppRoute.dashboard,
            onTap: () => onNavigate(AppRoute.dashboard),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            title: '마이페이지',
            icon: Icons.person_outline,
            isActive: activeRoute == AppRoute.myPage,
            onTap: () => onNavigate(AppRoute.myPage),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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
    required this.onTap,
    this.isActive = false,
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.teamName,
    required this.memberCount,
    required this.onTeamSwitch,
    required this.onMeetingStart,
    this.isMeetingStarting = false,
  });

  final String teamName;
  final int memberCount;
  final VoidCallback onTeamSwitch;
  final VoidCallback onMeetingStart;
  final bool isMeetingStarting;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTeamSwitch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    teamName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.people_outline, size: 18, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            '$memberCount 명',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isMeetingStarting ? null : onMeetingStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: isMeetingStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.videocam_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('회의 시작', style: TextStyle(fontSize: 13)),
                    ],
                  ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.notifications_none, color: Colors.grey),
        ],
      ),
    );
  }
}

class _TeamPickerSheet extends ConsumerWidget {
  const _TeamPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamState = ref.watch(teamSelectionControllerProvider);
    final teams = teamState.teams;
    final selectedTeamId = teamState.selectedTeam?.id;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '팀 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '참여 중인 팀을 선택해 대시보드를 전환하세요.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (teamState.isLoading && teams.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (teams.isEmpty)
              Expanded(
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(AppRoute.teamSelection.path);
                    },
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('팀을 먼저 생성하거나 참여하세요'),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final isSelected = team.id == selectedTeamId;
                    return _TeamPickerTile(
                      team: team,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(teamSelectionControllerProvider.notifier)
                            .selectTeam(team);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: teams.length,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(AppRoute.teamSelection.path);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('팀 관리 / 생성'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF111827),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPickerTile extends StatelessWidget {
  const _TeamPickerTile({
    required this.team,
    required this.isSelected,
    required this.onTap,
  });

  final Team team;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    team.memberCount != null
                        ? '${team.memberCount}명 참여 중'
                        : '참여 인원 정보 없음',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white)
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({this.data, this.userId, this.userName});

  final DashboardData? data;
  final String? userId;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final totalMeetings = data?.meetings.length ?? 0;
    final myItems = (data?.actionItems ?? []).where((item) {
      final idMatch =
          userId != null && item.assigneeUserId != null && item.assigneeUserId == userId;
      final nameMatch = (userName != null && userName!.isNotEmpty)
          ? item.assignee.trim() == userName!.trim()
          : false;
      return idMatch || nameMatch;
    }).toList();
    final myCompleted = myItems
        .where((item) => item.status.toLowerCase() == 'done')
        .length;
    final completionRate = myItems.isEmpty
        ? 0
        : ((myCompleted / myItems.length) * 100).round();
    final avgDuration = _averageDurationMinutes(data?.meetings ?? []);

    return Row(
      children: [
        _StatCard(
          title: '총 회의',
          value: '$totalMeetings 회',
          icon: Icons.calendar_today,
          iconColor: Colors.blue,
        ),
        const SizedBox(width: 16),
        _StatCard(
          title: '내 할 일',
          value: '$myCompleted / ${myItems.length} 개',
          icon: Icons.check_circle_outline,
          iconColor: Colors.purple,
        ),
        const SizedBox(width: 16),
        _StatCard(
          title: '내 완료율',
          value: '$completionRate %',
          icon: Icons.trending_up,
          iconColor: Colors.green,
        ),
        const SizedBox(width: 16),
        _StatCard(
          title: '평균 회의 시간',
          value: '$avgDuration 분',
          icon: Icons.access_time,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  static int _averageDurationMinutes(List<DashboardMeeting> meetings) {
    final durations = meetings
        .map(_computeMeetingDurationMinutes)
        .where((d) => d > 0)
        .toList();
    if (durations.isEmpty) return 0;
    final total = durations.fold<int>(0, (sum, value) => sum + value);
    return (total / durations.length).round();
  }

  static int _computeMeetingDurationMinutes(DashboardMeeting meeting) {
    if ((meeting.duration ?? 0) > 0) {
      return meeting.duration!;
    }
    final start = meeting.startDateTime;
    if (start == null || meeting.endTime == null) {
      return 0;
    }
    final parts = meeting.endTime!.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final end = DateTime(
      start.year,
      start.month,
      start.day,
      hour,
      minute,
    );
    final diff = end.difference(start).inMinutes;
    return diff > 0 ? diff : 0;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: iconColor),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItemsSection extends StatelessWidget {
  const _ActionItemsSection({
    required this.items,
    required this.isCreating,
    this.onRequestAdd,
    this.onComplete,
    this.onReopen,
    this.onDelete,
    this.onEdit,
  });

  final List<DashboardActionItem> items;
  final bool isCreating;
  final VoidCallback? onRequestAdd;
  final void Function(String id)? onComplete;
  final void Function(String id)? onReopen;
  final void Function(String id)? onDelete;
  final void Function(DashboardActionItem item)? onEdit;

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]
      ..sort((a, b) {
        final dueA = a.dueDate ?? DateTime(2100);
        final dueB = b.dueDate ?? DateTime(2100);
        return dueA.compareTo(dueB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '액션 아이템',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: isCreating ? null : onRequestAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (isCreating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.add, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isCreating ? '추가 중' : '추가',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey,
                    ),
                    hintText: '검색...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Text('전체', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (sortedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, color: Colors.grey),
                SizedBox(height: 8),
                Text('등록된 액션 아이템이 없습니다.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ...sortedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActionItemCard(
                item: item,
                onComplete: onComplete,
                onReopen: onReopen,
                onDelete: onDelete,
                onEdit: onEdit,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard({
    required this.item,
    this.onComplete,
    this.onReopen,
    this.onDelete,
    this.onEdit,
  });

  final DashboardActionItem item;
  final void Function(String id)? onComplete;
  final void Function(String id)? onReopen;
  final void Function(String id)? onDelete;
  final void Function(DashboardActionItem item)? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDone = item.status.toLowerCase() == 'done';
    final statusColor = isDone ? Colors.green : Colors.grey.shade300;
    final dueDateLabel = _formatDate(item.dueDate) ?? '마감일 없음';
    final meetingLabel = item.meetingTitle ?? '미팅 미지정';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: isDone ? Colors.green : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.content,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Tag(label: item.type),
                          Text(
                            '${item.assignee} • $dueDateLabel',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          _Tag(label: meetingLabel, icon: Icons.video_call),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onEdit == null ? null : () => onEdit!(item),
                          child: const Text(
                            '수정',
                            style: TextStyle(color: Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed:
                              onDelete == null ? null : () => onDelete!(item.id),
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (isDone) {
                              onReopen?.call(item.id);
                            } else {
                              onComplete?.call(item.id);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDone
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isDone ? '다시 진행' : '완료'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _RightPanelSection extends StatelessWidget {
  const _RightPanelSection({
    required this.members,
    required this.meetings,
    required this.actionItems,
  });

  final List<DashboardMember> members;
  final List<DashboardMeeting> meetings;
  final List<DashboardActionItem> actionItems;

  @override
  Widget build(BuildContext context) {
    final memberSummary = _buildMemberSummary(actionItems);
    final nextMeeting = _nextMeeting(meetings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '팀원',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: members
                .map(
                  (member) => Column(
                    children: [
                      _MemberRow(
                        member: member,
                        summary: memberSummary[member.id],
                      ),
                      if (member != members.last)
                        const Divider(
                          height: 24,
                          thickness: 0.5,
                          color: Color(0xFFF4F6F8),
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '최근 회의',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: nextMeeting == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '최근 회의가 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : InkWell(
                  onTap: () => context.push(
                    '${AppRoute.meetingDetail.path}?meetingId=${nextMeeting.id}',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nextMeeting.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                nextMeeting.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _meetingTimeLabel(nextMeeting),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.list_alt, size: 14, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(
                              '액션 아이템 ${nextMeeting.actionItemsCount}개',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Map<String, _MemberTaskStats> _buildMemberSummary(
    List<DashboardActionItem> items,
  ) {
    final map = <String, _MemberTaskStats>{};
    for (final item in items) {
      final key = item.assigneeUserId;
      if (key == null) continue;
      final entry = map.putIfAbsent(key, () => _MemberTaskStats());
      entry.total++;
      if (item.status.toLowerCase() == 'done') {
        entry.completed++;
      }
    }
    return map;
  }

  DashboardMeeting? _nextMeeting(List<DashboardMeeting> meetings) {
    final recent = meetings.where((meeting) {
      return meeting.status.toLowerCase() != 'scheduled';
    }).toList()
      ..sort((a, b) {
        final dateA = a.startDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.startDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    return recent.isEmpty ? null : recent.first;
  }

  String _meetingTimeLabel(DashboardMeeting meeting) {
    final date = meeting.date;
    if (date == null) return meeting.startTime ?? '-';
    final dateLabel = '${date.month}/${date.day}';
    return meeting.startTime != null
        ? '$dateLabel ${meeting.startTime}'
        : dateLabel;
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.summary});

  final DashboardMember member;
  final _MemberTaskStats? summary;

  @override
  Widget build(BuildContext context) {
    final subText = summary == null
        ? null
        : '${summary!.completed}/${summary!.total} 완료';
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE2E8F0),
          radius: 18,
          child: Text(
            member.name.isNotEmpty ? member.name.characters.first : '?',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (subText != null)
              Text(
                subText,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ],
    );
  }
}

class _MemberTaskStats {
  int total = 0;
  int completed = 0;
}

class _NoTeamSelectedView extends StatelessWidget {
  const _NoTeamSelectedView({
    required this.onSelectTeam,
    required this.onLogout,
  });

  final VoidCallback onSelectTeam;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '먼저 팀을 선택해주세요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onSelectTeam,
              child: const Text('팀 선택 화면으로 이동'),
            ),
            TextButton(onPressed: onLogout, child: const Text('로그아웃')),
          ],
        ),
      ),
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

class _EmptyDashboardPlaceholder extends StatelessWidget {
  const _EmptyDashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey),
          SizedBox(height: 12),
          Text('대시보드 데이터가 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return '${date.month}/${date.day}';
}

class _ActionItemFormResult {
  _ActionItemFormResult({
    required this.meetingId,
    required this.type,
    required this.assignee,
    required this.content,
    required this.status,
    this.dueDate,
  });

  final String meetingId;
  final String type;
  final String assignee;
  final String content;
  final String status;
  final DateTime? dueDate;
}

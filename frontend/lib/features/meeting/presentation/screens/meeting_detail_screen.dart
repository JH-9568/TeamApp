import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/meeting/models/meeting_models.dart';
import 'package:frontend/features/meeting/providers.dart';

class MeetingDetailScreen extends ConsumerWidget {
  const MeetingDetailScreen({super.key, this.meetingId});

  final String? meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (meetingId == null || meetingId!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('회의 ID가 없습니다.')),
      );
    }

    final repo = ref.watch(meetingRepositoryProvider);

    return FutureBuilder<MeetingDetail>(
      future: repo.fetchMeeting(meetingId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('회의 정보를 불러올 수 없습니다: ${snapshot.error}'),
            ),
          );
        }
        final meeting = snapshot.data;
        if (meeting == null) {
          return const Scaffold(
            body: Center(child: Text('회의 정보를 찾을 수 없습니다.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(meeting.title),
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(summary: meeting.summary),
                const SizedBox(height: 16),
                _ActionItemsCard(items: meeting.actionItems),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final safe = (summary ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '회의 요약',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            safe.isEmpty ? '요약이 없습니다.' : safe,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActionItemsCard extends StatelessWidget {
  const _ActionItemsCard({required this.items});

  final List<MeetingActionItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '생성된 할 일',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${items.length}개',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              '생성된 할 일이 없습니다.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusChip(status: item.status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '담당: ${item.assignee}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (item.dueDate != null)
                        Text(
                          '마감: ${item.dueDate}',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDone = status.toLowerCase() == 'done';
    final bg = isDone ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final label = isDone ? '완료' : '진행';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'package:frontend/features/auth/providers.dart';

import '../../models/meeting_models.dart';
import '../../providers.dart';
import '../controllers/meeting_controller.dart';

class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key, this.meetingId});

  final String? meetingId;

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  int _currentTabIndex = 0;
  final _actionContentController = TextEditingController();
  final _actionAssigneeController = TextEditingController();
  final _transcriptController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;
  String _actionType = '할일';
  bool _isRecording = false;

  @override
  void dispose() {
    _actionContentController.dispose();
    _actionAssigneeController.dispose();
    _transcriptController.dispose();
    _micSubscription?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetingId = widget.meetingId;
    if (meetingId == null || meetingId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(
          child: Text(
            '회의 정보가 없습니다.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    ref.listen<MeetingState>(
      meetingControllerProvider(meetingId),
      (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage!)),
          );
          ref
              .read(meetingControllerProvider(meetingId).notifier)
              .clearError();
        }
      },
    );

    final state = ref.watch(meetingControllerProvider(meetingId));
    final controller = ref.read(meetingControllerProvider(meetingId).notifier);
    final meeting = state.meeting;
    final isLoading = state.isLoading && meeting == null;
    final authUser = ref.watch(authControllerProvider).session?.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            MeetingTopBar(
              meetingTitle: meeting?.title ?? '회의',
              timerLabel: _timerLabel(meeting),
              status: meeting?.status ?? 'scheduled',
              isRecording: meeting?.status == 'in-progress',
              onEndMeeting: controller.endMeeting,
              onRefresh: controller.refresh,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 1024;
                          final participantsPanel = SizedBox(
                            width: isNarrow ? double.infinity : 280,
                            child: ParticipantsPanel(
                              participants: state.attendees,
                              activeSpeaker: state.transcripts.isNotEmpty
                                  ? state.transcripts.last.speaker
                                  : null,
                            ),
                          );
                          final tabContent = Expanded(
                            child: Column(
                              children: [
                                MeetingTabs(
                                  currentIndex: _currentTabIndex,
                                  onTabChanged: (index) => setState(
                                    () => _currentTabIndex = index,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    child: _buildTabContent(
                                      context,
                                      state,
                                      controller,
                                      authUser?.name ?? '나',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                participantsPanel,
                                const SizedBox(height: 16),
                                tabContent,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              participantsPanel,
                              const SizedBox(width: 16),
                              tabContent,
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _timerLabel(MeetingDetail? meeting) {
    if (meeting == null) {
      return '00:00';
    }
    if (meeting.duration != null && meeting.duration! > 0) {
      final minutes = meeting.duration!;
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
      }
      return '00:${mins.toString().padLeft(2, '0')}';
    }
    return meeting.startTime ?? '00:00';
  }

  Widget _buildTabContent(
    BuildContext context,
    MeetingState state,
    MeetingController controller,
    String defaultAssignee,
  ) {
    switch (_currentTabIndex) {
      case 0:
        return SubtitlesTab(
          transcripts: state.transcripts,
          isConnected: state.isConnected,
          transcriptController: _transcriptController,
          isSubmitting: state.isSubmittingTranscript,
          isRecording: _isRecording,
          onToggleRecording: () => _toggleRecording(controller),
          onSubmitTranscript: (text) async {
            await controller.submitTranscript(text);
            _transcriptController.clear();
          },
        );
      case 1:
        return AiSummaryTab(
          summary: state.meeting?.summary,
          isLoading: state.isSummaryLoading,
          onRegenerate: controller.requestSummary,
        );
      case 2:
        return ActionItemTab(
          items: state.actionItems,
          isSyncing: state.isActionSyncing,
          isSubmitting: state.isSubmittingAction,
          typeValue: _actionType,
          assigneeController: _actionAssigneeController,
          contentController: _actionContentController,
          onTypeChanged: (value) => setState(() => _actionType = value),
          onSubmit: () {
            final content = _actionContentController.text.trim();
            final assignee = _actionAssigneeController.text.trim().isEmpty
                ? defaultAssignee
                : _actionAssigneeController.text.trim();
            if (content.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('내용을 입력해주세요.')),
              );
              return;
            }
            controller.addActionItem(
              ActionItemInput(
                type: _actionType,
                assignee: assignee,
                content: content,
              ),
            );
            _actionContentController.clear();
          },
          onGenerate: controller.extractActionItems,
        );
      case 3:
        return ParticipationTab(stats: state.speakerStats);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _toggleRecording(MeetingController controller) async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한을 허용해주세요.')),
        );
      }
      return;
    }
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    setState(() => _isRecording = true);
    _micSubscription = stream.listen(
      (chunk) => controller.sendAudioChunk(Uint8List.fromList(chunk)),
      onError: (error) => debugPrint('Recorder error: $error'),
    );
  }

  Future<void> _stopRecording() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();
    if (mounted) {
      setState(() => _isRecording = false);
    }
  }
}

class MeetingTopBar extends StatelessWidget {
  const MeetingTopBar({
    super.key,
    required this.meetingTitle,
    required this.timerLabel,
    required this.status,
    required this.isRecording,
    required this.onEndMeeting,
    required this.onRefresh,
  });

  final String meetingTitle;
  final String timerLabel;
  final String status;
  final bool isRecording;
  final VoidCallback onEndMeeting;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF334155)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRecording ? Colors.redAccent : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timerLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isRecording
                  ? Colors.red.withValues(alpha: 0.18)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRecording ? Colors.red.shade800 : Colors.grey.shade600,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  size: 12,
                  color: isRecording ? Colors.red : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  isRecording ? '녹음 중' : status,
                  style: TextStyle(
                    color: isRecording ? Colors.red : Colors.grey.shade300,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onEndMeeting,
            icon: const Icon(Icons.call_end, size: 16),
            label: const Text('회의 종료'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParticipantsPanel extends StatelessWidget {
  const ParticipantsPanel({
    super.key,
    required this.participants,
    this.activeSpeaker,
  });

  final List<MeetingAttendee> participants;
  final String? activeSpeaker;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final hasBoundedHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
      final listWidget = participants.isEmpty
          ? const Center(
              child: Text(
                '아직 참여자가 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              shrinkWrap: !hasBoundedHeight,
              physics:
                  hasBoundedHeight ? null : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final attendee = participants[index];
                final isSpeaking =
                    activeSpeaker != null &&
                    attendee.displayName == activeSpeaker;
                return _ParticipantCard(
                  name: attendee.displayName,
                  isSpeaking: isSpeaking,
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: participants.length,
            );

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '참여자',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    participants.length.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasBoundedHeight)
              Expanded(child: listWidget)
            else
              listWidget,
          ],
        ),
      );
    });
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.name, required this.isSpeaking});

  final String name;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF334155).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF475569)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF64748B),
                child: Text(
                  name.characters.first,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (isSpeaking)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isSpeaking ? '발언 중' : '대기 중',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MeetingTabs extends StatelessWidget {
  const MeetingTabs({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  static const _tabs = [
    (label: '실시간 자막', icon: Icons.description_outlined),
    (label: 'AI 요약', icon: Icons.auto_awesome_outlined),
    (label: '액션 아이템', icon: Icons.check_circle_outline),
    (label: '참여도', icon: Icons.bar_chart),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
          left: BorderSide(color: Color(0xFF334155)),
          right: BorderSide(color: Color(0xFF334155)),
          bottom: BorderSide(color: Color(0xFF334155)),
        ),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final isActive = currentIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onTabChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF334155) : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: isActive ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SubtitlesTab extends StatelessWidget {
  const SubtitlesTab({
    super.key,
    required this.transcripts,
    required this.isConnected,
    required this.transcriptController,
    required this.isSubmitting,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onSubmitTranscript,
  });

  final List<TranscriptSegment> transcripts;
  final bool isConnected;
  final TextEditingController transcriptController;
  final bool isSubmitting;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final Future<void> Function(String text) onSubmitTranscript;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: const Color(0xFF172554),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: isConnected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? '실시간 STT 진행 중' : '연결 대기 중',
                style: TextStyle(
                  color: isConnected ? Colors.blue : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (context, index) {
              final item = transcripts[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.timestamp,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.speaker,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemCount: transcripts.length,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Color(0xFF334155))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '총 ${transcripts.length}개 발언 기록됨',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: isConnected ? onToggleRecording : null,
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    label: Text(isRecording ? '녹음 중지' : '음성 전송 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isRecording ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isRecording
                          ? '마이크 입력을 실시간으로 전송 중입니다.'
                          : '버튼을 눌러 음성을 전송하거나 아래 입력창을 사용하세요.',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: transcriptController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: isConnected
                            ? '여기에 입력하면 실시간 자막으로 추가됩니다.'
                            : '연결 대기 중...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF475569)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF475569)),
                        ),
                      ),
                      enabled: isConnected && !isSubmitting,
                      onSubmitted: (value) async {
                        final text = value.trim();
                        if (text.isEmpty) return;
                        await onSubmitTranscript(text);
                        transcriptController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: !isConnected || isSubmitting
                        ? null
                        : () async {
                            final text = transcriptController.text.trim();
                            if (text.isEmpty) {
                              return;
                            }
                            await onSubmitTranscript(text);
                            transcriptController.clear();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('추가'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AiSummaryTab extends StatelessWidget {
  const AiSummaryTab({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.onRegenerate,
  });

  final String? summary;
  final bool isLoading;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4338CA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.description_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'AI 자동 요약',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: isLoading ? null : onRegenerate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF312E81),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('다시 생성'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        summary ??
                            '회의가 진행되면 AI가 자동으로 요약을 생성합니다.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '회의 통계',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _StatItem(label: '진행 시간 (분)', value: '0'),
                      _StatItem(label: '발언 수', value: '0'),
                      _StatItem(label: '액션 아이템', value: '0'),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}

class ActionItemTab extends StatelessWidget {
  const ActionItemTab({
    super.key,
    required this.items,
    required this.isSyncing,
    required this.isSubmitting,
    required this.typeValue,
    required this.assigneeController,
    required this.contentController,
    required this.onTypeChanged,
    required this.onSubmit,
    required this.onGenerate,
  });

  final List<MeetingActionItem> items;
  final bool isSyncing;
  final bool isSubmitting;
  final String typeValue;
  final TextEditingController assigneeController;
  final TextEditingController contentController;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onGenerate;

  static const _types = ['할일', '논의', 'Shared'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    '액션 아이템이 없습니다',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.type,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.status,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.content,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '담당자: ${item.assignee}',
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemCount: items.length,
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Color(0xFF334155))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: typeValue,
                      decoration: _inputDecoration('타입'),
                      dropdownColor: const Color(0xFF0F172A),
                      items: _types
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onTypeChanged(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: assigneeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('담당자'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: contentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('액션 아이템 내용...'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('추가'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isSyncing ? null : onGenerate,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white70),
                  label: Text(
                    isSyncing ? 'AI가 분석 중...' : 'AI로 채우기',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF334155),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF475569)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF475569)),
      ),
    );
  }
}

class ParticipationTab extends StatelessWidget {
  const ParticipationTab({super.key, required this.stats});

  final List<SpeakerStat> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '참여도 분석',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (stats.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  '참여도 데이터가 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemBuilder: (context, index) {
                  final stat = stats[index];
                  return _ParticipationRow(
                    rank: index + 1,
                    stat: stat,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: stats.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _ParticipationRow extends StatelessWidget {
  const _ParticipationRow({required this.rank, required this.stat});

  final int rank;
  final SpeakerStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                stat.speaker,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(stat.participationRate ?? 0).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 64, top: 8),
          child: Row(
            children: [
              _smallStat('발언 ${stat.speakCount}회'),
              const SizedBox(width: 16),
              _smallStat('총 ${stat.speakTime}초'),
              const SizedBox(width: 16),
              _smallStat('평균 ${(stat.avgLength ?? 0).toStringAsFixed(1)}초'),
            ],
          ),
        ),
        const Divider(color: Color(0xFF334155), height: 1),
      ],
    );
  }

  Widget _smallStat(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
    );
  }
}

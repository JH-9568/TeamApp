import '../models/dashboard_models.dart';
import 'dashboard_api.dart';

class DashboardRepository {
  const DashboardRepository(this._api);

  final DashboardApi _api;

  Future<DashboardData> fetchDashboard(String teamId) async {
    final teamFuture = _api.fetchTeamDetail(teamId);
    final actionItemsFuture = _api.fetchActionItems(teamId);
    final meetingsFuture = _api.fetchMeetings(teamId);

    final results = await Future.wait([
      teamFuture,
      actionItemsFuture,
      meetingsFuture,
    ]);

    return DashboardData(
      team: results[0] as DashboardTeam,
      actionItems: results[1] as List<DashboardActionItem>,
      meetings: results[2] as List<DashboardMeeting>,
    );
  }

  Future<DashboardActionItem> createActionItem({
    required String meetingId,
    required String type,
    required String assignee,
    required String content,
    String status = 'pending',
    DateTime? dueDate,
  }) {
    return _api.createActionItem(
      meetingId: meetingId,
      type: type,
      assignee: assignee,
      content: content,
      status: status,
      dueDate: dueDate,
    );
  }

  Future<DashboardMeeting> createMeeting({
    required String teamId,
    required String title,
  }) {
    return _api.createMeeting(teamId: teamId, title: title);
  }

  Future<DashboardActionItem> updateActionItemStatus(
    String actionItemId,
    String status,
  ) {
    return _api.updateActionItemStatus(actionItemId, status);
  }

  Future<DashboardActionItem> updateActionItem(
    String actionItemId, {
    String? type,
    String? assignee,
    String? content,
    String? status,
    DateTime? dueDate,
  }) {
    return _api.updateActionItem(
      actionItemId,
      type: type,
      assignee: assignee,
      content: content,
      status: status,
      dueDate: dueDate,
    );
  }

  Future<void> deleteActionItem(String actionItemId) {
    return _api.deleteActionItem(actionItemId);
  }
}

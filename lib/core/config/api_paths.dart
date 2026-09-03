abstract final class ApiPaths {
  static const login = '/api/v1/auth/login';
  static const register = '/api/v1/auth/register';
  static const pushTokens = '/api/v1/push-tokens';
  static const me = '/api/users/me';
  static const users = '/api/users';
  static const members = '/api/v1/members';
  static String memberRole(int id) => '/api/v1/members/$id/role';
  static const transferGuildMaster = '/api/v1/guild/master';
  static String memberPasswordReset(int id) =>
      '/api/v1/members/$id/password-reset';
  static String member(int id) => '/api/v1/members/$id';
  static const legacyMembers = '/api/users';
  static String legacyAdminUserRole(int id) => '/api/admin/users/$id/role';
  static const legacyTransferGuildMaster = '/api/admin/guild/master';
  static String legacyAdminUserPassword(int id) =>
      '/api/admin/users/$id/reset-password';
  static String legacyAdminUser(int id) => '/api/admin/users/$id';
  static const serverTime = '/api/v1/time';
  static const legacyServerTime = '/api/time';
  static const guildSettings = '/api/v1/guild/settings';
  static const guildInvites = '/api/v1/auth/invites';
  static const legacySettings = '/api/settings';
  static const legacyInvites = '/api/invites';
  static const schedules = '/api/v1/schedules';
  static const schedulesCut = '/api/v1/schedules/cut';
  static const schedulesMung = '/api/v1/schedules/mung';
  static const schedulesAll = '/api/v1/schedules';
  static const customBosses = '/api/v1/bosses';
  static const customBossesReorder = '/api/v1/bosses/order';
  static const resetBosses = '/api/v1/bosses/reset';
  static const participants = '/api/v1/participants';
  static const participationTargets = '/api/v1/participation-targets';
  static const participationStates = '/api/v1/participation-states';
  static const legacySchedules = '/api/schedules';
  static const legacySchedulesCut = '/api/schedules/cut';
  static const legacySchedulesMung = '/api/schedules/mung';
  static const legacySchedulesAll = '/api/schedules-all';
  static const legacyCustomBosses = '/api/custom-bosses';
  static const legacyCustomBossesReorder = '/api/custom-bosses/reorder';
  static const legacyResetBosses = '/api/admin/reset-bosses';
  static const legacyParticipants = '/api/participants';
  static const legacyParticipationTargets = '/api/participation-targets';
  static const legacyParticipationStates = '/api/participation-states';
  static const ocrTemplates = '/api/ocr/templates';
  static const ocrBossSchedule = '/api/ocr/boss-schedule';
  static const voteBosses = '/api/v1/boss-votes';
  static const voteBossesManual = '/api/v1/boss-votes/manual';
  static String voteParticipation(String voteKey) =>
      '/api/v1/boss-votes/${Uri.encodeComponent(voteKey)}/participation';
  static const legacyVoteBosses = '/api/vote-bosses';
  static const legacyVoteBossesManual = '/api/vote-bosses/manual';
  static const legacyVoteParticipants = '/api/vote-participants';
  static const noticeRules = '/api/v1/notices/rules';
  static const noticeRuleOrder = '/api/v1/notices/rules/order';
  static String noticeRule(int id) => '/api/v1/notices/rules/$id';
  static const noticePriceGuides = '/api/v1/notices/price-guides';
  static String noticePriceGuide(int id) => '/api/v1/notices/price-guides/$id';
  static const noticeBossControls = '/api/v1/notices/boss-controls';
  static const legacyNoticeRules = '/api/notices/rules';
  static const legacyNoticeRuleOrder = '/api/notices/rule-order';
  static String legacyNoticeRule(int id) => '/api/notices/rules/$id';
  static const legacyNoticePriceGuides = '/api/notices/price-guides';
  static String legacyNoticePriceGuide(int id) =>
      '/api/notices/price-guides/$id';
  static const legacyNoticeBossControls = '/api/notices/boss-controls';
  static const collections = '/api/v1/collections';
  static String collection(int id) => '/api/v1/collections/$id';
  static const collectionCompletions = '/api/v1/collection-completions';
  static const collectionExclusions = '/api/v1/collection-exclusions';
  static const toggleCollectionExclusion =
      '/api/v1/collection-exclusions/toggle';
  static const legacyCollections = '/api/v2/collections';
  static String legacyCollection(int id) => '/api/v2/collections/$id';
  static const legacyUserCollections = '/api/v2/user-collections';
  static const legacyToggleUserCollection = '/api/v2/user-collections/toggle';
  static const legacyExcludedMembers = '/api/excluded-members';
  static const legacyToggleExcludedMember = '/api/excluded-members/toggle';
  static const contentGroups = '/api/v1/content-groups';
  static String contentGroup(int id) => '/api/v1/content-groups/$id';
  static String contentGroupMembers(int id) =>
      '/api/v1/content-groups/$id/members';
  static const legacyGroups = '/api/groups';
  static String legacyGroup(int id) => '/api/groups/$id';
  static String legacyGroupMembers(int id) => '/api/groups/$id/members';
  static const siege = '/api/v1/siege';
  static const siegeMe = '/api/v1/siege/me';
  static String siegeMember(int id) => '/api/v1/siege/members/$id';
  static const siegeAll = '/api/v1/siege';
  static const legacySiege = '/api/siege';
  static const legacySiegeMe = '/api/siege/me';
  static const legacySiegeAll = '/api/siege/all';
  static String legacyAdminSiege(int id) => '/api/admin/siege/$id';
  static const supportRequests = '/api/v1/support-requests';
  static String supportRequest(int id) => '/api/v1/support-requests/$id';
  static String supportRequestStatus(int id) =>
      '/api/v1/support-requests/$id/status';
  static String supportApplications(int requestId) =>
      '/api/v1/support-requests/$requestId/applications';
  static String supportApplication(int requestId, int applicationId) =>
      '/api/v1/support-requests/$requestId/applications/$applicationId';
  static String selectSupportApplication(int requestId, int applicationId) =>
      '/api/v1/support-requests/$requestId/select/$applicationId';
  static const legacySupportRequests = '/api/support-requests';
  static String legacySupportRequest(int id) => '/api/support-requests/$id';
  static String legacySupportRequestStatus(int id) =>
      '/api/support-requests/$id/status';
  static String legacySupportApplications(int requestId) =>
      '/api/support-requests/$requestId/applications';
  static String legacySupportApplication(int requestId, int applicationId) =>
      '/api/support-requests/$requestId/applications/$applicationId';
  static String legacySelectSupportApplication(
    int requestId,
    int applicationId,
  ) => '/api/support-requests/$requestId/select/$applicationId';
}

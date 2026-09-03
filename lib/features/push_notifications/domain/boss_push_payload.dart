import 'dart:convert';

class BossPushPayload {
  const BossPushPayload({
    required this.notificationKey,
    required this.guildId,
    required this.scheduleId,
    required this.bossDefinitionId,
    required this.bossType,
    required this.region,
    required this.boss,
    required this.spawnTime,
    required this.leadSeconds,
  });

  static const type = 'BOSS_SCHEDULE';
  static const supportedLeadSeconds = <int>{300, 60, 0};

  final String notificationKey;
  final int? guildId;
  final int? scheduleId;
  final int bossDefinitionId;
  final String bossType;
  final String region;
  final String boss;
  final int spawnTime;
  final int leadSeconds;

  String get occurrenceKey => '$bossDefinitionId:$spawnTime:$leadSeconds';

  String get scheduleLocation => Uri(
    path: '/schedule',
    queryParameters: <String, String>{
      'bossDefinitionId': '$bossDefinitionId',
      'spawnTime': '$spawnTime',
    },
  ).toString();

  Map<String, String> toData() => <String, String>{
    'type': type,
    'notificationKey': notificationKey,
    'guildId': guildId?.toString() ?? '',
    'scheduleId': scheduleId?.toString() ?? '',
    'bossDefinitionId': '$bossDefinitionId',
    'bossType': bossType,
    'region': region,
    'boss': boss,
    'spawnTime': '$spawnTime',
    'leadSeconds': '$leadSeconds',
  };

  String toJsonPayload() => jsonEncode(toData());

  static BossPushPayload? tryParse(Map<String, dynamic> data) {
    if (data['type']?.toString() != type) return null;
    final notificationKey = data['notificationKey']?.toString().trim() ?? '';
    final bossDefinitionId = int.tryParse(
      data['bossDefinitionId']?.toString() ?? '',
    );
    final spawnTime = int.tryParse(data['spawnTime']?.toString() ?? '');
    final leadSeconds = int.tryParse(data['leadSeconds']?.toString() ?? '');
    if (notificationKey.isEmpty ||
        bossDefinitionId == null ||
        bossDefinitionId <= 0 ||
        spawnTime == null ||
        spawnTime <= 0 ||
        leadSeconds == null ||
        !supportedLeadSeconds.contains(leadSeconds)) {
      return null;
    }

    return BossPushPayload(
      notificationKey: notificationKey,
      guildId: _optionalPositiveInt(data['guildId']),
      scheduleId: _optionalPositiveInt(data['scheduleId']),
      bossDefinitionId: bossDefinitionId,
      bossType: data['bossType']?.toString() ?? '',
      region: data['region']?.toString() ?? '',
      boss: data['boss']?.toString() ?? '',
      spawnTime: spawnTime,
      leadSeconds: leadSeconds,
    );
  }

  static BossPushPayload? tryParseJson(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded case final Map<String, dynamic> data) {
        return tryParse(data);
      }
    } catch (_) {
      // Invalid notification payloads are ignored without exposing their data.
    }
    return null;
  }

  static int? _optionalPositiveInt(Object? value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

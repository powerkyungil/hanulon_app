import 'package:flutter_riverpod/legacy.dart';

import '../../auth/domain/session.dart';

/// 일반 회원의 대리 대상은 서버 위임 설정이 아니라 화면의 임시 상태로만 유지한다.
final selectedCharacterKeyProvider = StateProvider<String?>((ref) => null);

/// 일정 화면의 기존 이름 기반 참여 목록에서 선택 캐릭터를 표시하기 위한
/// 화면 전용 메타데이터다. 서버 위임 상태로 저장하지 않는다.
final selectedCharacterNameProvider = StateProvider<String?>((ref) => null);

String? requestedCharacterKey(Session? session, String? selectedKey) {
  if (session?.isDeputy == true) return session?.activeCharacterKey;
  return selectedKey;
}

String? displayCharacterKey(Session? session, String? selectedKey) {
  final requested = requestedCharacterKey(session, selectedKey);
  if (requested != null && requested.isNotEmpty) return requested;
  final userId = session?.userId;
  return userId == null || userId <= 0 ? null : 'MAIN:$userId';
}

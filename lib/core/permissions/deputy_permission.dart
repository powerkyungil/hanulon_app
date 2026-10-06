import '../network/api_exception.dart';

const deputyFeatureForbiddenCode = 'DEPUTY_FEATURE_FORBIDDEN';
const deputyCharacterRequiredCode = 'DEPUTY_CHARACTER_REQUIRED';

bool isDeputyFeatureForbidden(Object error) {
  return error is ApiException && error.code == deputyFeatureForbiddenCode;
}

bool isDeputyCharacterRequired(Object error) {
  return error is ApiException && error.code == deputyCharacterRequiredCode;
}

String deputyPermissionMessage(Object error) {
  if (isDeputyCharacterRequired(error)) {
    return '기능을 이용하려면 먼저 사용할 캐릭터를 선택해 주세요.';
  }
  if (isDeputyFeatureForbidden(error)) {
    return '부주 계정에는 이 기능을 사용할 권한이 없습니다.';
  }
  return error is ApiException ? error.message : '요청을 처리하지 못했습니다.';
}

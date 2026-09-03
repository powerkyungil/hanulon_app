# Odin Guild App 백엔드 REST API 개발문서

> 상태: 구현 연동 기준 초안  
> 기준일: 2026-08-12  
> 기준 클라이언트: odin_guild_app Flutter 앱

## 1. 문서 목적과 적용 범위

이 문서는 현재 Flutter 앱이 실제로 호출하는 REST API 계약을 백엔드 구현 기준으로 정리한 문서다. 현재 저장소에는 백엔드 서버 코드가 없으므로, 다음 소스를 정본으로 삼았다.

- lib/core/config/api_paths.dart
- lib/features/**/data/*_repository.dart
- test/features/**/data/*_repository_test.dart
- docs/flutter-frontend-architecture.md의 역할·도메인 정책

인증 API는 `/api/v1/auth`를 현재 계약으로 사용한다. 나머지 `/api/...` 경로는 새 백엔드의 호환 route이며, 신규 endpoint는 `/api/v1` 아래에 추가한다.

이 문서의 **현재 사용** 표시는 현재 Flutter 앱이 직접 호출하는 계약을 뜻한다. 실제 서버에 아직 구현되지 않은 항목은 **백로그**로 분리한다.

## 2. 공통 프로토콜

### 2.1 기본 설정

| 항목 | 계약 |
| --- | --- |
| Base URL | Flutter 실행 시 API_BASE_URL로 주입. 예: https://api.example.com |
| Path | 인증은 /api/v1/auth/..., 나머지 기존 기능은 /api/... compatibility route |
| 문자 인코딩 | UTF-8 |
| JSON 요청 | Content-Type: application/json |
| JSON 응답 | Content-Type: application/json |
| Accept | Accept: application/json |
| 인증 | Authorization: Bearer <accessToken> |
| 타임아웃 | 연결 10초, 송신·수신 20초 |
| 길드 식별 | 요청 body의 guildId가 아니라 JWT의 길드 소속으로 결정 |
| 기준 시간대 | Asia/Seoul |

로그인·회원가입을 제외한 회원용 API에는 access token을 요구한다. /api/time은 공개 조회로 허용해도 되지만, 현재 클라이언트는 토큰이 있으면 이 요청에도 Bearer 헤더를 붙인다.

### 2.2 식별자와 시간

- DB 식별자는 정수 id를 사용한다.
- 보스 출현 시각과 서버 시각은 Unix epoch milliseconds 정수로 주고받는다.
  - spawnTime
  - currentSpawnTime
  - serverTime
- 생성·수정 일시는 ISO 8601 문자열을 권장한다. 현재 클라이언트는 일부 legacy 응답의 yyyy-MM-dd HH:mm:ss도 읽는다.
- epoch milliseconds는 절대 시각이지만, 입력 UI의 날짜·시간 해석은 Asia/Seoul 기준으로 한다.
- 보스 투표의 논리 키는 현재 클라이언트에서 다음 형식으로 조합한다.

~~~text
{type}|{region}|{boss}|{spawnTime}
~~~

voteKey는 URL path에 들어가므로 서버는 path decoding을 적용해야 한다.

### 2.3 성공 응답

클라이언트는 endpoint별 응답 형태를 디코딩한다. v1 인증 API는 `data` envelope를 사용하고, legacy 호환 route는 원본 형태를 유지한다.

- v1 인증: `{ "data": ... }` 형태로 반환한다.
- legacy 조회 목록: 별도 data wrapper 없이 JSON 배열을 반환한다.
- 객체 조회: endpoint별 객체를 반환한다.
- 저장·수정·삭제: body가 필요 없는 경우 204 No Content 또는 빈 200 OK를 반환한다.
- 생성: 201 Created를 우선하며, 클라이언트가 결과 객체를 사용하는 endpoint는 객체를 반환한다.
- 클라이언트가 응답 body를 사용하지 않는 mutation은 success 필드를 추가해도 되지만 필수로 만들지 않는다.

### 2.4 오류 응답

모든 오류는 다음 형식을 권장한다.

~~~json
{
  "code": "VALIDATION_ERROR",
  "message": "전투력은 0 이상이어야 합니다.",
  "details": {
    "field": "combat_power"
  }
}
~~~

현재 Flutter 클라이언트는 message 또는 error 문자열과 code를 읽는다. message는 사용자에게 표시 가능한 한국어 메시지로 제공한다.

| 상태 코드 | 의미 | 클라이언트 처리 |
| --- | --- | --- |
| 400 | JSON 형식·필수 필드·값 형식 오류 | 입력 오류 |
| 401 | 토큰 누락·만료·위조 | 토큰 삭제 후 로그인 화면 |
| 403 | 역할 또는 길드 권한 부족 | 권한 없음 안내 |
| 404 | 리소스 없음 | 대상 없음 안내 |
| 409 | 중복·상태 충돌 | 충돌 안내 후 재조회 |
| 422 | 도메인 유효성 오류 | 입력 오류 |
| 429 | 로그인·OCR 등 호출 제한 | 재시도 지연 안내 |
| 500 이상 | 서버 내부 오류 | 서버 오류 안내 |

비밀번호, access token, OCR secret, Discord token은 오류 body·로그·analytics에 남기지 않는다.

## 3. 인증·역할·길드 권한

### 3.1 역할 값

| API 값 | 표시명 | 설명 |
| --- | --- | --- |
| MASTER | 길드장 | 길드의 최상위 운영 권한 |
| ADMIN | 운영진 | 운영 기능 관리 권한 |
| MEMBER | 길드원 | 일반 조회·본인 상태 권한 |

역할은 JWT와 서버 DB를 기준으로 판단한다. 화면에서 버튼을 숨기는 것은 보안 경계가 아니며 모든 mutation에서 서버가 다시 검사해야 한다.

### 3.2 권한 요약

| 영역 | MASTER | ADMIN | MEMBER |
| --- | --- | --- | --- |
| 일정·참여 조회 | O | O | O |
| 일정 등록·컷·멍·삭제·보스 정의 | O | O | X |
| 투표 조회·본인 참여 | O | O | O |
| 수동 투표 등록 | O | O | X |
| 공지 조회 | O | O | O |
| 공지 CRUD·보스 통제 | O | O | X |
| 손지원 조회·요청·신청 | O | O | O |
| 손지원 전체 관리 | O | O | 요청자 본인 범위 |
| 컬렉션 조회·본인 체크 | O | O | O |
| 컬렉션 정의 CRUD·제외 관리 | O | O | X |
| 콘텐츠 그룹 조회 | O | O | O |
| 콘텐츠 그룹·배치 관리 | O | O | X |
| 공성전 조회·본인 입력 | O | O | O |
| 공성전 타인 수정·전체 초기화 | O | O | X |
| 길드원 역할 변경·강퇴·위임 | O | X | X |
| 길드원 비밀번호 초기화 | O | O | X |
| 길드 설정·가입 코드 | O | X | X |

모든 데이터 조회·수정은 JWT의 guild_id 범위로 제한한다. 다른 길드의 정수 ID를 body에 넣어 요청해도 접근할 수 없어야 한다.

## 4. API 목록

아래 목록은 현재 Flutter 앱이 직접 사용하는 endpoint다. 인증은 Bearer token 필요 여부이며, 역할은 최소 권한이다.

| 영역 | Method | Path | 인증 | 역할 |
| --- | --- | --- | --- | --- |
| 인증 | POST | /api/v1/auth/login | 아니오 | - |
| 인증 | POST | /api/v1/auth/register | 아니오 | - |
| 사용자 | GET | /api/users/me | 예 | MEMBER |
| 사용자 | PUT | /api/users/me | 예 | MEMBER |
| 사용자 | DELETE | /api/users/me | 예 | MEMBER |
| 사용자 | GET | /api/users | 예 | MEMBER |
| 사용자 관리 | PUT | /api/admin/users/:id/role | 예 | MASTER |
| 사용자 관리 | PUT | /api/admin/guild/master | 예 | MASTER |
| 사용자 관리 | PUT | /api/admin/users/:id/reset-password | 예 | MASTER/ADMIN |
| 사용자 관리 | DELETE | /api/admin/users/:id | 예 | MASTER |
| 공통 | GET | /api/time | 선택 | - |
| 길드 설정 | GET/POST | /api/settings | 예 | 조회: MEMBER / 저장: MASTER |
| 가입 코드 | GET/POST | /api/invites | 예 | MASTER |
| 일정 | GET/POST | /api/schedules | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 일정 | POST | /api/schedules/cut | 예 | MASTER/ADMIN |
| 일정 | POST | /api/schedules/mung | 예 | MASTER/ADMIN |
| 일정 | DELETE | /api/schedules/:id | 예 | MASTER/ADMIN |
| 일정 | DELETE | /api/schedules-all | 예 | MASTER/ADMIN |
| 보스 정의 | GET/POST | /api/custom-bosses | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 보스 정의 | DELETE | /api/custom-bosses/:id | 예 | MASTER/ADMIN |
| 보스 정의 | POST | /api/custom-bosses/reorder | 예 | MASTER/ADMIN |
| 보스 정의 | POST | /api/admin/reset-bosses | 예 | MASTER/ADMIN |
| 일정 참여 | GET/PUT | /api/v1/participation-targets | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 일정 참여 | GET | /api/participants | 예 | MEMBER |
| 일정 참여 | GET | /api/participation-states | 예 | MEMBER |
| 일정 참여 | POST | /api/participants/:boss | 예 | MEMBER |
| OCR | GET | /api/ocr/templates | 예 | MEMBER |
| OCR | POST | /api/ocr/boss-schedule | 예 | MEMBER |
| 보스 투표 | GET | /api/vote-bosses | 예 | MEMBER |
| 보스 투표 | POST | /api/vote-bosses/manual | 예 | MASTER/ADMIN |
| 보스 투표 | POST | /api/vote-participants/:voteKey | 예 | MEMBER |
| 공지 | GET/POST | /api/notices/rules | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 공지 | PUT/DELETE | /api/notices/rules/:id | 예 | MASTER/ADMIN |
| 공지 | PUT | /api/notices/rule-order | 예 | MASTER/ADMIN |
| 가격표 | GET/POST | /api/notices/price-guides | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 가격표 | PUT/DELETE | /api/notices/price-guides/:id | 예 | MASTER/ADMIN |
| 보스 통제 | GET/PUT | /api/notices/boss-controls | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 컬렉션 | GET/POST | /api/v2/collections | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 컬렉션 | PUT/DELETE | /api/v2/collections/:id | 예 | MASTER/ADMIN |
| 컬렉션 상태 | GET | /api/v2/user-collections | 예 | MEMBER |
| 컬렉션 상태 | POST | /api/v2/user-collections/toggle | 예 | 본인 또는 MASTER |
| 컬렉션 우선순위 | GET | /api/excluded-members | 예 | MEMBER |
| 컬렉션 우선순위 | POST | /api/excluded-members/toggle | 예 | MASTER/ADMIN |
| 콘텐츠 그룹 | GET/POST | /api/groups | 예 | 조회: MEMBER / 저장: MASTER/ADMIN |
| 콘텐츠 그룹 | PUT/DELETE | /api/groups/:id | 예 | MASTER/ADMIN |
| 콘텐츠 그룹 | POST | /api/groups/:id/members | 예 | MASTER/ADMIN |
| 공성전 | GET | /api/siege | 예 | MEMBER |
| 공성전 | PUT | /api/siege/me | 예 | MEMBER |
| 공성전 | PUT | /api/admin/siege/:id | 예 | MASTER/ADMIN |
| 공성전 | DELETE | /api/siege/all | 예 | MASTER/ADMIN |
| 손지원 | GET/POST | /api/support-requests | 예 | MEMBER |
| 손지원 | PUT | /api/support-requests/:id/status | 예 | 요청자 또는 MASTER/ADMIN |
| 손지원 | DELETE | /api/support-requests/:id | 예 | 요청자 또는 MASTER/ADMIN |
| 손지원 | POST | /api/support-requests/:id/applications | 예 | MEMBER |
| 손지원 | DELETE | /api/support-requests/:id/applications/:applicationId | 예 | 신청자 또는 MASTER/ADMIN |
| 손지원 | POST | /api/support-requests/:id/select/:applicationId | 예 | 요청자 또는 MASTER/ADMIN |

## 5. 인증·사용자 API

### 5.1 로그인

POST /api/v1/auth/login

요청:

~~~json
{
  "username": "freya",
  "password": "password"
}
~~~

성공 200:

~~~json
{
  "data": {
    "token": "<jwt>",
    "userId": 7,
    "username": "freya",
    "nickname": "프레이야",
    "role": "MASTER"
  }
}
~~~

token, userId, username은 필수다. 토큰 만료 정책은 현재 refresh API가 없으므로 access token 만료 시 재로그인 방식으로 운영한다. 기본 만료 시간은 백엔드에서 확정하되, 현재 프론트 설계는 7일을 전제로 한다.

### 5.2 회원가입

POST /api/v1/auth/register

기존 길드 가입:

~~~json
{
  "mode": "JOIN_GUILD",
  "code": "ODIN-7K4P",
  "username": "thor",
  "password": "password",
  "nickname": "토르",
  "occupation": "워리어",
  "main_class": "디펜더",
  "combat_power": 130000,
  "equipment": {
    "무기": {"val": "발뭉 7강", "color": "legend"}
  },
  "skills": {
    "active": {"영웅 1": "8강"},
    "passive": {"전설 1": "X"}
  }
}
~~~

새 길드 생성:

~~~json
{
  "mode": "CREATE_GUILD",
  "guild_name": "오딘 길드",
  "username": "freya",
  "password": "password",
  "nickname": "프레이야",
  "occupation": "소서리스",
  "main_class": "아크 메이지",
  "combat_power": 150000,
  "equipment": {},
  "skills": {}
}
~~~

JOIN_GUILD는 code가 필수이며 가입 코드에 연결된 역할로 가입한다. CREATE_GUILD는 guild_name이 필수이고 계정·길드 생성·MASTER 지정이 하나의 transaction이어야 한다. 성공 시 201로 다음 형식을 반환한다.

~~~json
{
  "data": {
    "userId": 7,
    "guildId": 1,
    "role": "MASTER"
  }
}
~~~

기본 검증:

- mode: JOIN_GUILD 또는 CREATE_GUILD
- password: 최소 6자
- guild_name: 최대 40자
- 가입 코드: 영문·숫자·_·-, 최대 32자
- combat_power: 정수
- occupation과 main_class: 허용된 조합
- nickname, username: 공백·중복 정책을 서버에서 최종 검증

### 5.3 내 정보

GET /api/users/me

응답:

~~~json
{
  "id": 7,
  "username": "freya",
  "role": "MASTER",
  "nickname": "프레이야",
  "occupation": "소서리스",
  "main_class": "아크 메이지",
  "combat_power": 150000,
  "equipment": {},
  "skills": {},
  "max_crit_rate": 52.3,
  "max_crit_resist": 41.2,
  "status_effect_acc": 18.0,
  "alternate_characters": []
}
~~~

PUT /api/users/me는 다음 필드를 받는다.

| 필드 | 타입 | 필수 | 비고 |
| --- | --- | --- | --- |
| nickname | string | 예 | 공백 불가 |
| occupation | string | 예 | 직업 |
| main_class | string | 예 | 직업과 조합 검증 |
| combat_power | integer | 예 | 길드 설정이 잠겨 있으면 기존 값 유지 또는 403 |
| equipment | object | 예 | 장비 부위별 {val,color} |
| skills | object | 예 | active, passive 맵 |
| max_crit_rate | number | 예 | 소수점 보존 |
| max_crit_resist | number | 예 | 소수점 보존 |
| status_effect_acc | number | 예 | 소수점 보존 |
| alternate_characters | array | 예 | 최대 1개 권장 |
| password | string | 아니오 | 값이 있을 때만 변경, 최소 6자 |

응답 body는 사용하지 않으므로 204를 반환해도 된다. 저장 후 클라이언트는 다시 GET /api/users/me를 호출한다.

### 회원 탈퇴

`DELETE /api/users/me`는 로그인한 사용자의 현재 비밀번호를 받아 본인 여부를 다시 확인한다.

```json
{
  "password": "current-password"
}
```

성공하면 계정과 해당 사용자의 개인 캐릭터·활동 데이터를 하나의 transaction에서 하드 삭제하고 `204 No Content`를 반환한다. 다른 길드원의 데이터와 공유 길드 데이터는 삭제하지 않는다. 다른 길드원이 있는 MASTER 계정은 삭제하지 않고 역할 이전을 요구하는 `409 Conflict` 오류를 반환한다. MASTER가 길드의 유일한 회원이면 계정과 길드 종속 데이터를 같은 transaction에서 하드 삭제한다. 성공 후 기존 access token으로 보호 API를 호출할 수 없어야 한다.

### 5.4 길드원 조회·관리

GET /api/users는 현재 길드의 길드원 배열을 반환한다. 각 항목은 GET /api/users/me의 캐릭터 필드와 같은 구조를 사용한다. 목록 화면에서 장비·스킬 비교를 수행하므로 equipment, skills, alternate_characters를 생략하지 않는다.

관리 mutation:

| Endpoint | 요청 body | 성공 | 규칙 |
| --- | --- | --- | --- |
| PUT /api/admin/users/:id/role | {"role":"MEMBER"} 또는 {"role":"ADMIN"} | 204 | MASTER만, 대상 MASTER 변경 금지 |
| PUT /api/admin/guild/master | {"target_user_id":8} | 204 | MASTER만, 같은 길드의 MEMBER/ADMIN 대상 |
| PUT /api/admin/users/:id/reset-password | 없음 | 204 | MASTER/ADMIN, 대상과 기존 정책 검증 |
| DELETE /api/admin/users/:id | 없음 | 204 | MASTER만, 현재 MASTER 삭제 금지 |

MASTER 위임은 기존 MASTER를 MEMBER로 변경하고 대상자를 MASTER로 변경하는 작업을 하나의 transaction으로 처리한다. 중간 상태가 외부에 노출되거나 한쪽만 변경되면 안 된다.

## 6. 공통·길드 설정 API

### 6.1 서버 시각

GET /api/time

~~~json
{"serverTime":1786406400000}
~~~

serverTime은 서버의 현재 시각을 epoch milliseconds로 반환한다. 일정 날짜 필터와 카운트다운의 기준이므로 서버 시간과 DB 시간대를 동일하게 유지한다.

### 6.2 길드 설정

GET /api/settings

권장 공개 응답:

~~~json
{
  "guild_name": "오딘 길드",
  "allow_member_combat_power_edit": 1
}
~~~

POST /api/settings

~~~json
{
  "guild_name": "오딘 길드",
  "allow_member_combat_power_edit": 0
}
~~~

현재 legacy 서버는 전체 설정 컬럼 저장을 요구할 수 있어 Flutter가 discord_token, discord_channel_id, discord_enabled를 보존해 함께 보낼 수 있다. 이 필드들은 모바일 공개 계약에 포함하지 않는다. 특히 discord_token은 GET 응답으로 반환하지 말고, 서버 내부 값 유지 또는 별도 관리자 전용 secret 관리 API로 분리한다.

### 6.3 고정 가입 코드

GET /api/invites 응답:

~~~json
{
  "invites": [
    {"inviteCode":"MEMBER-AB12","role":"MEMBER"},
    {"inviteCode":"ADMIN-CD34","role":"ADMIN"}
  ]
}
~~~

POST /api/invites 요청:

~~~json
{
  "targetRole": "MEMBER",
  "customCode": "ODIN-2026"
}
~~~

customCode가 없으면 서버가 충돌하지 않는 코드를 생성한다. 성공 응답:

~~~json
{"inviteCode":"ODIN-2026","role":"MEMBER"}
~~~

코드는 만료되지 않고 여러 번 사용할 수 있다. 같은 역할의 코드를 변경하면 이전 코드는 즉시 폐기한다. MASTER용 가입 코드는 만들지 않는다.

## 7. 보스 일정·보스 정의 API

### 7.1 일정 조회·등록

GET /api/v1/schedules 응답:

~~~json
[
  {
    "id": 101,
    "bossDefinitionId": 12,
    "type": "공통",
    "region": "요툰하임",
    "boss": "파르바",
    "spawnTime": 1786406400000,
    "is_mung": 0,
    "isFixed": false
  }
]
~~~

is_mung은 현재 클라이언트가 0/1 정수로 읽는다. isFixed는 선택 값이며 type이 고정이면 클라이언트가 고정 일정으로 처리한다. bossDefinitionId는 참여 보스 설정과 일정 유형을 정확히 연결하는 필수 보스 정의 ID다.

POST /api/v1/schedules 요청:

~~~json
{
  "schedules": [
    {
      "bossDefinitionId": 12,
      "type": "공통",
      "region": "요툰하임",
      "boss": "파르바",
      "spawnTime": 1786406400000
    }
  ]
}
~~~

일괄 등록은 guild_id, type, region, boss, spawn_time 조합의 중복 정책을 정하고, 재시도 시 동일 일정이 중복 생성되지 않도록 transaction 또는 idempotency 기준을 둔다.

### 7.2 일정 액션

| Endpoint | 요청 body |
| --- | --- |
| POST /api/schedules/cut | {"type":"공통","region":"요툰하임","boss":"파르바"} |
| POST /api/schedules/mung | {"type":"공통","region":"요툰하임","boss":"파르바","currentSpawnTime":1786406400000} |
| DELETE /api/schedules/:id | 없음 |
| DELETE /api/schedules-all | 없음 |

컷·멍은 서버의 보스 정의와 쿨타임을 기준으로 다음 일정을 계산한다. 클라이언트가 보낸 시각을 그대로 신뢰해 잘못된 젠을 만들지 않는다. 고정 일정 자동 생성분은 클라이언트가 보스 정의와 서버 시각으로 계산하므로 DB 저장 대상인지 여부를 백엔드와 확정한다.

### 7.3 사용자 참여 설정과 참여자

GET /api/v1/participation-targets 응답:

~~~json
{
  "data": {
    "bossDefinitionIds": [12, 27]
  }
}
~~~

PUT /api/v1/participation-targets 요청:

~~~json
{"bossDefinitionIds":[12,27]}
~~~

참여 대상은 보스명 문자열이 아니라 guild 범위의 보스 정의 ID로 저장한다. 따라서 동일한 보스명이 본섭·침공 또는 서로 다른 지역에 있어도 각각 독립적으로 참여 여부를 설정할 수 있다. 기존 이름 기반 설정을 이전할 때는 정확히 하나의 보스 정의와 일치하는 이름만 자동 전환하고, 여러 유형에 중복된 이름은 대상에서 제외해 운영진이 다시 선택하게 한다.

GET /api/participants 응답은 일정의 voteKey를 key로 하는 객체다.

~~~json
{
  "공통|요툰하임|파르바|1786406400000": ["프레이야","토르"]
}
~~~

GET /api/participation-states는 참여가 마감된 voteKey 배열이다.

~~~json
["공통|요툰하임|파르바|1786406400000"]
~~~

POST /api/participants/:boss는 :boss를 URL encode한 경로를 사용한다.

~~~text
POST /api/participants/%ED%8C%8C%EB%A5%B4%EB%B0%94
~~~

요청:

~~~json
{
  "type": "공통",
  "region": "요툰하임",
  "spawnTime": 1786406400000
}
~~~

성공 응답:

~~~json
{"joined":true}
~~~

참여 toggle은 guild_id, vote_key, user_id 조합의 unique key로 중복을 막고, 마감된 key에는 409 또는 403을 반환한다.

### 7.4 보스 정의 관리

GET /api/custom-bosses 응답:

~~~json
[
  {
    "id": 1,
    "type": "공통",
    "region": "요툰하임",
    "boss": "파르바",
    "cooldown": 4.0,
    "timeStr": null,
    "days": "월,수,금",
    "color": "#4F6EF7",
    "sort_order": 0
  }
]
~~~

POST /api/custom-bosses 요청:

~~~json
{
  "type":"고정",
  "region":"요툰하임",
  "boss":"파르바",
  "cooldown":4.0,
  "timeStr":"21:00",
  "days":"월,수,금",
  "color":"#4F6EF7"
}
~~~

추가 endpoint:

| Endpoint | 요청 |
| --- | --- |
| DELETE /api/custom-bosses/:id | 없음 |
| POST /api/custom-bosses/reorder | {"orderList":[{"boss":"파르바","sort_order":0}]} |
| POST /api/admin/reset-bosses | 없음 |

정렬 저장은 가능하면 boss 문자열 대신 정의 ID를 사용하도록 차기 버전에서 개선한다. 현재 클라이언트는 boss 문자열을 보낸다.

## 8. OCR API

### 8.1 템플릿 조회

GET /api/ocr/templates

~~~json
{
  "templates": [
    {"id":1,"name":"기본 일정표"}
  ]
}
~~~

### 8.2 스크린샷 분석

POST /api/ocr/boss-schedule

- body: multipart가 아닌 이미지 raw bytes
- Content-Type: 실제 이미지 타입 (image/jpeg, image/png 등)
- header: X-OCR-TEMPLATE-ID: 1
- 권장 최대 파일 크기: 5MB

응답:

~~~json
{
  "images": [
    {
      "fields": [
        {"name":"boss","inferText":"파르바"},
        {"name":"spawn_time","inferText":"21:00"}
      ]
    }
  ]
}
~~~

현재 앱은 OCR 결과를 자동으로 일정에 저장하지 않는다. OCR provider secret·템플릿 호출 URL·API key는 백엔드 환경변수에만 둔다. 지원하지 않는 이미지, 용량 초과, OCR provider timeout은 서로 다른 code로 반환한다.

## 9. 보스 참여 투표 API

### 9.1 투표 목록

GET /api/vote-bosses 응답:

~~~json
[
  {
    "id": 20,
    "voteKey": "공통|요툰하임|파르바|1786406400000",
    "type": "공통",
    "region": "요툰하임",
    "boss": "파르바",
    "spawnTime": 1786406400000,
    "participants": [
      {"userId":7,"nickname":"프레이야"}
    ],
    "joined": true,
    "isClosed": false,
    "isBlessed": false,
    "isManual": false,
    "isHistory": false
  }
]
~~~

현재 앱은 응답 배열을 출현 시각 오름차순으로 정렬한다. 서버는 현재 로그인 사용자의 joined를 계산해 반환한다.

### 9.2 수동 투표 등록

POST /api/vote-bosses/manual — MASTER/ADMIN

~~~json
{
  "boss": "파르바",
  "spawnTime": 1786406400000,
  "type": "공통",
  "region": "요툰하임",
  "isBlessed": true
}
~~~

spawnTime은 서울 UI에서 입력한 시각을 epoch milliseconds로 변환한 값이다. guild_id와 voteKey의 중복을 막는다.

### 9.3 투표 참여 toggle

POST /api/vote-participants/:voteKey

~~~json
{
  "boss": "파르바",
  "spawnTime": 1786406400000
}
~~~

응답:

~~~json
{"joined":true}
~~~

마감된 투표에는 참여할 수 없다. 참여 row는 guild_id, vote_id, user_id 조합의 unique key로 보호하고 toggle 연산은 transaction으로 처리한다.

## 10. 공지·가격표·보스 통제 API

### 10.1 길드룰·가격표

길드룰과 가격표의 응답 item:

~~~json
{
  "id": 1,
  "title": "길드 운영 내규",
  "content": "길드 내규 > 참여 > 미리 알려 주세요.",
  "color": "#F2B705",
  "sort_order": 0,
  "updated_at": "2026-08-11T01:00:00.000Z"
}
~~~

| Endpoint | 요청 |
| --- | --- |
| GET /api/notices/rules | 없음, 배열 반환 |
| POST /api/notices/rules | {"title":"...","content":"...","color":"#F2B705"} |
| PUT /api/notices/rules/:id | 같은 body |
| DELETE /api/notices/rules/:id | 없음 |
| GET /api/notices/price-guides | 없음, 배열 반환 |
| POST /api/notices/price-guides | 같은 body |
| PUT /api/notices/price-guides/:id | 같은 body |
| DELETE /api/notices/price-guides/:id | 없음 |
| PUT /api/notices/rule-order | {"ids":[3,1,2]} |

content는 현재 앱이 섹션 > 항목 > 값 줄 형식으로 저장하는 legacy 문자열이다. >와 줄바꿈 escape 규칙을 변경하지 않는다. 차기 버전에서는 구조화된 sections 배열로 마이그레이션할 수 있다.

### 10.2 보스 통제

GET /api/notices/boss-controls 응답:

~~~json
{
  "chapters": [
    {
      "chapter": "요툰하임",
      "bosses": [
        {"name":"파르바","status":"CONTROL"}
      ]
    }
  ]
}
~~~

PUT /api/notices/boss-controls:

~~~json
{
  "chapter": "요툰하임",
  "boss": "파르바",
  "status": "ALLY_ONLY"
}
~~~

status 허용 값은 NONE, ALLY_ONLY, CONTROL이다. 통제 상태 변경과 조회가 동시에 발생할 수 있으므로 저장 성공 후 최신 전체 상태를 조회한다.

## 11. 컬렉션 API V2

### 11.1 컬렉션 정의

GET /api/v2/collections 응답:

~~~json
[
  {
    "id": 1,
    "name": "전설 방어구",
    "items": [
      {"id":10,"part":"발키리 갑옷","enchantment":"강화 7"}
    ]
  }
]
~~~

POST /api/v2/collections 및 PUT /api/v2/collections/:id 요청:

~~~json
{
  "name": "전설 방어구",
  "items": [
    {"id":10,"part":"발키리 갑옷","enchantment":"강화 7"},
    {"part":"발키리 투구","enchantment":"강화 5"}
  ]
}
~~~

기존 item의 id를 유지해야 이름·강화·정렬을 수정해도 달성 상태가 다른 item으로 이동하지 않는다. 컬렉션 삭제 시 연결된 item과 상태의 cascade 정책을 명시한다.

### 11.2 달성 상태

GET /api/v2/user-collections 응답:

~~~json
[
  {"user_id":1,"collection_item_id":10}
]
~~~

POST /api/v2/user-collections/toggle:

~~~json
{
  "userId": 7,
  "collectionItemId": 10,
  "completed": true
}
~~~

현재 클라이언트는 본인 또는 MASTER만 다른 사용자 상태를 변경할 수 있다고 가정한다. 서버는 요청자의 JWT user id와 userId를 비교해 이 권한을 강제한다.

### 11.3 우선순위 제외

GET /api/excluded-members 응답:

~~~json
[2,9]
~~~

POST /api/excluded-members/toggle:

~~~json
{"userId":2}
~~~

응답:

~~~json
{"status":"added"}
~~~

status는 added 또는 removed다. 제외 대상은 같은 길드의 활성 회원만 허용한다.

## 12. 콘텐츠 그룹 API

GET /api/groups 응답:

~~~json
[
  {"id":1,"name":"1군 레이드","memberIds":[7,8]},
  {"id":2,"name":"2군 레이드","memberIds":[]}
]
~~~

현재 repository는 memberIds와 member_ids, 배열과 comma-separated 문자열을 모두 읽지만, 신규 서버 응답은 memberIds 배열을 정본으로 사용한다.

| Endpoint | 요청·응답 |
| --- | --- |
| POST /api/groups | 요청 {"name":"발할라"}, 응답 {"id":3,"name":"발할라","memberIds":[]} |
| PUT /api/groups/:id | 요청 {"name":"발할라 1군"}, 성공 204 |
| DELETE /api/groups/:id | 성공 204, 배치 회원은 미편성으로 이동 |
| POST /api/groups/:id/members | 요청 {"userIds":[7,8,9]}, 성공 204 |

한 회원이 동시에 여러 그룹에 배치되지 않도록 저장 transaction에서 검증한다. 모바일은 이동 시 원본·대상 그룹을 각각 저장하므로 부분 실패에 대비해 보상 요청과 재조회가 가능해야 한다.

## 13. 공성전 API

GET /api/siege 응답:

~~~json
[
  {
    "id":7,
    "nickname":"프레이야",
    "main_class":"아크 메이지",
    "combat_power":150000,
    "current_diamonds":80000,
    "remaining_diamonds":35000,
    "updated_at":"2026-08-11T02:30:00.000Z"
  }
]
~~~

입력 body:

~~~json
{
  "current_diamonds": 80000,
  "remaining_diamonds": 35000
}
~~~

| Endpoint | 권한 | 설명 |
| --- | --- | --- |
| GET /api/siege | MEMBER | 현재 길드 전체 현황 |
| PUT /api/siege/me | MEMBER | JWT 사용자 본인 기록 |
| PUT /api/admin/siege/:id | MASTER/ADMIN | 특정 회원 기록 |
| DELETE /api/siege/all | MASTER/ADMIN | 전체 기록 초기화 |

검증 규칙:

- 두 값은 정수이며 0 이상 999,999,999 이하
- remaining_diamonds <= current_diamonds
- 사용 다이아는 current_diamonds - remaining_diamonds
- 전체 초기화는 destructive action이므로 audit log를 남긴다.

## 14. 손지원 API

### 14.1 요청 목록 모델

GET /api/support-requests는 배열을 반환한다.

~~~json
[
  {
    "id":1,
    "requesterId":7,
    "requestedTime":"2026-08-12 20:00~21:00",
    "memo":"장비 세팅 도움",
    "status":"MATCHED",
    "selectedApplicationId":10,
    "createdAt":"2026-08-11T09:00:00.000Z",
    "updatedAt":"2026-08-11T09:30:00.000Z",
    "nickname":"프레이야",
    "occupation":"소서리스",
    "mainClass":"아크 메이지",
    "combatPower":142530,
    "applications":[
      {
        "id":10,
        "requestId":1,
        "applicantId":8,
        "memo":"가능합니다.",
        "status":"SELECTED",
        "createdAt":"2026-08-11T09:20:00.000Z",
        "nickname":"토르",
        "occupation":"워리어",
        "mainClass":"디펜더",
        "combatPower":137420
      }
    ]
  }
]
~~~

현재 repository는 requester_id, requested_time, created_at 같은 snake_case 응답도 읽지만, 신규 API의 정본은 위 camelCase다.

### 14.2 mutation

| Endpoint | 요청 |
| --- | --- |
| POST /api/support-requests | {"requestedTime":"2026-08-12 종일","memo":"세팅 지원"} |
| PUT /api/support-requests/:id/status | {"status":"DONE"} |
| DELETE /api/support-requests/:id | 없음 |
| POST /api/support-requests/:id/applications | {"memo":"가능합니다."} |
| DELETE /api/support-requests/:id/applications/:applicationId | 없음 |
| POST /api/support-requests/:id/select/:applicationId | 없음 |

허용 상태는 OPEN, MATCHED, DONE, CANCELED다. 기본 상태는 OPEN이다.

검증·상태 규칙:

- requestedTime: 최대 80자. 현재 앱은 yyyy-MM-dd 종일 또는 yyyy-MM-dd HH:mm~HH:mm 형식을 전송한다.
- memo: 최대 500자
- 요청자는 자기 요청에 신청할 수 없다.
- OPEN이 아닌 요청에는 신규 신청을 받지 않는다.
- 지원자 선택은 요청자 또는 MASTER/ADMIN만 가능하다.
- 선택 성공 시 selectedApplicationId를 저장하고 요청 상태를 MATCHED로 변경한다.
- 상태 변경·신청·선택 후 목록을 다시 조회해 동시 변경을 반영한다.

## 15. 공통 데이터 규칙과 검증

### 15.1 캐릭터·장비·스킬

현재 앱에서 사용하는 직업과 주클래스 조합:

| 직업 | 주클래스 |
| --- | --- |
| 워리어 | 디펜더, 버서커, 썬더브링어, 프로스트 본 |
| 로그 | 스나이퍼, 어쌔신, 헌트리스 |
| 소서리스 | 아크 메이지, 다크 위저드, 인챈트리스, 알케미스트 |
| 프리스트 | 세인트, 팔라딘, 바드, 새크리파이스 |
| 실드 메이든 | 발키리, 액슬러, 디스트로이어 |

장비 부위는 13개다: 무기, 보조무기, 투구, 갑옷, 장갑, 각반, 신발, 망토, 목걸이, 귀걸이, 팔찌, 반지, 벨트.

장비 등급 값은 none, hero, legend, mythic이며, 예시는 다음과 같다.

~~~json
{"무기":{"val":"발뭉 7강","color":"legend"}}
~~~

스킬 map은 active와 passive로 나누고 이름은 영웅 1~영웅 4, 전설 1~전설 2를 사용한다. 강화 값은 X, 0강~10강이다.

### 15.2 응답 필드명 호환

현재 repository가 읽는 대표적인 legacy alias는 다음과 같다.

| 정본 | legacy alias |
| --- | --- |
| requesterId | requester_id |
| requestedTime | requested_time |
| selectedApplicationId | selected_application_id |
| mainClass | main_class |
| combatPower | combat_power |
| createdAt | created_at |
| updatedAt | updated_at |
| memberIds | member_ids |

신규 endpoint는 정본 필드명만 사용하고, alias는 마이그레이션 기간에만 허용한다.

## 16. 백엔드 구현 시 필수 보안·무결성 정책

1. 모든 query에 JWT의 guild_id 조건을 적용한다. URL의 user id, group id, collection id만으로 다른 길드 데이터에 접근할 수 없어야 한다.
2. 비밀번호는 Argon2id 또는 bcrypt 등 검증된 password hash로 저장하며 평문을 저장하거나 응답하지 않는다.
3. TLS를 사용하고 로그인·가입·OCR·가입 코드 발급 endpoint에 rate limit을 적용한다.
4. MASTER 위임, 회원 강퇴, 전체 일정 초기화, 공성전 전체 초기화, 가입 코드 변경은 audit log를 남긴다.
5. 역할 변경·MASTER 위임·길드 탈퇴/강퇴는 transaction과 대상 상태 검증을 함께 적용한다.
6. 일정·투표·참여·컬렉션 달성 상태에는 길드 범위의 unique constraint를 둔다.
7. 그룹 배치 저장 시 회원이 여러 그룹에 중복 배치되지 않도록 transaction으로 처리한다.
8. 손지원 status transition은 서버가 허용 상태 전이를 검사한다. 클라이언트의 버튼 노출만 믿지 않는다.
9. OCR provider secret과 Discord secret은 앱 응답·앱 설정·로그에 노출하지 않는다.
10. mutation은 네트워크 재시도에 안전해야 한다. 특히 일정 일괄 등록, 참여 toggle, 그룹 저장은 중복 요청과 부분 실패를 처리한다.
11. 현재 목록 API는 pagination을 사용하지 않지만, 길드원이 증가하면 limit, cursor 기반 pagination을 /api/v1에서 도입한다.

## 17. 현재 개발 기준의 미확정·백로그 항목

다음 항목은 기존 설계 문서에는 언급되어 있으나 현재 Flutter의 ApiPaths와 repository에서 직접 호출하지 않는다. 백엔드 1차 구현에 필수로 추가하지 말고, 화면 구현 시 계약을 별도로 확정한다.

- 투표 마감·영구 삭제: POST/DELETE /api/vote-bosses/:voteKey, DELETE /api/vote-bosses/:voteKey/permanent
- 투표 통계·회원별 참여율: GET /api/vote-stats, GET /api/vote-member-rates
- 운영진의 특정 투표 참여자 수동 관리
- 대시보드 집계: GET /api/dashboard
- 가격표 전용 세부 API /api/notices/prices
- refresh token·서버 로그아웃 API
- /api/v1 버전 경로와 OpenAPI 문서 자동 배포

백엔드 착수 전에 다음 정책을 확정한다.

1. 현재 /api/...를 유지할지 /api/v1/...로 시작할지
2. 일정 등록·컷·멍·개별 삭제를 MASTER/ADMIN만 허용할지
3. reset-password 성공 후 임시 비밀번호를 별도 채널로 전달할지
4. /api/settings의 legacy Discord 컬럼을 언제 분리할지
5. 모든 목록 endpoint의 pagination 도입 시점
6. API 응답 날짜 형식을 ISO 8601로 통일할 시점

## 18. 구현 완료 체크리스트

- [ ] 로그인·회원가입·내 정보·역할별 middleware 구현
- [ ] 길드 tenant isolation 및 권한 테스트
- [ ] 서버 시간과 Asia/Seoul 기준 검증
- [ ] 일정·보스 정의·참여·투표 unique constraint 및 transaction 테스트
- [ ] OCR raw image 업로드·5MB 제한·provider timeout 처리
- [ ] 공지·컬렉션·그룹·공성전·손지원 CRUD 및 상태 전이 테스트
- [ ] 오류 응답 {code,message,details} 통일
- [ ] OpenAPI 3.1 또는 Swagger UI 제공
- [ ] Flutter repository fixture와 실제 응답 contract test
- [ ] 설정 secret 비노출 확인
- [ ] destructive mutation audit log 확인
- [ ] 운영·스테이징·개발 Base URL 및 HTTPS 확인

## 부록 A. 클라이언트 연동 순서

1. POST /api/v1/auth/login으로 token을 발급한다.
2. token을 Secure Storage에 저장한다.
3. GET /api/users/me와 GET /api/settings로 bootstrap한다.
4. 일정 화면은 /api/schedules, /api/participation-targets, /api/participants, /api/participation-states, /api/time, /api/custom-bosses를 병렬 조회한다.
5. 공지·컬렉션·그룹·공성전·손지원은 각 목록 조회 후 mutation 성공 시 최신 목록을 다시 조회한다.
6. 401이면 token을 삭제하고 로그인 화면으로 이동한다. 403이면 권한 안내를 표시한다.

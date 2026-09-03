# 한울ON 앱 배포 체크리스트

## 1. 고정 식별자와 버전

- Android application ID: `com.odinguild.odin_guild_app`
- iOS bundle ID: `com.odinguild.odinGuildApp`
- 표시 이름: `한울ON`
- 운영 API 기본 주소: `https://api.hanul-on.cloud`
- 개인정보처리방침: `https://hanulbear.online/privacy`
- 외부 계정 삭제: `https://hanulbear.online/delete-account`

첫 스토어 등록 전에 application ID와 bundle ID를 최종 확정한다. 새 빌드를 업로드할 때마다
`pubspec.yaml`의 build number(`+1`)를 이전 업로드보다 크게 올린다.

## 2. Android 업로드 키

업로드 키는 최초 생성 후 안전한 별도 저장소에 백업한다. 키 파일과 비밀번호를 잃으면 이후
업데이트 배포가 어려워질 수 있다.

```sh
keytool -genkeypair -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

cp android/key.properties.example android/key.properties
```

`android/key.properties`의 `CHANGE_ME` 두 곳을 생성할 때 입력한 비밀번호로 바꾼다.
`android/upload-keystore.jks`와 `android/key.properties`는 Git에서 제외되어 있다.

```sh
flutter build appbundle --release
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

검증 출력의 signer가 `Android Debug`가 아닌 업로드 키 소유자여야 한다.

## 3. iOS 배포 빌드

1. `ios/Runner.xcworkspace`를 Xcode에서 연다.
2. Runner target의 Team과 `com.odinguild.odinGuildApp` App ID를 확인한다.
3. 실제 기기에서 Release 구성으로 로그인, 사진 선택, 알림, 회원 탈퇴를 확인한다.
4. Product > Archive를 실행한다.
5. Organizer에서 Validate App을 통과한 뒤 TestFlight에 먼저 배포한다.
6. Xcode Organizer의 Privacy Report와 App Store Connect 경고를 확인한다.

## 4. 제출 전 자동 검증

```sh
flutter analyze
flutter test
flutter build appbundle --release
flutter build ios --release --no-codesign
```

모든 명령이 성공한 동일한 커밋을 스토어에 제출한다.

## 5. 스토어 콘솔

### Google Play Console

- 개인정보처리방침 URL 등록
- Data safety와 Data deletion 질문 작성
- 외부 계정 삭제 URL 등록
- 알림·사진 선택 및 전송 데이터 공개 내용 확인
- App access에 심사용 계정과 가입 방법 입력
- 콘텐츠 등급, 대상 연령, 광고 여부 작성
- 내부 테스트 트랙에서 실기기 검증 후 프로덕션 제출

### App Store Connect

- Privacy Policy URL과 App Privacy 답변 등록
- 연령 등급, 카테고리, 지원 URL, 저작권 입력
- 심사 메모에 테스트 계정과 길드 가입 방법 입력
- 알림 사용 목적과 OCR용 사진 선택 흐름 설명
- iPhone/iPad 스크린샷 및 설명 등록
- TestFlight 검증 후 App Review 제출

스토어 심사용 계정 비밀번호와 Android 업로드 키 비밀번호는 문서나 Git에 기록하지 않는다.

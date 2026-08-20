# StayTab 릴리스 가이드

이 문서는 릴리스 담당자용입니다. 모든 배포물은 GPL-3.0 대응 소스, Developer ID 서명,
Apple 공증, BetterUpdater 매니페스트를 갖춰야 합니다.

## 최초 한 번 설정

### 1. GitHub 저장소

공개 저장소는 `kang1027/StayTab`을 사용합니다. 원본 저장소는 `upstream`, StayTab
저장소는 `origin`으로 둡니다.

```bash
git remote set-url --push upstream DISABLED
git remote add origin https://github.com/kang1027/StayTab.git
```

### 2. Apple 공증 자격 증명

Developer ID Application 인증서의 팀은 `GGR9HG6DB8`입니다. App Store Connect에서
앱 전용 암호 또는 API 키를 준비한 뒤 다음 이름으로 로컬 Keychain profile을 만듭니다.

```bash
xcrun notarytool store-credentials "StayTabNotarization" \
  --apple-id "APPLE_ID" \
  --team-id "GGR9HG6DB8" \
  --password "APP_SPECIFIC_PASSWORD"
```

암호를 저장소, 설정 파일, 로그 또는 이슈에 넣으면 안 됩니다.

### 3. 자동 업데이트 서명키

StayTab 전용 BetterUpdater 개인키는 로컬 Keychain의
`StayTab BetterUpdater Signing Key` 항목에 보관합니다. 공개 저장소를 만든 뒤 다음
스크립트로 값을 출력하지 않고 GitHub Actions secret에 전달합니다.

```bash
scripts/configure_release_secrets.sh kang1027/StayTab
```

이 키를 잃으면 이미 배포된 앱의 업데이트 신뢰 체인을 이어갈 수 없습니다. 최초 릴리스
전에 별도 암호 관리자에 안전하게 백업해야 합니다.

## 버전 준비

StayTab은 `v0.1.0` 형식의 태그를 사용합니다.

```bash
scripts/set_version.sh 0.1.0
```

버전 커밋을 검토하고 `origin/main`에 푸시한 뒤 릴리스 노트를 준비합니다.

## 로컬 패키징

```bash
scripts/build_release.sh --clean
```

스크립트는 전체 품질 게이트, Release archive, 코드 서명 확인, 앱·DMG 공증 및 staple,
GPL/NOTICE 번들 포함 여부를 검사합니다. 결과는 `build/release/`에 생성됩니다.

공증 자격 증명 없이 패키징만 점검하려면 다음 명령을 사용합니다. 이 결과물은 공개하면
안 됩니다.

```bash
scripts/build_release.sh --skip-notarization
```

## 공개

DMG를 직접 설치해 동작을 확인한 뒤에만 공개합니다.

```bash
scripts/build_release.sh \
  --skip-build \
  --auto-release \
  --notes-file notes.md
```

`--auto-release`는 현재 `HEAD`가 깨끗하고 `origin/main`과 동일한 경우에만 `v<version>`
태그와 GitHub Release를 만듭니다. 스크립트는 커밋이나 push를 자동 수행하지 않습니다.

릴리스가 공개되면 다음 워크플로가 실행됩니다.

- `sign-release.yml`: DMG/ZIP 해시와 저장소·번들·팀 정보를 서명한 BetterUpdater
  매니페스트를 첨부합니다.
- `update-homebrew-cask.yml`: DMG의 SHA-256으로 `Casks/staytab.rb`를 갱신합니다.

워크플로가 모두 통과한 뒤 새 설치와 인앱 업데이트를 각각 확인합니다.

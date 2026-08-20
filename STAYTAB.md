# StayTab

StayTab은 자주 쓰는 앱을 종료 후에도 `⌘Tab` 목록에 유지하고, 나머지 앱은 실행 중일 때만 보여 주는 macOS 앱입니다.

## 사용 방법

1. StayTab을 실행하고 손쉬운 사용 권한을 허용합니다.
2. 메뉴 막대의 명령 아이콘에서 **Settings…**를 엽니다.
3. **Apps → Always in ⌘Tab**에서 항상 유지할 앱을 선택합니다.
4. `⌘Tab`으로 앱을 선택합니다. 실행 중인 앱은 활성화되고, 종료된 고정 앱은 다시 실행됩니다.

`⌘``은 기존처럼 현재 앱의 창만 전환합니다. 고정 앱 기능은 일반 `⌘Tab`에만 적용됩니다.

## 빌드

```bash
xcodebuild -scheme "BetterCmdTab Debug" -configuration Debug build
```

빌드 결과의 앱 이름은 `StayTab Debug.app`입니다. Xcode 프로젝트와 스킴 이름은 업스트림 호환을 위해 그대로 유지합니다.

파일 기반 설정을 사용할 경우 경로는 `~/.config/staytab/config.json`입니다.

## 오픈 소스

StayTab은 GPL-3.0으로 공개된 [BetterCmdTab](https://github.com/rokartur/BetterCmdTab)을 기반으로 한 파생 프로젝트입니다. 원본 저작권과 GPL-3.0 라이선스는 `LICENSE` 및 기존 소스 기록에 따라 유지됩니다.

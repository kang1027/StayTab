# StayTab 배포 이미지 가이드

README와 릴리스에 사용하는 이미지는 실제 StayTab 빌드에서 캡처합니다. 사용자 데이터,
로컬 프로젝트명, 한국 전용 앱이 보이는 이미지는 공개하지 않습니다.

## 메인 스위처 이미지

- macOS와 StayTab을 다크 모드로 설정합니다.
- 패널 크기는 90%, 레이아웃은 Grid View, 창 제목 표시와 창 상태 아이콘은 끔으로 설정합니다.
- 패널 테마는 이미지 배경을 사용합니다.
- Always에는 ChatGPT, Calculator, Docker, Mail, Music, Obsidian, Warp, Zen을 둡니다.
- ChatGPT와 Calculator는 종료해 점선 상태가 보이게 합니다.
- Running now에는 Helium, Slack, Notion Calendar, Messages, Safari만 둡니다. 다른 앱과
  시스템 경고창은 앱 예외로 숨깁니다.
- `⌘Tab`을 길게 눌러 패널을 표시한 뒤 원본 Retina 해상도로 캡처합니다.
- 패널 바깥의 개인 화면은 제거하고, 앱 이름과 점프 키가 선명한지 확인합니다.

현재 README 자산은 `assets/switcher-hero.png`이며 1940×914 PNG입니다.

## 설정 이미지

- Apps 화면의 Always 목록 전체와 점프 키 입력란이 보이게 합니다.
- 공개 스위처 이미지와 같은 앱 순서를 사용합니다. Calculator만 `Auto`로 두고 나머지는
  자동 배정과 같은 점프 키를 직접 입력해 두 방식이 함께 보이게 합니다.
- App rules에는 기본 Finder 규칙만 둡니다.
- 검색어, 사용자 경로, 계정 정보가 없는지 확인합니다.
- 설정창은 그림자 없이 창 단위로 캡처합니다.

현재 README 자산은 `assets/settings-pinned-apps.png`이며 1740×1300 PNG입니다.

## 테마 이미지

- Theme 화면의 Background 탭을 열고, 패널 미리보기와 Style 항목이 보이게 합니다.
- 대표 스위처 이미지와 같은 이미지 테마를 사용합니다.
- 미리보기 샘플 개수는 Always 8, Running now 12로 둡니다. 개수를 줄이면 가독성 경고가
  표시될 수 있습니다.
- 검색창에 포커스가 없는 상태로 그림자 없이 창 단위로 캡처합니다.

현재 README 자산은 `assets/settings-theme.png`이며 1740×1300 PNG입니다.

화면에 포함된 제3자 앱 아이콘과 상표, 패널 테마 이미지의 권리는 각 소유자에게 있습니다.

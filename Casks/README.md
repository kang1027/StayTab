# Homebrew Cask

첫 안정 릴리스를 공개하면 `update-homebrew-cask.yml`이 검증된 DMG의 SHA-256으로
`staytab.rb`를 생성합니다. 그전에는 존재하지 않는 다운로드 URL이나 임시 체크섬을
커밋하지 않습니다.

StayTab 저장소는 별도 tap 저장소가 준비되기 전까지 명시적 URL tap으로 사용합니다.

```bash
brew tap kang1027/staytab https://github.com/kang1027/StayTab.git
brew install --cask kang1027/staytab/staytab
```

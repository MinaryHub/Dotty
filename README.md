# Dotty

LED 전광판처럼 문구를 도트(점)로 표시하는 **Dot Display 앱**입니다.
Flutter로 만들어 하나의 코드로 **Windows · macOS · Linux · Android**에서 실행됩니다.

## 기능

- **문구 표시**: 한글, 영문, 숫자, 기호 등 시스템 글꼴로 그릴 수 있는 글자는 모두 도트로 변환
- **스크롤**: 왼쪽 / 오른쪽 / 고정, 속도 1–120칸/초
- **색상**: 점 색상(프리셋 + 색조 슬라이더), 무지개 효과, 배경 색상
- **도트 모양**: 해상도(세로 8–64점), 점 크기, 원형/사각형, 꺼진 점 밝기, 빛 번짐(글로우)
- **효과**: 깜빡임(0.5–8 Hz), 굵은 글씨
- **전체 화면 모드**: 화면 꺼짐 방지, 데스크톱은 창 전체 화면, Android는 몰입 모드
  - 화면 탭: 버튼 표시/숨김 · `Esc`: 나가기 · `Space`: 일시정지
- 설정은 자동 저장되어 다음 실행 때 그대로 복원됩니다.

## 실행

[Flutter SDK](https://docs.flutter.dev/get-started/install) 3.47 이상이 필요합니다.

```bash
flutter pub get
flutter run -d windows   # 또는 macos, linux, <android 기기 ID>
```

## 빌드

| 플랫폼  | 명령                            | 결과물                                           |
|---------|---------------------------------|--------------------------------------------------|
| Android | `flutter build apk --release`   | `build/app/outputs/flutter-apk/app-release.apk`  |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/`            |
| macOS   | `flutter build macos --release` | `build/macos/Build/Products/Release/dotty.app`   |
| Linux   | `flutter build linux --release` | `build/linux/x64/release/bundle/`                |

각 데스크톱 빌드는 해당 OS에서만 가능합니다. Linux 빌드에는
`clang cmake ninja-build pkg-config libgtk-3-dev` 패키지가 필요합니다.

GitHub Actions(`.github/workflows/build.yml`)가 push / PR마다 테스트를 돌리고
네 플랫폼 빌드를 모두 만들어 아티팩트로 올립니다.

> Android 릴리스 APK는 기본 템플릿대로 디버그 키로 서명됩니다.
> 스토어 배포 시 `android/app/build.gradle.kts`에 자체 서명 키를 설정하세요.

## 구조

```
lib/
  main.dart                       앱 진입점
  models/display_settings.dart    설정 값 + JSON 직렬화
  models/settings_store.dart      설정 상태 관리 및 저장
  dot_matrix/dot_bitmap.dart      문구 → 도트 비트맵 변환
  dot_matrix/dot_matrix_painter.dart  도트 렌더링 (스크롤/깜빡임/무지개/글로우)
  dot_matrix/dot_matrix_display.dart  애니메이션 위젯
  screens/home_screen.dart        미리보기 + 설정 화면
  screens/settings_panel.dart     설정 패널
  screens/sign_screen.dart        전체 화면 전광판
  platform/screen_mode.dart       창 전체 화면, 화면 꺼짐 방지
```

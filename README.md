# Dotty

LED 전광판처럼 문구를 도트(점)로 표시하는 **Dot Display 앱**입니다.
Flutter로 만들어 하나의 코드로 **웹(Vercel) · Windows · macOS · Linux · Android**에서 실행됩니다.

## 기능

- **여러 장면 + 순차 재생**: 장면을 원하는 만큼 만들고 순서대로 자동 전환, 끝나면 처음부터 반복
  - 장면 목록에서 선택 · 길게 눌러 끌어서 순서 변경 · 메뉴로 이동/복제/삭제
  - 다음 장면으로 넘어가는 시점: **스크롤 N회 완료 후** 또는 **N초 후**
  - 장면이 나타나는 효과: 바로 / 페이드 / 옆으로 밀기 / 위로 밀기 (도트 단위로 이동) /
    **플립** (플립 도트 전광판처럼 모든 점이 왼쪽부터 물결치듯 뒤집히며 바뀜)
  - 상단 **연속 재생** 버튼으로 편집 화면에서도 전체 흐름 미리보기
  - **전체 화면**은 연속 재생이 켜져 있을 때만 모든 장면을 순서대로 재생하고, 꺼져 있으면
    선택한 장면만 반복 재생합니다 (미리보기와 같은 동작).
- **LED 입체 표현**: 각 LED를 소켓에 박힌 볼록한 렌즈로 그립니다 — 돔 음영, 빛나는 심,
  반사 하이라이트, 색이 묻은 빛 번짐. 꺼진 LED는 어둡게 물든 렌즈로 보입니다.
- **화면 비율 (미리보기 = 전체 화면)**: 패널에서 화면 비율을 고르면 가로×세로 점 격자가 고정되어
  미리보기와 전체 화면이 똑같이 보입니다. 기본 **자동**은 이 기기 화면 비율을 써서 전체 화면을 꽉
  채웁니다 (16:9 · 4:3 · 21:9 · 32:9 · 3:1 · 2:1 · 1:1 · 9:16도 선택 가능).
- **표시 방식: LED / 플립 도트**
  - **플립 도트**: 실제 기계식 플립 도트 전광판처럼 원판(점)이 바뀔 때만 하나씩 뒤집힙니다.
    원판은 홈에 끼워진 입체 원판(음영·테두리·회전축·그림자)으로 그려지고, 원판마다 밝기와
    기울기가 조금씩 달라 아날로그 느낌이 납니다. 자석에 끌려 가속하며 돌다가 멈춤쇠에 부딪혀
    살짝 튕긴 뒤 멈추며, 구동 회로처럼 열을 순서대로 훑으며 뒤집힙니다.
    스크롤·깜빡임·편집·장면 전환 모두 점이 뒤집히며 바뀌고, 장면 전환 효과에 따라
    뒤집히는 순서가 달라집니다 (옆으로 밀기·플립: 왼쪽부터 물결, 위로 밀기: 아래에서 위로,
    페이드: 무작위로 흩어지듯, 바로: 한꺼번에).
  - 움직이는 원판은 가로 회전축을 중심으로 원근감 있게 3D로 돌아갑니다. 옆면이 보일 때는
    원판 두께가 얇은 막대로 보이고, 기울어지며 빛을 받아 반짝입니다.
  - **원판 뒤집힘 시간**(패널 탭, 0.08–1초, 기본 0.5초): 원판 하나가 뒤집혀 멈출 때까지의 시간.
    고정된 장면이 바뀔 때 가장 잘 보입니다. 빠르게 흐르는 글자(스크롤 6칸 이상)나 깜빡임에서는
    글자가 뭉개지지 않도록 자동으로 짧아지므로, 뒤집히는 모습을 보려면 스크롤 속도를 낮추세요.
    장면이 바뀔 때 물결이 화면을 지나가는 시간은 **전환 효과 시간**으로 따로 조절합니다.
  - **뒤집히는 소리**: 코일이 놓이는 작은 틱 → 원판이 멈춤쇠에 부딪히는 "딱" → 되튐 탭과
    하우징 잔향까지 합성해, 뒤집히는 점마다 그 순간에 맞춰 재생합니다. 한 점은 "틱", 화면
    전체가 바뀔 때는 "촤르륵" 하고, 많은 점이 한꺼번에 뒤집히면 판 전체가 울리는 낮은 "쿵"이
    더해집니다. 음량 조절 가능.
    (웹은 첫 탭/클릭 이후 소리가 납니다 — 브라우저 정책)
- **문구 장면**: 한글, 영문, 숫자, 기호 등 글꼴로 그릴 수 있는 글자는 모두 도트로 변환
  - "고정" 장면은 속도 설정을 쓰지 않습니다. 글자가 화면보다 조금 넓으면 맞게 줄이고, 많이
    넓으면 (작게 줄이면 한글이 뭉개지므로) 실제 전광판처럼 일정한 속도(15칸/초)로 흐르게 합니다.
- **시계 장면 (현재 시간 데모)**: 이 기기의 현재 시간을 실시간으로 표시합니다.
  `14:05` · `14:05:09` · `오후 2:05` · `10/24 14:05` 형식, 숫자는 도트 시계처럼 또렷한 7-세그먼트로
  화면에 들어가는 가장 큰 크기로 그립니다. 초가 없는 형식은 콜론(:)이 1초마다 깜빡여 매초 갱신이
  보입니다. 플립 도트에서는 바뀐 숫자의 원판만 뒤집혀 플립 시계처럼
  동작합니다. 장면 목록의 **시계 추가** 버튼으로 넣을 수 있고, 처음 실행 시 기본 쇼에도 들어 있습니다.
- **이미지 장면**: PNG · JPG · GIF · WebP 파일을 도트로 변환
  - **원본 색**(점마다 이미지 색) 또는 **단색**(장면 점 색상) 모드
  - 밝기 기준으로 어두운 부분은 꺼진 점으로 처리
- **장면별 설정**: 점 색상(프리셋 + 색조), 무지개 효과, 스크롤 방향/속도(0 = 멈춤), 깜빡임, 굵은 글씨
- **패널 공통 설정**: 화면 비율, 해상도(세로 8–64점), 점 크기, 원형/사각형, 꺼진 점 밝기, 빛 번짐, 배경, 전환 시간
- **전체 화면 모드**: 화면 끝까지 도트로 꽉 채움, 화면 꺼짐 방지, 데스크톱은 창 전체 화면,
  웹은 브라우저 전체 화면, Android는 몰입 모드(카메라 노치 영역까지 사용)
  - 화면 탭: 버튼 표시/숨김 · `Esc`: 나가기 · `Space`: 일시정지 · ⛶ 버튼: 다시 꽉 채우기
  - iPhone Safari는 웹 전체 화면을 지원하지 않으므로 공유 → 홈 화면에 추가 후 실행하세요.
- 모든 장면과 설정(이미지 포함)은 자동 저장되어 다음 실행 때 그대로 복원됩니다.
  웹은 브라우저 저장소에 저장되므로 기기·브라우저마다 따로 저장됩니다.

## 웹 배포 (Vercel) — apps.kimserv.com/dotty

저장소의 `vercel.json`과 `scripts/vercel-build.sh`로 배포됩니다.

- 빌드 스크립트가 Flutter SDK를 받아 `flutter build web --base-href /dotty/`로 빌드하고
  결과를 `build/site/dotty/`에 배치합니다. 사이트 루트(`/`)는 `/dotty/`로 이동합니다.
- 다른 경로에 올리려면 Vercel 환경 변수 `DOTTY_BASE_PATH`(예: `/sign/`)를 설정하세요.
- Flutter 버전은 환경 변수 `FLUTTER_VERSION`으로 바꿀 수 있습니다.

**도메인 연결**: `apps.kimserv.com`을 Vercel 프로젝트 도메인으로 추가한 뒤, DNS(Google Cloud DNS)에
다음 레코드를 추가하세요.

| 이름 | 종류  | 값                      |
|------|-------|-------------------------|
| apps | CNAME | `cname.vercel-dns.com.` |

로컬에서 웹으로 실행하기:

```bash
flutter run -d chrome
```

## 실행

[Flutter SDK](https://docs.flutter.dev/get-started/install) 3.47 이상이 필요합니다.

```bash
flutter pub get
flutter run -d windows   # 또는 macos, linux, <android 기기 ID>
```

## 빌드

| 플랫폼  | 명령                            | 결과물                                           |
|---------|---------------------------------|--------------------------------------------------|
| Web     | `flutter build web --release --no-web-resources-cdn` | `build/web/`              |
| Android | `flutter build apk --release`   | `build/app/outputs/flutter-apk/app-release.apk`  |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/`            |
| macOS   | `flutter build macos --release` | `build/macos/Build/Products/Release/dotty.app`   |
| Linux   | `flutter build linux --release` | `build/linux/x64/release/bundle/`                |

각 데스크톱 빌드는 해당 OS에서만 가능합니다. Linux 빌드에는
`clang cmake ninja-build pkg-config libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
패키지가 필요합니다.

GitHub Actions(`.github/workflows/build.yml`)가 push / PR마다 테스트를 돌리고
다섯 플랫폼 빌드를 모두 만들어 아티팩트로 올립니다.

> Android 릴리스 APK는 기본 템플릿대로 디버그 키로 서명됩니다.
> 스토어 배포 시 `android/app/build.gradle.kts`에 자체 서명 키를 설정하세요.

## 구조

```
lib/
  main.dart                       앱 진입점
  models/show.dart                쇼(패널 + 장면 목록) 데이터 + JSON 직렬화
  models/show_store.dart          쇼 상태 관리 및 저장
  dot_matrix/dot_bitmap.dart      문구/이미지 → 도트 비트맵 변환
  dot_matrix/clock_font.dart      시계 장면의 7-세그먼트 숫자
  dot_matrix/dot_matrix_painter.dart  도트 렌더링 (스크롤/깜빡임/무지개/이미지 색/글로우)
  dot_matrix/dot_matrix_display.dart  한 장면 애니메이션 위젯
  dot_matrix/show_player.dart     장면 순차 재생 + 전환 효과
  dot_matrix/flip_board.dart      플립 도트 원판 상태(점별 뒤집힘 타이밍)
  dot_matrix/led_sprites.dart     LED 렌즈 스프라이트 (소켓·빛 번짐·렌즈·심·하이라이트)
  dot_matrix/disc_sprites.dart    플립 도트 원판 스프라이트
  dot_matrix/sign_geometry.dart   전광판 비율/가로 점 수 (미리보기 = 전체 화면)
  sound/                          플립 소리 합성 + 재생 (웹: Web Audio, 앱: audioplayers)
  screens/home_screen.dart        미리보기 + 장면 목록 + 편집 화면
  screens/editor/                 장면 목록, 장면 편집, 패널 편집
  screens/sign_screen.dart        전체 화면 전광판
  platform/image_import.dart      이미지 파일 선택
  platform/screen_mode.dart       창/브라우저 전체 화면, 화면 꺼짐 방지
web/                              웹 진입점, PWA manifest, 아이콘
vercel.json, scripts/vercel-build.sh  Vercel 배포 설정
```

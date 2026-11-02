---
id: feature-retention-polish
title: One Line Labyrinth 별자리 시각 개편, 한붓 손맛, 재플레이 동기(별점, 레벨 지도, 별자리 도감, 하늘 레벨)
status: active
owner: games
related_adrs:
  - adr-one-line-labyrinth-crazygames-web
  - adr-spec-driven-delivery
related_contracts:
  - contract-grid-puzzle-generation
  - contract-one-line-labyrinth-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# 기능 명세: 별자리 시각 개편, 한붓 손맛, 재플레이 동기

## Problem
CrazyGames가 같은 계열의 게임(MergeCamp)을 "The overall quality of the game does not yet meet the expectations of our
platform"으로 거절했다. One Line Labyrinth도 회색 원과 노란 선, Material 기본 위젯만 있어 시제품처럼 보이고,
선을 긋는 순간과 퍼즐을 푸는 순간의 연출이 약하며 배경음악이 없다. 저장되는 것은 난이도별 최고 레벨뿐이라
레벨을 끝낸 뒤 다시 플레이할 이유(목표, 수집, 성장)가 부족하다.

## Scope
1. 시각 개편(별자리 테마)
   - 매듭(knot)은 별, 그은 선은 빛나는 실(thread)로 외부 에셋 없이 `CustomPainter`로 그린다. 시작 매듭은 빛살이 있는
     큰 별, 끝 매듭은 궤도 고리가 있는 별, 방문 가능한 매듭은 맥동하는 고리로 구분한다. 연결선(link)은 희미한 점선 실이다.
   - 그은 선은 바깥 번짐, 색 실, 흰 심 3겹으로 그리고 선을 따라 흐르는 빛(shimmer)과 선 끝의 불꽃을 애니메이션한다.
   - 배경은 테마별 밤하늘(그라데이션, 성운, 반짝이는 별, 가끔 지나가는 유성, 지평선 실루엣)이다. 보드는 반투명 유리 패널이다.
   - 하늘 테마 4종: Twilight(Lv1, 기본), Aurora(Lv3), Nebula(Lv6), Eclipse(Lv10). 테마는 꾸미기 전용이며 규칙에 영향이 없다.
   - 넓은 화면(1280x720, 1366x768 iframe)은 보드를 가운데 두고 왼쪽 패널(제목, 지표, 난이도, 도구, 별 목표)과
     오른쪽 패널(하늘 레벨, 테마, 레벨 지도, 도감, 결과 카드)을 둔다. 중간 폭 가로 화면(844x390)은 두 열,
     좁은 화면(390x844, 320x480)은 위아래로 쌓는다. 어디에서도 오버플로가 없다.
   - 튜토리얼 카드는 새 패널 모양으로 바꾸고 문구를 별/고리 표현에 맞춘다. 동작(첫 실행, Skip, 키 처리)은 그대로다.
2. 손맛(연출)
   - 매듭을 방문하면 별이 튀어 오르며(pop) 작은 고리와 반짝이가 퍼진다.
   - 되돌리기(이전 매듭으로 돌아가기)는 지워지는 선분이 이전 매듭 쪽으로 말려 들어가며 사라지고, 초기화는 선 전체가 흩어진다.
   - 연결되지 않은 매듭을 탭하면 그 매듭이 붉게 흔들린다.
   - 막다른 길(선 끝에 방문 가능한 이웃이 없는데 아직 끝나지 않음)이면 선 끝이 붉게 맥동하고 상태 문구가 되돌리기를 권한다.
   - 드래그 중에는 선 끝에서 손가락까지 희미한 실이 따라온다.
   - 완성하면 빛의 파동이 시작에서 끝까지 선을 따라 흐르고, 별들이 차례로 빛나며, 끝 매듭에서 파티클이 터지고,
     별자리 이름이 보드 위에 나타난다. 연속 클린 클리어는 "Clean streak x2" 배너로 강조한다.
   - 연출은 입력을 막지 않는다. 규칙 처리는 즉시 하고 연출은 뒤따른다. 화면 전체에 시계(ticker)는 하나이며
     페인터만 다시 그린다. 연출 수명은 타이머가 아닌 이 시계로 관리한다.
3. 레벨 안의 목표: 별점(레벨 생성은 바꾸지 않는다)
   - 별 1: 풀기(Solved). 별 2: 클린(Clean line) - 되돌리기, 초기화, 힌트를 한 번도 쓰지 않음.
     별 3: 신속(Swift) - 기준 시간 이하. 기준 시간 = ceil(매듭 수 x 1.6) + 4초.
   - 플레이 중 패널에 두 목표의 현재 상태(클린 유지/실패, 경과 시간/기준 시간)를 보여준다.
   - 힌트 버튼(툴팁 "Hint", 키 H): 현재 선을 숨은 해답과 일치하는 가장 긴 앞부분까지 되감고 다음 매듭을 빛낸다.
     힌트를 쓰면 클린 별을 잃는다. 해답 생성 로직은 바꾸지 않는다.
4. 레벨 사이의 동기: 결과 카드, 레벨 지도, 별자리 도감, 하늘 레벨
   - 결과 카드(완성 후, 보드 입력은 이미 막힘): 별자리 이름, "New constellation!", 별 3개(차례로 등장, 효과음),
     걸린 시간, 레벨 최고 별 수, "New best!"(그 난이도에서 처음 도달한 레벨), 획득 XP, 레벨 진행 바, 레벨 업과
     새로 열린 테마, "Replay"(같은 레벨 새 퍼즐)와 "Next Level" 버튼. Enter/Space는 Next Level이다.
     넓은 화면은 오른쪽 패널, 좁은 화면은 보드 아래에 놓여 별자리를 가리지 않는다.
   - 레벨 지도(오버레이): 난이도별로 레벨 1부터 (최고 레벨 + 1)까지 열리고 각 레벨의 최고 별 수를 보여준다.
     열린 레벨을 고르면 그 레벨 크기의 새 퍼즐을 시작한다. 잠긴 레벨은 고를 수 없다.
   - 별자리 도감(오버레이): 난이도별 레벨 1-12, 총 36칸. 칸마다 고정된 별자리 이름이 있고, 처음 깬 순간
     플레이어가 실제로 그은 선 모양이 저장되어 그림으로 보인다. 아직 못 깬 칸은 "???"와 희미한 점이다.
     레벨 13 이상은 이름만 결정적으로 생성하고 도감에는 넣지 않는다.
   - 하늘 레벨: 풀 때마다 XP = 20 + 별 x 10 + 난이도 보너스(Normal 5, Hard 10) + 처음 깬 레벨 보너스 15.
     레벨 L에서 L+1까지 100 + 40 x (L - 1) XP. 테마 해금 Lv3/Lv6/Lv10은 대략 6/20/50번 풀이다.
   - 오버레이(지도, 도감)가 열려 있으면 보드와 HUD 입력이 막히고 Esc/Enter로 닫힌다. 튜토리얼과 같은 키 규칙
     (Tab, F5, Ctrl/Cmd/Alt 조합은 통과)을 따른다.
   - 진행도는 `shared_preferences` 키 `labyrinth_progress_v1`(JSON)에 저장한다: XP, 선택 테마, 난이도별 최고 레벨,
     레벨별 최고 별, 도감. 읽기/쓰기 실패나 손상된 값은 필드 단위로 기본값으로 대체하고 플레이를 막지 않는다.
   - 마이그레이션: 기존 `best_level_<difficulty>` 키(`BestLevelStore`)는 계속 읽고 쓰며, 로드 시 새 키의 최고
     레벨과 큰 값을 취한다. 기존 기록은 사라지지 않는다.
   - 저장된 값이 로드되기 전에는 저장하지 않는다. 로드 전에 생긴 진행(풀이)은 로드 후 합쳐서 저장한다.
5. 소리
   - 배경음악: 우주 느낌의 앰비언트 루프(느린 패드 화음, 드문 종소리 아르페지오와 메아리, 옅은 바람 소리)를
     `tool/generate_sounds.py`(표준 라이브러리, 결정적)로 합성한다. 16000 Hz 모노 16비트, 1 MB 이하,
     `assets/music/ambient_loop.wav`(효과음 폴더와 분리). 루프 경계가 끊기지 않게 원형으로 합성한다.
   - 웹은 첫 사용자 입력 이후 시작하고, 탭/앱이 숨겨지면 멈췄다가 돌아오면 이어진다. 소리 토글(효과음+음악 하나),
     CrazyGames `muteAudio`(설정 변경 리스너 + 입력마다 재확인)를 따른다. 이 게임에는 광고가 없다.
   - 네이티브: iOS `AVAudioPlayer`(.ambient, 무한 반복, 통화 등 인터럽트 뒤 재개), Android `MediaPlayer`
     (`isLooping`, `USAGE_GAME`)로 `startLoop`/`stopLoop`를 채널 `one_line_labyrinth/audio`에 추가한다.
   - 새 효과음: `hint`, `dead_end`, `star`(결과 카드의 별마다), `level_up`. 기존 step/undo/invalid/solved는 유지한다.

## Acceptance Criteria
- 매듭, 선, 시작/끝, 방문 가능 매듭이 별자리 그림으로 그려지고 4개 테마 모두 배경과 보드가 그려진다.
- 방문, 되돌리기, 초기화, 잘못된 탭, 막다른 길, 완성 연출이 재생되고, 연출 중에도 탭/드래그가 즉시 처리된다.
- 완성 시 별 수가 규칙대로 계산되어 결과 카드에 보이고, 레벨별 최고 별이 저장되어 레벨 지도에 보인다.
- 힌트는 해답과 어긋난 부분을 되감고 다음 매듭을 표시하며, 쓰면 클린 별이 사라진다.
- 결과 카드에 이름, 별, 시간, New best, XP, 레벨 바, 해금 테마가 보이고 Next Level/Replay가 동작한다.
- 처음 깬 레벨 1-12는 도감에 그 선 모양으로 저장되고, 앱을 다시 열어도 유지된다. 미발견 칸은 "???"이다.
- 레벨 지도에서 열린 레벨만 고를 수 있고 고르면 그 레벨이 시작된다.
- 테마는 요구 레벨 도달 시 열리고 고를 수 있으며, 잠긴 테마는 고를 수 없다. 선택은 유지된다.
- 기존 `best_level_*` 값은 새 진행도와 합쳐져 HUD에 보인다. 손상된 `labyrinth_progress_v1`은 기본값으로 대체된다.
- 배경음악은 음소거(사용자/플랫폼) 시 멈추고, 숨김 시 멈췄다가 돌아오면 재생된다. 웹은 첫 입력 전에는 재생하지 않는다.
- 튜토리얼, 결과 등록(GitHub Pages 전용 한국어 문구), CrazyGames gameplayStart/Stop, GamePix 흐름은 그대로다.
- 390x844, 844x390, 1280x720, 1366x768, 320x480에서 오버플로가 없다.
- 기존 테스트가 통과한다(UI가 실제로 바뀐 곳만 수정). CrazyGames/GamePix 빌드 자체 검사가 통과한다.

## Constraints
- 새 패키지 의존성 없음. 그림은 코드로, 소리는 생성기로 만든다.
- `lib/` UI 문자열은 영어 ASCII다. 예외는 기존 `result_registration.dart`의 GitHub Pages 전용 결과 등록 문구다.
- 퍼즐 생성(`puzzle_generator.dart`)과 한붓 규칙(이웃만, 한 번씩, 끝은 고리)은 바꾸지 않는다.
- GamePix: 외부 요청 없음, 모든 자산은 번들이다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /OneLineLabyrinth/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 임시 골든 테스트로 1280x720, 390x844 화면과 결과 카드 PNG를 렌더링해 확인(확인 후 삭제)
- `node <harness-lab>/dist/index.js audit . --format md`

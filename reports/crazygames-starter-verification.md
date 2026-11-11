# CrazyGames playable onboarding verification

Verified on 2026-11-11 against the working tree based on
`4f35897364c500a4d109e35c327cc7c62cf72ca8`.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | Exit 0, no issues |
| `flutter test --no-pub --reporter expanded` | Exit 0, 137 passed |
| `flutter test --no-pub --platform chrome test/web --timeout 60s --reporter expanded` | Exit 0, 17 passed |
| `flutter test --no-pub --platform chrome test/game_platform_flow_test.dart --name CrazyGames --timeout 60s --reporter expanded` | Exit 0, 5 passed |
| `tool/build_crazygames.sh` and `unzip -tq build/one-line-labyrinth-crazygames.zip` | Exit 0, 46 files, CRC passed |
| `flutter build web --release --no-pub --base-href /OneLineLabyrinth/` | Exit 0, SDK absent and hub nav present |
| Harness verify and check-evidence | Exit 0, execution and source fingerprints verified |
| Harness audit | Exit 0, 0 critical and 4 existing workflow/maintenance warnings |
| Independent harness review | Approved after fixes to first-frame SDK timing, HUD focus and saved-progress coverage |

Commands ran from the OneLineLabyrinth repository. The verification bundle
and command logs are in `build/starter-verification/`. The CrazyGames bundle
folder is `build/crazygames/`. The ZIP archive has 12,576,200 bytes and SHA-256
`9804592b51ce6c9e7505dcd954b1e7f728eee4518ff1308744eaafbed60389b6`.

The release build was also opened locally in Orca's Chromium browser.
Screenshots of the 1280×720 and 390×844 first board and a 1280×720 first clear
are in `build/starter-screenshots/`. The first clear was a functional smoke
check after the browser had been left open. First-time human completion
timing, native device testing and authenticated CrazyGames portal QA remain
unmeasured. The November 6 submission packet reflects the previous release.

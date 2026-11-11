# CrazyGames launch verification — 2026-11-06 task

Final verification recorded at 2026-11-06T15:20:48.659750+00:00.

Base: `4f35897364c500a4d109e35c327cc7c62cf72ca8`. HEAD: `4f35897364c500a4d109e35c327cc7c62cf72ca8`. Working tree dirty: `True`. Existing gameplay changes were preserved; no commit or push performed.

Build inputs SHA-256 at report time: `8bd181b75698d8291f9485fc2f7032a316a57ed11a2f7ba88f09cd5f40eddd14`. This fingerprint covers lib/assets/web/tool/pubspec; it is not a claim of a clean commit build.

## Final checks

| Check | Result |
|---|---|
| Flutter analyze | exit 0 |
| Full VM tests | exit 0; 130 passed |
| Chrome SDK/cloud tests | exit 0; 17 passed |
| Normal Pages release build | exit 0; no CrazyGames SDK in index.html |
| CrazyGames release build/self-checks | exit 0 |
| Harness audit | exit 0; Critical 0; warnings 4 |
| Independent review | approve; no findings |

Exact commands, sanitized logs and structural ZIP checks are in `crazygames-launch-2026-11-06/verification.json` and its sibling `.log` files. The five existing games' final Chrome rerun used a muted/headless wrapper with background timer throttling disabled and explicit timeouts after the earlier abandoned runner stalled; the successful complete rerun is the accepted evidence.

## Upload bundle

- Path: `build/one-line-labyrinth-crazygames.zip`
- ZIP SHA-256: `03de76b21172933492bbbeea9fc8c92b03a7bb267d6b3f4521814ae6209e8bf1`
- ZIP bytes: 12575476; files: 46; unpacked bytes: 31059248
- Root index, relative base, SDK v3, no hub navigation, no debug symbols and ZIP CRC checked.

## Review and limits

Independent harness-review of the entire release working tree approved with no findings. 

Local SDK tests use a fake SDK and do not establish real account syncing or platform-hosted QA. Authenticated draft upload, portal settings, actual QA and publication are coordinator-owned and recorded separately in the launch packet. Native device testing was not part of this web release verification. Existing maintenance/workflow warnings remain in the audit.

References used: repository AGENTS/workflow/project instructions where present, CrazyGames and cloud-save specs, linked ADR/contracts, constraints and golden rules. Applied packs: none. Constraints: preserve ordinary distributions, preexisting edits and source freeze; no production edits during final verification. Conflicts or gaps: external QA and existing audit maintenance warnings. Escalation: none for local verification.

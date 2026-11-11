# CrazyGames build

Building with `--dart-define=CRAZYGAMES=true` enables the CrazyGames HTML5 SDK v3
adapter and the playable Easy starter sequence. Normal web (GitHub Pages)
and mobile builds do not use the SDK.

## First session

Easy levels 1–5 are fixed boards. The first board is playable immediately
and highlights the first link. A dead end points back to the previous star.
Use the question-mark button to open the full help card. Easy level 6 and
all Normal and Hard levels use the puzzle generator.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder for portal upload
- `build/one-line-labyrinth-crazygames.zip`: archive of the bundle folder

The script builds with `--base-href /` and `--no-web-resources-cdn`, then sets
`<base href="./">`, inserts the SDK script before the Flutter loader, removes the
Bon-on hub navigation bar (portals forbid outbound links), deletes `*.symbols`, and
checks file count (<= 1500) and size (<= 50MB).

## Tests

```sh
flutter test                              # game flow with a fake platform (VM)
flutter test --platform chrome test/web   # SDK adapter (Chrome)
```

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/crazygames/index.html
```

On `localhost` the SDK environment is `local`; the console logs the SDK calls.

## SDK events

| When | Call |
|---|---|
| Startup | `SDK.init()`; SDK is disabled unless environment is `crazygames` or `local` |
| First playable board becomes active | `gameplayStart` |
| "How to play" overlay opens | `gameplayStop` |
| Overlay closes | `gameplayStart` |
| Level complete | `gameplayStop` |
| Next Level / new puzzle / difficulty change after completion | `gameplayStart` |

Leaderboard registration is not offered in this build, and no ads are used.

## Progress Save

Progress is saved through the SDK Data module (`feature-crazygames-cloud-save`). On the submission screen, **Progress Save**
must be set to "Yes, using the Data Module from the CrazyGames SDK"; otherwise the Data module is disabled and progress
stays in browser localStorage only.

- All preferences are stored in one Data module key, `prefs_v1`, as `{rev, owner, values}`, and mirrored to localStorage.
  localStorage `cg_prefs_stamp_v1` records the mirror's owner (username, null for guests) and revision.
- At startup the local mirror wins when it belongs to the same player and its revision is not older than the account copy;
  otherwise the account copy wins. Another player's mirror is never used. Progress from before this feature is adopted only
  when no account copy exists.
- While cloud save is active, the page reloads (`user.addAuthListener`) only when the player changes
  to a different player or logs out. If the initial user cannot be read, cloud save stays off.

Sound: effects and the music loop are muted while `SDK.game.settings.muteAudio` is true (read on every sound, re-checked on every input and via `addSettingsChangeListener`), in addition to the player's own sound toggle. Music starts after the first input and pauses while the tab is hidden.

## Upload notes

- Orientation: portrait and landscape are both supported; the layout adapts.
- Input: touch/mouse tap and drag (keyboard is not required).
- Prepared covers: 1920x1080, 800x1200, 800x800.
- Submit with Basic Launch first.

## Launch verification — 2026-11-06

- Covers are maintained in the workspace marketing folder (`../_marketing/OneLineLabyrinth/crazygames-launch/`) in landscape 1920x1080, portrait 800x1200 and square 800x800 sizes.
- Backgrounding or losing focus pauses SDK gameplay and sound; resume starts gameplay only if no tutorial/menu/result is open. Repeated lifecycle transitions do not duplicate events.
- Local automated SDK tests use a fake SDK. Final portal QA must still confirm the real uploaded build's loading, inputs, audio mute and account progress persistence.
- The self-contained release packet is prepared at `../_marketing/crazygames-launch-2026-11-06/OneLineLabyrinth/` (ZIP, media and submission metadata). Portal upload and real QA are pending authenticated portal access.

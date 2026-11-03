# CrazyGames build

Building with `--dart-define=CRAZYGAMES=true` enables the CrazyGames HTML5 SDK v3
adapter. Normal web (GitHub Pages) and mobile builds do not use the SDK.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder
- `build/one-line-labyrinth-crazygames.zip`: portal upload zip

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
| Tutorial flag read and overlay not shown (first launch: overlay closed) | `gameplayStart` |
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
- Covers still needed (not created): 1920x1080, 800x1200, 800x800.
- Submit with Basic Launch first.

# Extended Camera

Lets the camera zoom out further than the game allows, when exploring and in combat.

A mod for Baldur's Gate 3 (Patch 8), made with game version 4.1.1.7398727. It needs
[Norbyte's Script Extender](https://github.com/Norbyte/bg3se) and the
[Mod Configuration Menu](https://github.com/AtilioA/BG3-MCM) (MCM) 1.41. This README is for developers. What the mod
does, how to install it and its compatibility are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus).

## How it works

The game keeps its camera limits in four camera definitions, which the Script Extender exposes as
`Ext.Utils.GetGlobalSwitches().CameraSwitches` (type `CameraGlobalSwitches`). `DefaultDistanceMax` is the zoom-out
limit with mouse and keyboard. [Native Camera Tweaks](https://github.com/ersh1/BG3_NativeCameraTweaks) writes the
same values in memory; its offsets (exploration `0x79C`, combat `0x930`, one more at `0xC58`, all `0x194` apart, the
size of `CameraGlobalSwitches`) put the exploration camera at index 1 and the combat camera at index 2, and its
comments give the game's limits: 12 when exploring, 15 in combat.

`Client/Camera.lua` sets `DefaultDistanceMax` of both from the settings, on the client:

- at every session load, after it wrote all four definitions to client.log (`Camera switches: [1] max 12, ...`);
- at once after an MCM change (`Settings.OnChange`);
- every two seconds it compares the values with the settings and sets them again when the game or a setting changed
  them. The log tells once per mode when the game wrote its own value.

The values belong to the game process, not to the Lua state, so they stay when a save loads; the mod always sets the
values from the settings and never changes them relative to what it finds. Slider values are rounded and clamped to
10-40, because MCM saves values between the steps while the player drags a slider. When the Script Extender gives no
camera switches, the mod writes one error line to client.log and leaves the camera alone.

## Settings

The Mod Configuration Menu shows the settings of `MCM_blueprint.json`. `Shared/Settings.lua` reads them:
`Settings.Get(id)` returns the value and its source (`MCM` or `default`), and `Settings.OnChange(fn)` reports a change
or an MCM profile switch. Without MCM (missing, or loaded after this mod) the values of `Settings.Defaults` apply. The
tests check that `Settings.Defaults` and the blueprint list the same settings with the same defaults. `meta.lsx` lists
MCM 1.41.0.0 (`755a8a72-407f-4f0d-9a33-274ac0f0b53d`) as a dependency, so the mod managers load MCM first; only then
does MCM put its `MCM` table into this mod. The setting ids are part of the players' saved settings: never rename one
after a release.

## Build

Requirements: Windows PowerShell and [LSLib](https://github.com/Norbyte/lslib/releases) (`Divine.exe`).
`build.ps1` looks for `_tools\lslib\Packed\Tools\Divine.exe` in the parent folders of the project; set `BG3_TOOLS` to
a folder that holds `lslib\` to use another place.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1             # dist\bg3_extendedcamera.pak
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy     # build, then copy the .pak to the Mods folder
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Wait      # copy the .pak when the game is closed
```

`deploy.ps1` copies the .pak to the `Mods` folder below `BG3_DATA_DIR` (the BG3 user-data folder), else to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`; `-ModsDir` overrides both. The running game locks the .pak, so
the script stops (exit code 2) or, with `-Wait`, waits until the game is closed.

## Project layout

```
src/                                     Mod files (packed into the .pak)
  Mods/bg3_extendedcamera/meta.lsx           Mod metadata (UUID 26eba788-94ed-4f42-89f6-d75036cf09ca), MCM dependency
  Mods/bg3_extendedcamera/MCM_blueprint.json The Mod Configuration Menu page (the settings)
  Mods/bg3_extendedcamera/ScriptExtender/
    Config.json
    Lua/BootstrapServer.lua              Server entry point
    Lua/BootstrapClient.lua              Client entry point
    Lua/Shared/Common.lua                Shared helpers (mod version)
    Lua/Shared/FileWriter.lua            Throttled file output in the Script Extender folder
    Lua/Shared/Settings.lua              MCM settings with defaults (Settings.Defaults)
    Lua/Server/ServerLog.lua             server.log
    Lua/Client/ClientLog.lua             client.log
    Lua/Client/Camera.lua                Sets the zoom-out limits from the settings
docs/                                    Cover and screenshots for openmods.md
tests/                                   Offline tests (Lua 5.4 through lupa)
scripts/bump_version.py                  Raises the last version digit in meta.lsx
scripts/show_log.py                      Prints the mod's log files and MCM settings
build.ps1                                Builds dist/bg3_extendedcamera.pak from src/ (.loca.xml -> .loca, .lsf.lsx -> .lsf)
deploy.ps1                               Copies the .pak to the Mods folder
openmods.json, openmods.md               Data and mod page for openmods.nexus
```

Versioning: every change raises the last version digit (1.0.0.0 -> 1.0.0.1):

```powershell
python scripts\bump_version.py           # both Version64 values in meta.lsx
python scripts\bump_version.py --show
```

Logs: the mod writes `server.log` and `client.log` to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\bg3_extendedcamera\`. Each load writes a line like
`Extended Camera 1.0.0.1 loaded.`, so the logs show which version runs, and server.log gets a line with every setting,
for example `Settings: combat_max_distance = 20 (MCM), exploration_max_distance = 20 (MCM).`, also after each change.
client.log gets the camera values and every change, for example
`Session loaded: zoom-out limit exploration 12 -> 20, combat 15 -> 20.` The files keep the lines of earlier
loads and game starts (the newest 500 in server.log, 200 in client.log). MCM stores the settings in
`Script Extender\BG3MCM\Profiles\<Profile>\bg3_extendedcamera\settings.json`. `python scripts\show_log.py` prints the
newest log lines and these settings (from `BG3_DATA_DIR`, if set).

Tests:

```powershell
python -m pip install lupa
python tests\run_tests.py
```

The tests run every mod script against mocks of the Script Extender API (`tests/harness.lua`). The IMGUI, audio and
resource mocks are checked against the Script Extender IDE helpers (`tests/gen_extui_api.py` refreshes
`tests/extui_api.json`), so a property or method that does not exist in the real API fails the tests.

## License

MIT, see [LICENSE](LICENSE).

## Credits

ersh1's [Native Camera Tweaks](https://github.com/ersh1/BG3_NativeCameraTweaks) (GPL-3.0) was the reference for the
camera values and their meaning; this mod copies no code from it. Norbyte's
[Script Extender](https://github.com/Norbyte/bg3se) exposes the values to Lua.

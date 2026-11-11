# Indian Truck Simulator - All India Edition

A 3D Indian truck driving simulator for Windows, made with Godot 4.7 (free, MIT licence).
The game starts in Coimbatore, Tamil Nadu. This is **Phase 1**: driving, the driver on foot,
the Coimbatore starter area and three truck horns.

## Status

| Area | State |
|---|---|
| Driving physics (6x4 truck, 6-speed auto/manual, air brakes, parking brake, 80 km/h governor) | Working, tested |
| Cockpit and chase cameras, driver on foot, get in / get out | Working, tested |
| Three horns (H standard, J air horn, K multi-tone), rebindable, combined mode | Working, tested |
| Coimbatore area (~9 km of roads, flyover, landmarks, streaming chunks) | Working, tested |
| HUD, minimap, world map, pause menu, settings, key rebinding | Working |
| Save / load / autosave | Working, tested |
| **Art** | **Placeholder.** Truck, buildings and driver are simple shapes built in code. Realistic models and textures are the next task (see `docs/ASSETS.md`). |

Measured on the development laptop (i7-8750H, 8 GB RAM, GTX 1050 Ti, Low preset, 1280x720):
30 FPS average (the Low preset caps at 30), slowest frame 19 FPS while a chunk loads.

## Run it

1. Download Godot 4.7.2 (standard, not .NET) from godotengine.org.
2. Open `project.godot` in Godot and press F5, or export (below).

## Build the Windows .exe

1. In Godot: Editor > Manage Export Templates > Download (once).
2. Project > Export > Windows Desktop > Export Project, or from a terminal:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/IndianTruckSimulator.exe
```

The result is a single `build/IndianTruckSimulator.exe` (about 105 MB, no install needed).

## Run the tests

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_runner.tscn --fixed-fps 60
```

61 automated checks: spawn, engine, gearbox, flyover climb, braking distance, steering,
reverse, parking brake, horns, get out / walk / get in, save/load, damaged saves,
streaming, key rebinding and graphics presets. Exit code 0 means all passed.

## Benchmark and screenshots

```
IndianTruckSimulator.exe -- --bench --autodrive --frames=450 --out=C:/temp/bench.txt --shot=C:/temp/shot.png
```

Options: `--cam=chase|cockpit|foot`, `--hour=18`, `--spawn=x,z,yaw_degrees`.

## Controls (defaults, change in Settings)

W/S accelerate and brake, A/D steer, R reverse, E engine, Space parking brake, H/J/K horns,
L headlights, [ and ] indicators, T automatic/manual, Shift/Ctrl gear up/down,
C camera, F get in/out, M map, F1 help, F5 save, F9 load, Esc pause.
Gamepads work (triggers, left stick). Steering wheels show up as a joypad.

## Folder structure

```
project.godot, export_presets.cfg
scenes/            main_menu.tscn, game.tscn
scripts/autoload/  GameConfig (presets, keys, audio, theme), SaveSystem
scripts/core/      MeshBatcher (merges geometry per chunk), MeshKit (materials, helpers)
scripts/vehicle/   Truck (physics), TruckModel (visuals), HornController
scripts/player/    Driver (on foot), CameraRig
scripts/world/     CoimbatoreWorld (layout, planning), WorldStreamer, Landmarks
scripts/audio/     AudioSynth (all sounds generated in code), EngineAudio
scripts/ui/        HUD, GaugeCluster, MapView, PauseMenu, SettingsMenu, main menu
tests/             headless gameplay tests
docs/              feature report, asset plan
```

## Licences

Code: written for this project. Sounds: generated in code (no third-party audio).
Engine: Godot (MIT). All business names in the game are fictional.

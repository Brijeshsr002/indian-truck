# Feature completion report

Updated: 11 Nov 2026. "Tested" means covered by `tests/test_runner.gd` or checked in the exported game.

## Phase 1 - core playable game

| Feature | Status | Notes |
|---|---|---|
| Godot project, modular architecture | Done | Godot 4.7.2, GDScript. Unity was dropped: no licence/account wanted, and 18 GB free disk. |
| Coimbatore-inspired 3D road area | Done (placeholder art) | Avinashi Rd with flyover and median, Mettupalayam Rd, Ukkadam/Pollachi Rd, Trichy Rd, Sulur Rd, bypass, cross roads. Bus stand, temple, petrol station, mills, logistics park, level crossing, welcome arch, tea stall, yard, signals, signs, milestones. |
| Indian heavy truck | Done (placeholder art) | Original 6x4 design, right-hand drive, hollow cockpit, Vel on dashboard, HORN OK PLEASE. |
| Acceleration, steering, braking, reverse | Done, tested | 0-80 km/h, 80 km/h governor, 37.8 m stop from 80 km/h, reverse limited to 15 km/h. |
| Automatic and manual gearbox | Done, tested | 6 forward + reverse, kickdown, automatic clutch. No clutch pedal yet. |
| Chase and cockpit cameras | Done | Mouse look; spring arm avoids walls. |
| Playable driver, get in / get out | Done, tested | Finds a clear door, applies the parking brake, keeps the truck where it was. |
| Engine and horn audio | Done, tested | Live engine synthesis; 3 horns; cabin muffling. |
| Windows build | Done | Single exe, about 105 MB. Runs at 30 FPS (Low) on GTX 1050 Ti. |
| Save / load / autosave | Done, tested | JSON with safe write; damaged files are moved aside. |
| Graphics presets Low / Medium / High | Done, tested | Low is the default. |
| World streaming | Done, tested | 250 m chunks, one built per update, distant ones freed. |

## Phase 2 items started early

| Feature | Status |
|---|---|
| Three horns with H/J/K, rebinding, combined mode | Done, tested |
| Vel decoration and cabin tassels | Done (fixed, not yet a garage choice) |

## Phase 2 - realistic truck

| Feature | Status | Notes |
|---|---|---|
| Detailed Indian cab-over lorry (Blender, PBR, CC0 textures) | Done, tested | tools/blender/build_indian_lorry.py; simple model kept as a fallback. |
| Parked lorries in the yard use the new model | Done, tested | Own cab colours. |
| Windscreen wipers (V: off / slow / fast) | Done, tested | Sweep 95 degrees, park when switched off, WIPE lamp, saved in save games. |
| Correct world colours and daylight exposure | Done, tested | Vertex colours converted to linear; tone white point 6; sun, moon and headlights rebalanced. Sunlit yard and bus stand no longer render white. |
| Intermittent crash on quit | Fixed, tested | Engine sound generator is stopped before it is freed; 12 of 12 clean runs (was 2 crashes in 8). |

## Known limitations

- The world, human and trees are still simple geometry; realistic environment is Phase 3, human is Phase 7.
- No traffic, NPCs, weather or jobs yet (later phases).
- Mirrors are not reflective yet (needs extra render passes; will be a Medium/High option).
- No clutch pedal yet. Wipers work but there is no rain yet (Phase 6).
- Tamil signs use the Windows "Nirmala UI" font; on non-Windows systems they may not render.
- Steering wheels work as generic joypads; there is no force feedback or wheel setup screen yet.

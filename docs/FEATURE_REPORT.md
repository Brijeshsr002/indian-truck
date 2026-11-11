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

## Known limitations

- All art is placeholder geometry. Realistic truck, human and textures are the next task.
- No traffic, NPCs, weather or jobs yet (later phases).
- Mirrors are not reflective yet (needs extra render passes; will be a Medium/High option).
- No clutch pedal or wipers yet.
- Tamil signs use the Windows "Nirmala UI" font; on non-Windows systems they may not render.
- Steering wheels work as generic joypads; there is no force feedback or wheel setup screen yet.

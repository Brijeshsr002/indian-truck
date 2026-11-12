# Truck model credits

`indian_lorry.gltf` is an original model made for this game by the script
`tools/blender/build_indian_lorry.py` (Blender 4.5, run headless). It is inspired by
common Indian cab-over highway lorries but copies no manufacturer's design, logo or name.

Textures (all CC0, public domain, from Poly Haven, https://polyhaven.com):
- white_planks_clean: painted wooden body boards
- wood_planks: cargo deck floor
- metal_plate_02: tread plate on the steps and battery box

To rebuild the model:
  blender.exe --background --factory-startup --python tools/blender/build_indian_lorry.py -- assets/trucks/indian_lorry.gltf tools/blender/textures

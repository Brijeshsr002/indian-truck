# Asset plan (realistic art, zero budget)

Put raw downloads in `assets/incoming/` (ignored by git). Processed assets go in `assets/`.
Record every third-party asset in the table at the bottom with its licence and author.

## 1. Truck model (you download, needs a free Sketchfab account)

1. Go to sketchfab.com and log in.
2. Search: `indian truck`, `indian lorry`, `tata truck` or `ashok leyland`.
3. Filters: tick **Downloadable**. Licence: **CC0** or **CC Attribution** only.
   Avoid "Non-Commercial" and "No Derivatives" if you may ever share the game.
4. Prefer models under about 100k triangles (the laptop has 8 GB RAM), with separate wheels.
5. Download format: **glTF (.glb)**.
6. Save it to `assets/incoming/truck/` and note the author name and model URL.

Real manufacturer logos and names (Tata, Ashok Leyland, BharatBenz, Eicher) are trademarks.
They are fine for private play, but must be removed or replaced before sharing the game.

## 2. Human driver (you download, needs a free Adobe account)

1. Go to mixamo.com and log in.
2. Characters: pick a realistic adult male (for example "Remy", "Brian" or "Leonard").
3. Download the character: Format **FBX Binary**, Pose **T-pose**, With skin.
4. Animations (search each, then download with **Without Skin**, FBX, 30 fps, "In Place" ticked):
   `Idle`, `Walking`, `Running`, `Sitting Idle`, `Talking`, `Turn`.
5. Save everything to `assets/incoming/human/`.

## 3. Textures and sky (downloaded automatically, CC0, polyhaven.com)

Asphalt, soil, grass, plaster walls, concrete, brick, rusty metal and a daytime HDRI sky.
CC0 means no attribution is required; we credit Poly Haven anyway.

## Third-party assets in use

| Asset | Source | Author | Licence |
|---|---|---|---|
| Lord Murugan painting (cabin photo) | Wikimedia Commons | Raja Ravi Varma | Public domain |
| Truck horn recording (not yet in game) | BigSoundBank #2721 | Pierre Sibanarco | CC0 |

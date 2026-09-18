# Pixelhouse Zombie source archive

Downloaded from https://opengameart.org/content/zombie on 2026-09-14.
Author: pixelhouse / Pixelhouse. License: CC BY 3.0, https://creativecommons.org/licenses/by/3.0/.

`zombie-original.zip` and extracted FBX/JPG files are unmodified source resources. Keep `read first.txt` with the source. License and modification details are recorded in `game/licenses/Pixelhouse-Zombie-CC-BY-3.0.md`.

Rebuild with Blender 5.2 or newer:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/import_zombie.py
```

Run from the project root. Outputs: `art/pixelhouse_zombie.blend`, `game/assets/survival/zombie/pixelhouse_zombie.glb`, and `import-report.json`. Blender's native `bpy.ops.wm.fbx_import` supports this original FBX 6100 format. Diffuse/normal images are packed into the editable derivative and the GLB. No account, cloud asset URL, or runtime download is required.

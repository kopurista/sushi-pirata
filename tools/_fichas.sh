#!/bin/sh
cd "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
SP="C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/2dc473bd-c44d-4fea-9990-58d9c877cb32/scratchpad"
for p in "$@"; do
  f="_gen/meshy/${p}_listo.glb"
  [ -f "$f" ] || continue
  "$B" --background --python tools/blender/_v.py -- "$f" "$SP/fx_$p" >/dev/null 2>&1
  "$B" --background --python tools/blender/ver_mano.py -- "$f" "$SP/fm_$p" >/dev/null 2>&1
  echo "ficha $p"
done

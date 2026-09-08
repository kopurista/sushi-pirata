#!/bin/sh
# Acabado de cada personaje que vuelve de Meshy:
#   1. preparar_personaje.py  -> huesos al esquema del juego, escala, material,
#                                textura a 1024
#   2. david_munon.py         -> las manos a MUNON. Hace falta SIEMPRE: Meshy
#                                convierte las bolas del concepto en manos con
#                                pulgar, porque "corrige" lo que interpreta
#                                como un brazo mal reconstruido. No se puede
#                                evitar desde el prompt.
cd "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for p in "$@"; do
  src="_gen/meshy/${p}_v4_rig.glb"
  [ -f "$src" ] || { echo "[$p] sin modelo todavia"; continue; }
  "$B" --background --python tools/blender/preparar_personaje.py -- \
      "$src" "_gen/meshy/${p}_prep.glb" 2>&1 | grep -E "^\[pir\] (huesos|exportado)" | sed "s/^/[$p] /"
  "$B" --background --python tools/blender/david_munon.py -- \
      "_gen/meshy/${p}_prep.glb" "_gen/meshy/${p}_listo.glb" 2>&1 \
      | grep -E "soldado|sobresal|Taubin|exportado|sin grupo" | sed "s/^/[$p] /"
done
echo "=========== ACABADO ==========="

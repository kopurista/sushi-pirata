#!/bin/sh
# Lote v5: conceptos SIN MANOS, multi-image a maxima calidad (100k tris, 4k) + rig.
# Las esferas de las manos las pone luego tools/blender/manos_esfera.py.
cd "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
M=_gen/la4/meshy2
for p in "$@"; do
  echo "=========== $p ==========="
  python tools/meshy.py multi "${p}_v5" "$M/${p}_f.png" "$M/${p}_l.png" "$M/${p}_b.png" \
      --poly 12000 --poly-crudo 100000 --textura 4k --rig 2>&1 \
      | grep -E "Multi-image|SUCCEEDED|FAILED|bajado|LISTO|Rigging|rror|reintent"
done
echo "=========== LOTE TERMINADO ==========="

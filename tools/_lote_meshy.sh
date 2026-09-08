#!/bin/sh
# Lote de multi-image-to-3D + rig para el reparto entero.
cd "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
M=_gen/la4/meshy
for p in saverio pablo cai cai_sombrero alice miku nach kappa sirena; do
  echo "=========== $p ==========="
  python tools/meshy.py multi "${p}_v4" "$M/${p}_f.png" "$M/${p}_l.png" "$M/${p}_b.png" \
      --poly 12000 --rig 2>&1 | grep -E "Multi-image|SUCCEEDED|FAILED|bajado|LISTO|Rigging|error|Error"
done
echo "=========== LOTE TERMINADO ==========="

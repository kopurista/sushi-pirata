#!/bin/sh
# Acabado v5 de cada personaje que vuelve de Meshy (conceptos SIN manos):
#   1. preparar_personaje.py -> huesos al esquema del juego, escala, material,
#                               textura a 1024 (los ojos ya vienen del concepto)
#   2. gafas_cerrar.py       -> solo MIKU: le cierra los aros de las gafas
#   3. manos_esfera.py       -> la ESFERA en cada muñeca
#   4. rebake.py             -> decimado en Blender + atlas nuevo + horneado
#   5. _v.py + ver_mano.py   -> fichas de comprobacion en _gen/la4/fichas
cd "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for p in "$@"; do
  src="_gen/meshy/${p}_v5_rig.glb"
  [ -f "$src" ] || { echo "[$p] sin modelo todavia"; continue; }
  "$B" --background --python tools/blender/preparar_personaje.py -- \
      "$src" "_gen/meshy/${p}_v5_prep.glb" 2>&1 \
      | grep -E "^\[pir\] (huesos|exportado|sin ojos)" | sed "s/^/[$p] /"

  ENTRADA="_gen/meshy/${p}_v5_prep.glb"
  # (Miku llevo un paso propio, `gafas_cerrar.py`, cuando Meshy le dejo los
  # aros a medias. Ya no hace falta: regenerada, salen completos. La
  # herramienta se queda por si vuelve a pasar.)

  # PABLO lleva su PUÑAL en la muñeca izquierda en vez de esfera.
  if [ "$p" = "pablo" ]; then
    export ESFERA_HOJA=L ESFERA_PUNAL=assets/models/source/punal_pablo3.glb
  else
    unset ESFERA_HOJA ESFERA_PUNAL
  fi
  # LA SIRENA: su rig pone las muñecas dentro de la melena, asi que la bola se
  # coloca por GEOMETRIA (la punta del brazo) y el color se saca de la carne.
  # Casos con la bola MEDIDA A MANO, porque su rig no dice donde esta la mano:
  #  · la SIRENA: sus muñecas caen a la altura del pecho, dentro de la melena.
  #  · el KAPPA: su rig apenas pesa en la muñeca (157 vertices), asi que la
  #    bola le quedaba colgando AL LADO de su mano de verdad — se le veian las
  #    dos, como si sujetara una pelota.
  # Los sitios salen de medir la malla, no de mirar el render.
  unset ESFERA_POS_L ESFERA_POS_R ESFERA_R_FIJO ESFERA_COLOR_DE ESFERA_PLANO_POS ESFERA_ALCANCE_POS MANO_SOLDAR MANO_SUAVIZA ESFERA_UV
  unset ESFERA_RADIO
  # EL CHEF LLEVA LA BOLA MAS PEQUEÑA: su concepto trae las mangas remangadas,
  # asi que el antebrazo se ve entero y una bola del tamaño del brazo se leia
  # como un guante de boxeo (lo dijo el usuario). Los demas van con manga
  # larga y ahi la bola tiene que tapar la boca de la tela.
  if [ "$p" = "chef" ]; then export ESFERA_RADIO=0.86; fi
  if [ "$p" = "sirena" ]; then
    export ESFERA_POS_L="0.114,-0.016,0.514" ESFERA_POS_R="-0.111,-0.010,0.512"
    export ESFERA_R_FIJO=0.030 ESFERA_COLOR_DE=carne
  fi
  if [ "$p" = "kappa" ]; then
    export ESFERA_POS_L="0.335,-0.030,-0.198" ESFERA_POS_R="-0.335,-0.030,-0.198"
    export ESFERA_R_FIJO=0.080 ESFERA_PLANO_POS=1.0 ESFERA_ALCANCE_POS=2.2
    # su bola cae pegada al caparazon, asi que el texel se fuerza: si no, se
    # lleva uno de la concha y la mano sale GRANATE
    export ESFERA_UV="0.4963,0.103"
    # solo el Kappa necesita soldar y alisar: su mano de origen tiene pulgar y
    # hay que fundirla en la bola. En los demas, tocar la malla no hace falta
    # y encima deja marcas en la piel.
    export MANO_SOLDAR=1 MANO_SUAVIZA=6
  fi

  "$B" --background --python tools/blender/manos_esfera.py -- \
      "$ENTRADA" "_gen/meshy/${p}_v5_listo.glb" 2>&1 \
      | grep -E "^\[esfera\]" | sed "s/^/[$p] /"
  # LA SIRENA: el rig de Meshy le metio la MELENA en el grupo de las muñecas
  # (22.000 vertices por lado) y al comer el pelo salia volando de lado; se
  # pasa a Head/Spine1 lo que quede a mas de 0.12 del hueso (5-9-2026).
  if [ "$p" = "sirena" ]; then
    "$B" --background --python tools/blender/pesos_lejos.py -- \
        "_gen/meshy/${p}_v5_listo.glb" "_gen/meshy/${p}_v5_pelo.glb" \
        "L_Wrist,R_Wrist,L_Elbow,R_Elbow" 0.12 2>&1 | grep "^.pesos." | sed "s/^/[$p] /"
    mv -f "_gen/meshy/${p}_v5_pelo.glb" "_gen/meshy/${p}_v5_listo.glb"
  fi
  # EL KAPPA: su rig de Blender deja el armature a z=+0.5 y en Godot la caja
  # del modelo sale medio metro por encima de la piel (el retrato del dialogo
  # encuadraba el aire). El armature se aplica al origen (5-9-2026).
  if [ "$p" = "kappa" ]; then
    "$B" --background --python tools/blender/rig_al_origen.py -- \
        "_gen/meshy/${p}_v5_listo.glb" "_gen/meshy/${p}_v5_origen.glb" 2>&1 | grep "^.origen." | sed "s/^/[$p] /"
    mv -f "_gen/meshy/${p}_v5_origen.glb" "_gen/meshy/${p}_v5_listo.glb"
  fi
  # RE-HORNEADO (7-9-2026): decimar en Blender y hornear la textura sobre un
  # atlas limpio. Es lo que quita las MANCHAS: el decimador de Godot fundia
  # vertices a traves de las costuras del atlas de Meshy (1659 motas contra
  # 468 asi). Va al final, sobre el modelo ya con manos, pelo y origen.
  "$B" --background --python tools/blender/rebake.py -- \
      "_gen/meshy/${p}_v5_listo.glb" "_gen/meshy/${p}_v5_horneado.glb" 14000 1024 2>&1 \
      | grep -E "^.rebake." | sed "s/^/[$p] /"
  [ -f "_gen/meshy/${p}_v5_horneado.glb" ] && mv -f "_gen/meshy/${p}_v5_horneado.glb" "_gen/meshy/${p}_v5_listo.glb"
  "$B" --background --python tools/blender/_v.py -- \
      "_gen/meshy/${p}_v5_listo.glb" "_gen/la4/fichas/${p}_v5.png" >/dev/null 2>&1
  "$B" --background --python tools/blender/ver_mano.py -- \
      "_gen/meshy/${p}_v5_listo.glb" "_gen/la4/fichas/${p}_v5_mano.png" >/dev/null 2>&1
  python tools/_ficha_grande.py "$p" >/dev/null
done
echo "=========== ACABADO ==========="

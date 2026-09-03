# Prepara el TALLER: un .blend con David y Gigi cargados, y lo abre en Blender
# con el servidor del MCP en marcha, para trabajar en vivo mientras el usuario
# mira lo que se toca.
#
#   python tools/blender/abrir_david.py            (prepara y abre)
#
# El .blend se monta en SEGUNDO PLANO y luego se abre: importar un .glb desde
# el script de arranque de la interfaz revienta con "Context object has no
# attribute 'object'" (el importador pide un objeto activo y ahí todavía no hay
# ventana), y ni un temporizador ni vaciar la escena lo arreglan.
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLENDER = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
TALLER = os.path.join(ROOT, "_gen", "david_taller.blend")

MONTAR = r'''
import bpy, os
ROOT = r"%s"
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "david_toy.glb"))
for o in bpy.context.scene.objects:
    o.name = "David_" + o.name
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "gigi_toy.glb"))
for o in bpy.context.scene.objects:
    if not o.name.startswith("David_"):
        o.name = "Gigi_" + o.name
        if o.parent is None:
            o.location.x = 1.1
for o in list(bpy.context.scene.objects):
    if o.type == "CAMERA" or o.type == "LIGHT":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=r"%s")
print("[taller] guardado", [o.name for o in bpy.context.scene.objects])
''' % (ROOT, TALLER)

ARRANQUE = r'''
import bpy
def ir():
    for area in bpy.context.screen.areas:
        if area.type != "VIEW_3D":
            continue
        for sp in area.spaces:
            if sp.type == "VIEW_3D":
                sp.shading.type = "SOLID"
                sp.shading.color_type = "TEXTURE"
                sp.shading.show_specular_highlight = True
        win = [r for r in area.regions if r.type == "WINDOW"][0]
        with bpy.context.temp_override(area=area, region=win):
            bpy.ops.view3d.view_axis(type="FRONT")
            bpy.ops.view3d.view_all()
    try:
        bpy.ops.preferences.addon_enable(module="blender_mcp")
        bpy.ops.blendermcp.start_server()
        print("[taller] servidor MCP en marcha")
    except Exception as e:
        print("[taller] servidor:", e)
    return None
bpy.app.timers.register(ir, first_interval=1.0)
'''

if __name__ == "__main__":
    prep = os.path.join(os.path.dirname(TALLER), "_montar.py")
    ini = os.path.join(os.path.dirname(TALLER), "_arranque.py")
    open(prep, "w", encoding="utf-8").write(MONTAR)
    open(ini, "w", encoding="utf-8").write(ARRANQUE)
    subprocess.run([BLENDER, "--background", "--python", prep], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("taller:", TALLER, os.path.exists(TALLER))
    subprocess.Popen([BLENDER, TALLER, "--python", ini])

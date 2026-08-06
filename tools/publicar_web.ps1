# Publica el build web de Sushi Pirata en GitHub Pages de un tirón:
# importa, exporta, comprueba tamaños, copia al repositorio de publicación y
# hace commit y push.
#
#   powershell -File tools/publicar_web.ps1
#   powershell -File tools/publicar_web.ps1 -Mensaje "Nivel 6 y tienda nueva"
#
# El repositorio de publicación (sushi-pirata-web) es SOLO para los archivos
# generados: se mantiene aparte para que los 100+ MB de binarios no entren en el
# historial del repositorio de código, donde se quedarían para siempre.

param(
    [string]$Mensaje = "",
    # Con -SoloExportar prepara el build y NO sube nada, para revisarlo antes.
    [switch]$SoloExportar
)

$ErrorActionPreference = "Stop"

$Godot    = "C:/Users/KOPURISTA/Desktop/GODOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
$Proyecto = "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
$Salida   = "$Proyecto/sushiBeta/nuevo"
$Repo     = "C:/Users/KOPURISTA/Desktop/GODOT/sushi-pirata-web"

# GitHub RECHAZA cualquier archivo de más de 100 MB y avisa a partir de 50 MB.
$LimiteBloqueo = 100MB
$LimiteAviso   = 50MB

# Lo que no se borra del repositorio de publicación al renovar el build.
# OJO con `.github`: ahí vive el flujo de trabajo que publica en Pages. La
# primera versión de este script no lo incluía, se lo llevó por delante al
# vaciar la carpeta, y el build se subió sin que nada lo desplegara: el sitio
# se quedó sirviendo la versión anterior sin dar ningún error.
$Conservar = @(".git", ".github", ".nojekyll", "README.md")


function Paso($texto) {
    Write-Host ""
    Write-Host "==> $texto" -ForegroundColor Cyan
}

foreach ($ruta in @($Godot, $Proyecto, $Repo)) {
    if (-not (Test-Path $ruta)) { throw "No existe: $ruta" }
}

# --------------------------------------------------------------- 1. importar
# Hace falta porque el decimado de modelos (import_hooks/decimate_import.gd)
# corre en la importación, y porque un script nuevo con class_name no existe
# hasta que se importa.
Paso "Importando recursos"
& $Godot --headless --import --path $Proyecto | Out-Null

# --------------------------------------------------------------- 2. exportar
Paso "Exportando a web (release)"
if (Test-Path $Salida) { Remove-Item $Salida -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
& $Godot --headless --path $Proyecto --export-release "sushi" "$Salida/index.html" | Out-Null

if (-not (Test-Path "$Salida/index.pck")) {
    throw "La exportación no ha generado index.pck. Revisa las plantillas de exportación."
}

# --------------------------------------------------- 3. comprobar tamaños
Paso "Comprobando tamaños"
$total = 0
$bloquea = $false
foreach ($f in Get-ChildItem $Salida -File | Sort-Object Length -Descending) {
    $total += $f.Length
    if ($f.Length -gt $LimiteAviso) {
        $mb = [math]::Round($f.Length / 1MB, 2)
        if ($f.Length -gt $LimiteBloqueo) {
            Write-Host ("   $mb MB  $($f.Name)  <-- GitHub RECHAZARA este archivo") -ForegroundColor Red
            $bloquea = $true
        } else {
            Write-Host ("   $mb MB  $($f.Name)  (aviso, pero se sube)") -ForegroundColor Yellow
        }
    }
}
Write-Host ("   total de la descarga: {0:N1} MB" -f ($total / 1MB))
if ($bloquea) {
    throw "Hay archivos por encima de 100 MB: GitHub los rechaza. Adelgaza el paquete antes de publicar."
}

if ($SoloExportar) {
    Write-Host ""
    Write-Host "Listo en $Salida (no se ha subido nada)." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------- 4. copiar al repositorio
# Se vacía primero para que los archivos de un build viejo que ya no existan no
# se queden colgados en la publicación.
Paso "Copiando al repositorio de publicación"
Get-ChildItem $Repo -Force | Where-Object { $Conservar -notcontains $_.Name } |
    Remove-Item -Recurse -Force
Copy-Item "$Salida/*" $Repo -Recurse -Force

# ------------------------------------------------------- 5. commit y push
Paso "Publicando"
git -C $Repo add -A
if ((git -C $Repo status --porcelain).Count -eq 0) {
    Write-Host "   No hay cambios respecto a lo ya publicado." -ForegroundColor Yellow
    exit 0
}

if ($Mensaje -eq "") {
    $Mensaje = "Build web {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm")
}
git -C $Repo commit -m $Mensaje | Out-Null
git -C $Repo push origin main
if ($LASTEXITCODE -ne 0) { throw "El push ha fallado." }

Write-Host ""
Write-Host "Publicado: https://kopurista.github.io/sushi-pirata-web/" -ForegroundColor Green
Write-Host "GitHub Pages tarda uno o dos minutos en servir la version nueva."
Write-Host "En el iPhone, borra el icono de la pantalla de inicio y vuelve a"
Write-Host "anadirlo si ves la version antigua: el service worker cachea."

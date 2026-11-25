# Crea el instalador de Windows (target\windows\Reproductor-<versión>-instalador.exe).
#
#   powershell -ExecutionPolicy Bypass -File scripts\crear-instalador-windows.ps1
#   ... -SinDescargas -Dependencias C:\ruta   # usa mpv, yt-dlp y deno de esa carpeta
#   ... -ConFfmpeg                            # añade ffmpeg (solo para la carátula animada)
#   ... -Instalar                             # al terminar, abre el instalador
#
# Necesita (ver COMPILAR.md): Rust con el destino MSVC, Visual Studio Build Tools (C++), Qt 6.8+
# para MSVC con Qt Multimedia e Inno Setup 6. mpv, yt-dlp y deno se descargan de sus
# publicaciones oficiales en GitHub, y el Python embebido de python.org (para el yt-dlp
# residente); todo va dentro del instalador.
param(
    [switch]$SinDescargas,
    [string]$Dependencias = "",
    [switch]$ConFfmpeg,
    [switch]$Instalar
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest va mucho más rápido sin barra
Set-Location (Join-Path $PSScriptRoot "..")

function Falta($que, $como) {
    Write-Host "Falta $que. $como" -ForegroundColor Red
    Write-Host "Ver COMPILAR.md, sección Windows."
    exit 1
}

function Buscar($programa, $rutas) {
    $comando = Get-Command $programa -ErrorAction SilentlyContinue
    if ($comando) { return $comando.Source }
    foreach ($ruta in $rutas) {
        $encontrada = Get-Item $ruta -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($encontrada) { return $encontrada.FullName }
    }
    return $null
}

# --- Herramientas ---------------------------------------------------------------------------

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Falta "Rust (cargo)" "Instálalo con rustup: https://rustup.rs"
}
# Qt 6.9 o superior (RectangularShadow); si hay varios en C:\Qt, el más nuevo.
$qmake = if ($env:QMAKE) { $env:QMAKE } else {
    Get-ChildItem "C:\Qt\6.*\msvc*_64\bin\qmake6.exe" -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.FullName -replace '^C:\\Qt\\([0-9.]+)\\.*$', '$1') } -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $qmake) { $qmake = Buscar "qmake6" @() }
if (-not $qmake) { $qmake = Buscar "qmake" @() }
if (-not $qmake) { Falta "Qt 6 para MSVC (qmake6)" "Instálalo con el instalador de Qt o indica su ruta en la variable QMAKE." }
$env:QMAKE = $qmake
$qtBin = Split-Path $qmake
$windeployqt = Join-Path $qtBin "windeployqt.exe"
if (-not (Test-Path $windeployqt)) { $windeployqt = Join-Path $qtBin "windeployqt6.exe" }
if (-not (Test-Path $windeployqt)) { Falta "windeployqt" "Debería estar junto a qmake ($qtBin)." }
$iscc = Buscar "ISCC" @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
if (-not $iscc) { Falta "Inno Setup 6" "Instálalo con: winget install JRSoftware.InnoSetup" }

# --- Compilar -------------------------------------------------------------------------------

Write-Host "› Compilando en modo release (Qt: $qtBin)…"
cargo build --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$version = (Select-String -Path Cargo.toml -Pattern '^version = "(.*)"' | Select-Object -First 1).Matches[0].Groups[1].Value
$origen = Join-Path (Get-Location) "target\windows\Reproductor"
if (Test-Path $origen) { Remove-Item $origen -Recurse -Force }
New-Item -ItemType Directory -Force $origen | Out-Null
Copy-Item target\release\musicplayer.exe, target\release\musicplayer-login.exe $origen

Write-Host "› Copiando Qt (windeployqt)…"
# --qmldir: windeployqt mira qué módulos de QML importa la interfaz y copia solo esos.
& $windeployqt --release --qmldir qml --no-translations --no-system-d3d-compiler --no-opengl-sw (Join-Path $origen "musicplayer.exe")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --- mpv, yt-dlp y deno ---------------------------------------------------------------------

$descargas = Join-Path (Get-Location) "target\windows\descargas"
New-Item -ItemType Directory -Force $descargas | Out-Null

function Ultima($repositorio, $patron) {
    $publicacion = Invoke-RestMethod "https://api.github.com/repos/$repositorio/releases/latest" -Headers @{ "User-Agent" = "musicplayer-build" }
    $recurso = $publicacion.assets | Where-Object { $_.name -match $patron } | Select-Object -First 1
    if (-not $recurso) { throw "No hay ningún archivo «$patron» en la última publicación de $repositorio." }
    return $recurso
}

function Descargar($recurso) {
    $destino = Join-Path $descargas $recurso.name
    if (-not (Test-Path $destino)) {
        Write-Host "  descargando $($recurso.name)…"
        Invoke-WebRequest $recurso.browser_download_url -OutFile $destino
    }
    return $destino
}

function Extraer7z($archivo, $carpeta) {
    New-Item -ItemType Directory -Force $carpeta | Out-Null
    # El tar de Windows 11 (libarchive) lee .7z; si no, 7-Zip. Sus errores no paran el script.
    $antes = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    tar -xf $archivo -C $carpeta 2>$null
    $ErrorActionPreference = $antes
    if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $carpeta "mpv.exe"))) { return }
    $sieteZip = Buscar "7z" @("$env:ProgramFiles\7-Zip\7z.exe")
    if (-not $sieteZip) { Falta "7-Zip para abrir $archivo" "Instálalo con: winget install 7zip.7zip" }
    & $sieteZip x -y "-o$carpeta" $archivo | Out-Null
}

# Python embebido con el yt-dlp en script (`yt-dlp.zip`, en el `._pth`): el yt-dlp residente
# (src/daemon.rs). Sin él, cada pista que no da la vía rápida lanza yt-dlp.exe entero (~7 s).
function PrepararPython($zip, $ytdlp) {
    $carpeta = Join-Path $origen "python"
    Expand-Archive $zip -DestinationPath $carpeta -Force
    Copy-Item $ytdlp (Join-Path $carpeta "yt-dlp.zip")
    $pth = Get-ChildItem $carpeta -Filter "python*._pth" | Select-Object -First 1
    if (-not $pth) { throw "El Python embebido no trae su archivo ._pth." }
    $biblioteca = ($pth.BaseName) + ".zip"
    Set-Content $pth.FullName "$biblioteca`r`n.`r`nyt-dlp.zip" -Encoding ascii
}

if ($SinDescargas) {
    if (-not $Dependencias) { Falta "-Dependencias <carpeta>" "Con -SinDescargas, indica la carpeta con mpv.exe, yt-dlp.exe y deno.exe." }
    foreach ($programa in @("mpv.exe", "yt-dlp.exe", "deno.exe")) {
        $ruta = Join-Path $Dependencias $programa
        if (-not (Test-Path $ruta)) { Falta $programa "No está en $Dependencias." }
        Copy-Item $ruta $origen
    }
    # Opcionales: el zip del Python embebido y el yt-dlp en script (sin ellos, no hay residente).
    $pythonZip = Get-ChildItem $Dependencias -Filter "python-*-embed-amd64.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    $ytdlpScript = Join-Path $Dependencias "yt-dlp"
    if ($pythonZip -and (Test-Path $ytdlpScript)) {
        PrepararPython $pythonZip.FullName $ytdlpScript
    } else {
        Write-Host "  sin python-*-embed-amd64.zip y yt-dlp en ${Dependencias}: no habrá yt-dlp residente" -ForegroundColor Yellow
    }
    foreach ($opcional in @("ffmpeg.exe", "ffprobe.exe")) {
        $ruta = Join-Path $Dependencias $opcional
        if ($ConFfmpeg -and (Test-Path $ruta)) { Copy-Item $ruta $origen }
    }
} else {
    Write-Host "› Descargando mpv, yt-dlp, deno y Python…"
    # mpv: compilación de shinchiro (la que enlaza mpv.io); la versión x86_64 normal, que va en
    # cualquier procesador de 64 bits (la «v3» exige AVX2).
    $mpv = Descargar (Ultima "shinchiro/mpv-winbuild-cmake" '^mpv-x86_64-\d{8}-git-[0-9a-f]+\.7z$')
    $mpvCarpeta = Join-Path $descargas "mpv"
    Extraer7z $mpv $mpvCarpeta
    Copy-Item (Join-Path $mpvCarpeta "mpv.exe") $origen

    $ytdlp = Descargar (Ultima "yt-dlp/yt-dlp" '^yt-dlp\.exe$')
    Copy-Item $ytdlp $origen

    # El Python embebido más reciente de python.org (la carpeta de una versión aparece antes que
    # sus archivos: se usa la primera que ya tiene el zip) y el yt-dlp en script.
    $indice = (Invoke-WebRequest "https://www.python.org/ftp/python/" -UseBasicParsing).Content
    $versiones = [regex]::Matches($indice, 'href="(3\.\d+\.\d+)/"') | ForEach-Object { [version]$_.Groups[1].Value } |
        Where-Object { $_ -ge [version]"3.10" } | Sort-Object -Descending
    $pythonZip = $null
    foreach ($v in $versiones | Select-Object -First 6) {
        $nombre = "python-$v-embed-amd64.zip"
        $destino = Join-Path $descargas $nombre
        if (-not (Test-Path $destino)) {
            try {
                Write-Host "  descargando $nombre…"
                Invoke-WebRequest "https://www.python.org/ftp/python/$v/$nombre" -OutFile $destino
            } catch { Remove-Item $destino -ErrorAction SilentlyContinue; continue }
        }
        $pythonZip = $destino
        break
    }
    if (-not $pythonZip) { throw "No se encontró el Python embebido en python.org." }
    $ytdlpScript = Descargar (Ultima "yt-dlp/yt-dlp" '^yt-dlp$')
    PrepararPython $pythonZip $ytdlpScript

    $deno = Descargar (Ultima "denoland/deno" '^deno-x86_64-pc-windows-msvc\.zip$')
    Expand-Archive $deno -DestinationPath (Join-Path $descargas "deno") -Force
    Copy-Item (Join-Path $descargas "deno\deno.exe") $origen

    if ($ConFfmpeg) {
        $ffmpeg = Descargar (Ultima "BtbN/FFmpeg-Builds" '^ffmpeg-master-latest-win64-gpl\.zip$')
        Expand-Archive $ffmpeg -DestinationPath (Join-Path $descargas "ffmpeg") -Force
        Get-ChildItem (Join-Path $descargas "ffmpeg") -Recurse -Include ffmpeg.exe, ffprobe.exe | Copy-Item -Destination $origen
    }
}

# --- Instalador -----------------------------------------------------------------------------

Write-Host "› Creando el instalador (Inno Setup)…"
& $iscc /Q "/DVersion=$version" "/DOrigen=$origen" scripts\windows\reproductor.iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$instalador = Join-Path (Get-Location) "target\windows\Reproductor-$version-instalador.exe"
$megas = [math]::Round((Get-Item $instalador).Length / 1MB)
Write-Host "Listo: $instalador ($megas MB)" -ForegroundColor Green
if ($Instalar) { Start-Process $instalador }

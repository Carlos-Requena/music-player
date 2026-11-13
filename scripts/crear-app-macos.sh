#!/usr/bin/env bash
# Crea «Reproductor.app» y, salvo que se pida lo contrario, la instala en /Applications.
#
#   scripts/crear-app-macos.sh                  # compila, crea la app y la instala
#   scripts/crear-app-macos.sh --independiente  # copia Qt dentro de la app (no depende de Homebrew)
#   scripts/crear-app-macos.sh --sin-instalar   # deja la app en target/ sin instalarla
#   scripts/crear-app-macos.sh --destino ~/Applications
set -euo pipefail

cd "$(dirname "$0")/.."

INDEPENDIENTE=0
INSTALAR=1
DESTINO="/Applications"
while [ $# -gt 0 ]; do
    case "$1" in
        --independiente) INDEPENDIENTE=1 ;;
        --sin-instalar) INSTALAR=0 ;;
        --destino) DESTINO="$2"; shift ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; exit 1 ;;
    esac
    shift
done

for programa in cargo qmake6 mpv yt-dlp; do
    if ! command -v "$programa" >/dev/null 2>&1; then
        echo "Falta «$programa». Instala las dependencias (ver COMPILAR.md):" >&2
        echo "  brew install rust qtbase qtdeclarative qtshadertools mpv yt-dlp deno" >&2
        exit 1
    fi
done

echo "› Compilando en modo release…"
cargo build --release

VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
APP="target/Reproductor.app"
echo "› Creando $APP (versión $VERSION)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp target/release/musicplayer "$APP/Contents/MacOS/musicplayer"
cp assets/icon.icns "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Reproductor</string>
    <key>CFBundleDisplayName</key><string>Reproductor de música</string>
    <key>CFBundleIdentifier</key><string>local.musicplayer</string>
    <key>CFBundleExecutable</key><string>musicplayer</string>
    <key>CFBundleIconFile</key><string>icon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

if [ "$INDEPENDIENTE" = 1 ]; then
    echo "› Copiando Qt dentro de la app (macdeployqt)…"
    # Algunos módulos QML de Homebrew enlazan QtSvg, que vive fuera de qtbase.
    LIBS=()
    for formula in qtsvg qtdeclarative qtbase; do
        prefijo=$(brew --prefix "$formula" 2>/dev/null || true)
        [ -n "$prefijo" ] && [ -d "$prefijo/lib" ] && LIBS+=("-libpath=$prefijo/lib")
    done
    macdeployqt "$APP" -qmldir=qml -always-overwrite "${LIBS[@]}"
fi

# Apple Silicon exige firma; una firma local («ad hoc») basta para usarla en este Mac.
echo "› Firmando la app (firma local)…"
codesign --force --deep --sign - "$APP"

if [ "$INSTALAR" = 1 ]; then
    echo "› Instalando en $DESTINO…"
    mkdir -p "$DESTINO"
    rm -rf "$DESTINO/Reproductor.app"
    ditto "$APP" "$DESTINO/Reproductor.app"
    echo "Listo: abre «Reproductor de música» desde Launchpad o $DESTINO."
else
    echo "Listo: $APP"
fi

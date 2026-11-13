#!/usr/bin/env bash
# Compila e instala el reproductor para tu usuario en Linux (probado para Arch/CachyOS).
#
#   scripts/instalar-linux.sh                # compila e instala en ~/.local
#   scripts/instalar-linux.sh --dependencias # instala antes las dependencias con pacman (pide sudo)
#   scripts/instalar-linux.sh --desinstalar
set -euo pipefail

cd "$(dirname "$0")/.."

PREFIJO="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
# qt6-webengine: la ventana de inicio de sesión (musicplayer-login). Sin él la app funciona y
# se puede importar la sesión del navegador.
DEPENDENCIAS=(base-devel rust qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-webengine mpv yt-dlp deno)

case "${1:-}" in
    --desinstalar)
        rm -f "$BIN/musicplayer" "$BIN/musicplayer-login" \
              "$PREFIJO/applications/musicplayer.desktop" \
              "$PREFIJO/icons/hicolor/scalable/apps/musicplayer.svg"
        command -v update-desktop-database >/dev/null && update-desktop-database "$PREFIJO/applications" || true
        echo "Desinstalado. Tus preferencias siguen en ~/.config/musicplayer (bórralas si quieres)."
        exit 0
        ;;
    --dependencias)
        sudo pacman -S --needed "${DEPENDENCIAS[@]}"
        ;;
    "") ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
esac

faltan=()
for programa in cargo qmake6 mpv yt-dlp; do
    command -v "$programa" >/dev/null 2>&1 || faltan+=("$programa")
done
if [ ${#faltan[@]} -gt 0 ]; then
    echo "Faltan: ${faltan[*]}. Instala las dependencias con:" >&2
    echo "  sudo pacman -S --needed ${DEPENDENCIAS[*]}" >&2
    echo "o ejecuta: scripts/instalar-linux.sh --dependencias" >&2
    exit 1
fi
if ! command -v deno >/dev/null 2>&1 && ! command -v node >/dev/null 2>&1; then
    echo "Aviso: yt-dlp necesita deno o Node.js para YouTube (sudo pacman -S deno)." >&2
fi

echo "› Compilando en modo release…"
# cxx-qt localiza Qt con qmake; en Arch el de Qt 6 se llama qmake6.
QMAKE="${QMAKE:-$(command -v qmake6)}" cargo build --release

echo "› Instalando en ~/.local…"
install -Dm755 target/release/musicplayer "$BIN/musicplayer"
# Ventana de inicio de sesión, solo si se compiló con Qt WebEngine.
if target/release/musicplayer-login --check; then
    install -Dm755 target/release/musicplayer-login "$BIN/musicplayer-login"
else
    rm -f "$BIN/musicplayer-login"
    echo "Aviso: sin qt6-webengine no hay ventana de inicio de sesión; podrás importar la sesión del navegador." >&2
    echo "       Para tenerla: sudo pacman -S qt6-webengine y vuelve a ejecutar este script." >&2
fi
install -Dm644 assets/icon.svg "$PREFIJO/icons/hicolor/scalable/apps/musicplayer.svg"
install -Dm644 /dev/stdin "$PREFIJO/applications/musicplayer.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Reproductor de música
GenericName=Reproductor de YouTube Music
Comment=Cliente ligero de YouTube Music
Exec=$BIN/musicplayer
Icon=musicplayer
Terminal=false
Categories=AudioVideo;Audio;Music;Player;
Keywords=música;youtube;reproductor;letras;
StartupWMClass=musicplayer
EOF
command -v update-desktop-database >/dev/null && update-desktop-database "$PREFIJO/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$PREFIJO/icons/hicolor" || true

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "Aviso: $BIN no está en tu PATH; añádelo para lanzar «musicplayer» desde la terminal." ;;
esac
echo "Listo: busca «Reproductor de música» en el menú de aplicaciones o ejecuta musicplayer."

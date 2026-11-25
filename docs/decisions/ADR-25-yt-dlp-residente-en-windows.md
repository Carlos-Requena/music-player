---
adr: ADR-25
titulo: yt-dlp residente también en Windows, con un Python embebido en el instalador
estado: aceptada
fecha: 2026-11-22
areas: [resolucion]
---

# ADR-25 · yt-dlp residente también en Windows, con un Python embebido en el instalador

- **Estado:** Aceptada. Amplía [ADR-24](ADR-24-version-de-windows.md) y lleva
  [ADR-08](ADR-08-yt-dlp-residente.md) a Windows.
- **Registrada:** 2026-11-22
- **Ámbito:** [resolucion](../areas/resolucion.md)

## Decisión

- El instalador de Windows lleva, en `{app}\python\`, el **Python embebido** oficial de python.org
  (el más reciente que ya tenga su `python-X.Y.Z-embed-amd64.zip`) y el **yt-dlp en script** (el
  archivo `yt-dlp` de su publicación, guardado como `yt-dlp.zip`). El `python*._pth` se reescribe
  con la biblioteca de Python, `.` y `yt-dlp.zip`, así que `import yt_dlp` funciona sin instalar
  nada. Lo prepara `PrepararPython` en `scripts/crear-instalador-windows.ps1`.
- `daemon::interpreter` en Windows usa el primer `python\python.exe` con `yt-dlp.zip` al lado que
  encuentre en las carpetas de `audio::search_path` (la del programa y la de la app instalada, que
  sirve también a `target\debug\musicplayer.exe`). El residente es el mismo `ytdlp_daemon.py`.
- `yt-dlp.exe` sigue en el instalador: lo usan el gancho de yt-dlp de mpv y el resolver cuando no
  hay residente (desactivado en Opciones o sin `python\`).
- Lo eligió el propietario (opción «A» de tres).

## Alternativas descartadas

- **yt-dlp en carpeta (`yt-dlp_win.zip`)** en vez del `.exe` de un archivo: ahorra la
  descompresión de cada arranque, pero sigue siendo un proceso por pista (calculado en 4–5 s, sin
  medir).
- **No hacer nada y usar la calidad «Alta»** en Windows: la vía rápida da ~0,1 s, pero Premium
  (256 kbps) solo llega con yt-dlp y la sesión.

## Motivo

Con la calidad Premium y la sesión iniciada, cada pista va primero a yt-dlp. En Windows no había
residente y cada pista lanzaba `yt-dlp.exe`, que descomprime su Python en cada arranque y el
antivirus lo revisa. Medidas del 2026-11-22 en el PC del propietario (Windows 11, release, sin
sesión, clientes `web_embedded,mweb`):

| Vía | Por pista |
|---|---|
| `yt-dlp.exe --version` (solo arrancar) | 2,6–2,7 s |
| `yt-dlp.exe`, un proceso por pista | 7,2–7,8 s |
| Residente con Python 3.15.2 embebido (`--probe resolve`) | 4,8 s la primera (arranca el residente); 2,4–2,5 s las siguientes |

## Consecuencias

- El instalador crece unos 16 MB (Python embebido ~13 MB y yt-dlp en script ~3 MB).
- El residente ocupa ~77 MB mientras vive (60 MB privados; medido el 2026-11-22) y se cierra tras
  un minuto sin uso, como en macOS y Linux.
- Actualizar yt-dlp en Windows es crear un instalador nuevo: se descargan los dos yt-dlp.
- Con `-SinDescargas`, el residente solo existe si la carpeta de `-Dependencias` trae
  `python-*-embed-amd64.zip` y `yt-dlp`.

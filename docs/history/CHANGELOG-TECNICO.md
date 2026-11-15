# Changelog técnico

Cómo llegó el reproductor a su estado actual. **Es un registro**: no describe la app de hoy (para
eso, [ARCHITECTURE](../ARCHITECTURE.md) y las [fichas](../areas/)). Lo nuevo va arriba en cada
tabla.

---

## Cronología

| Fecha | Cambio | Commit |
|---|---|---|
| 2026-11-15 | Documentación reestructurada como en Quests (ADR-16): normas en `docs/AGENTES.md`, una ficha por área en `docs/areas/`, ADR, runbooks, `TRAMPAS.md`, historial aparte, `EN-CURSO.md` y `scripts/docs.py` para comprobarla. `AGENTS.md` y `CLAUDE.md` pasan a señalar la guía; el contenido de áreas de `ARCHITECTURE.md` pasa a las fichas | — |
| 2026-11-14 | Registro de escuchas con `c=WEB_REMIX` y `cver`: las escuchas iban al historial de YouTube y no al de YouTube Music | sin commit al registrarlo |
| 2026-11-14 | Mejoras varias y calidad de vida; letra al estilo Better Lyrics con tres calidades | `286d5b2`, `6064993` |
| 2026-11-13 | Versión 1.0: arreglos finales y de Linux | `14996f2`, `b2c4dbd`, `6565585` |
| 2026-11-13 | Primeras versiones: vistas, reproducción con mpv y yt-dlp, vía rápida, precarga, letra, sesión, plugins | `e25bd36` … `a628202` |

## Medidas sustituidas

Medidas que estuvieron en los documentos vigentes y que ya no describen la app.

| Fecha | Qué | Medida | Por qué ya no vale |
|---|---|---|---|
| 2026-11-13 | Clic hasta oír audio con el gancho de yt-dlp de mpv | 8,2–9,5 s (~12 s si YouTube rechazaba la URL) | yt-dlp propio y después la vía rápida (ADR-03); el gancho queda como plan B |
| 2026-11-13 | Clic hasta oír audio con yt-dlp propio, sin precarga | ~4 s | La vía rápida (ADR-03) |
| 2026-11-14 | Letra anterior a la de Better Lyrics: CPU en 25 s y memoria | 1,4 s · 241 MB | Letra nueva con tres modos ([letra](../areas/letra.md#medidas)) |
| 2026-11-13 | mpv en reposo con sus scripts de interfaz y caché por defecto | 44 MB | Sin scripts y caché de 16 MB: 20 MB |

## Quitado

| Fecha | Qué | Dónde mirarlo |
|---|---|---|
| 2026-11-13/14 (sin apuntar) | Estilo de ventana «Escenario», con la letra sobre la estantería (la navegación superior se quedó) | Historia de git |

## Fallos resueltos

| Fecha | Síntoma | Causa y arreglo |
|---|---|---|
| 2026-11-14 | Las escuchas salían en el historial de YouTube y no en el de YouTube Music | Faltaba `c=WEB_REMIX` en los avisos ([historial](../areas/historial.md)) |
| 2026-11-14 | La letra subía la CPU a ~25 % sin animaciones | Un gestor de «hover»/clic por línea; ahora uno solo ([ADR-13](../decisions/ADR-13-letra-de-lrclib-con-un-solo-gestor.md)) |
| 2026-11-13 | En Lomos una caja saltaba al cruzar el centro hacia la izquierda | El lomo y el eje de giro cambiaban de lado de golpe; funciones continuas ([ADR-14](../decisions/ADR-14-lomos-con-matrices-propias.md)) |
| 2026-11-13 | Cada descarga fallaba con «NSURLErrorDomain -1003» | Qt seguía el WPAD roto del sistema; `window.cpp` respeta `HTTPS_PROXY`/`HTTP_PROXY` |

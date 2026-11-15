---
area: historial
titulo: Registro de escuchas
resumen: Apunta en el historial de YouTube Music lo que suena, con los mismos avisos que manda su reproductor, sin retrasar el arranque.
archivos: [src/history.rs]
opciones: [historial]
adr: [ADR-12]
---

# Registro de escuchas

Opciones › Reproducción › «Registrar en YouTube Music» (activado por defecto). Solo con sesión.

## Qué hace

Lo que suena aparece en el historial de YouTube Music y cuenta para sus recomendaciones. Con
«repetir la canción», cada vuelta es una escucha nueva.

## Reglas y decisiones

- **Pedir el audio no cuenta como reproducción**; la cuentan los avisos del reproductor
  ([ADR-12](../decisions/ADR-12-historial-con-los-avisos-del-reproductor.md)).
- **Todos los avisos llevan `c=WEB_REMIX` y `cver`**: sin ellos la escucha va al historial de
  YouTube y no al de YouTube Music (es lo que hace ytmusicapi en `add_history_item`).
- **No toca el arranque**: nada espera a esas peticiones y sus fallos solo van a stderr, con el
  prefijo `historial:`.
- **Las cookies solo se mandan a `*.youtube.com`** (`is_youtube`).
- Contrapartida conocida: YouTube ve la escucha y aplica su límite de un dispositivo a la vez por
  cuenta.

## Cómo funciona

1. Cuando una pista ya suena (`Event::Started`, la primera vez de cada carga), un hilo pide
   `/player` con la sesión (cliente `WEB_REMIX`) y toma `playbackTracking.videostatsPlaybackUrl` y
   `videostatsWatchtimeUrl`.
2. Avisa del inicio con un `cpn` nuevo (16 caracteres, como yt-dlp `--mark-watched`).
3. `player.rs` (`Listen`) sigue la posición y envía el tramo escuchado (`st`/`et`/`cmt`) cada
   30 s, al pausar, al saltar y al cambiar de pista.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/history.rs` | Avisos de inicio y de tiempo escuchado |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Activar o desactivar | [`set_enabled`](../../src/history.rs) |
| Aviso de inicio | [`start`](../../src/history.rs) |
| Tramo escuchado | [`watched`](../../src/history.rs) |
| Parámetros de cliente en cada aviso | [`with_params`](../../src/history.rs) |
| Seguimiento de la posición | [`Listen`](../../src/player.rs) |

## Dependencias

- **[sesion](sesion.md)** (`account::with_session`): sin sesión no hay registro.
- **[catalogo](catalogo.md)** (`ytm::tracking_urls`): las URLs de los avisos.
- **La usan:** [reproduccion](reproduccion.md) (`history::start`, `history::watched`),
  [personalizacion](personalizacion.md) (la opción).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** `mod tests` de `src/history.rs` (sustitución de parámetros, avisos de YouTube Music,
  `cpn`, solo hosts de YouTube).
- **Sin verificar:** que la escucha aparezca en el historial con la cuenta del propietario tras el
  cambio a `c=WEB_REMIX` (necesita su sesión real; lo comprueba él).
- **Historial:** [docs/history/verificacion/historial.md](../history/verificacion/historial.md).

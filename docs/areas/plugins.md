---
area: plugins
titulo: Plugins (Discord y Last.fm)
resumen: Discord Rich Presence («Escuchando…») y scrobbling a Last.fm, alimentados por los eventos del reproductor en un hilo propio.
archivos: [src/plugins.rs, src/plugins/discord.rs, src/plugins/lastfm.rs]
opciones: []
adr: [ADR-15]
---

# Plugins (Discord y Last.fm)

Opciones › Plugins. Los controles del sistema (souvlaki) se activan aquí pero viven en
[reproduccion](reproduccion.md), porque en macOS van en el hilo principal.

## Qué hace

- **Discord**: «Escuchando…» con la carátula y la barra de tiempo. Hace falta un «Application ID»
  (uno incluido al compilar con `MUSICPLAYER_DISCORD_ID`, o el del usuario; ver
  [COMPILAR](../../COMPILAR.md#discord)).
- **Last.fm**: «escuchando ahora» al empezar y scrobble cuando la pista dura más de 30 s y se ha
  escuchado la mitad o 4 minutos de escucha real (los saltos no cuentan).

## Reglas y decisiones

- **Un hilo propio reparte los eventos** ([ADR-15](../decisions/ADR-15-plugins-en-un-hilo-propio.md)):
  `Player` llama a `emit(Event)` al empezar una pista (`Track`), al pausar o reanudar (`Playing`),
  con cada posición (`Position`) y al terminar la cola (`Stopped`). Nunca frenan la interfaz.
- **Configuración en `<config>/musicplayer/plugins.json`**, legible solo por el usuario (lleva el
  secreto y la sesión de Last.fm).
- Los estados vuelven a la interfaz como `Plugins.discordStatus` y `Plugins.lastfmStatus`.

## Cómo funciona

- **Discord:** socket IPC local, mensajes `[opcode u32 LE][longitud u32 LE][JSON]`; saludo
  (`opcode 0`, `client_id`) y `SET_ACTIVITY` con `type: 2` («Escuchando»).
- **Last.fm:** API 2.0 firmada (md5 de los parámetros ordenados + secreto). Autorización en dos
  pasos: `auth.getToken` → web → `auth.getSession`.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/plugins.rs` | Singleton `Plugins`, configuración y reparto de eventos |
| `src/plugins/discord.rs` | Rich Presence por IPC |
| `src/plugins/lastfm.rs` | Firma, autorización y reglas de scrobble |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Avisar de un evento | [`emit`](../../src/plugins.rs) |
| Hilo que reparte | [`worker`](../../src/plugins.rs) |
| Mensaje de Discord | [`frame`](../../src/plugins/discord.rs) |
| Actividad de escucha | [`activity`](../../src/plugins/discord.rs) |
| Firma de Last.fm | [`sign`](../../src/plugins/lastfm.rs) |
| Regla de scrobble | [`should_scrobble`](../../src/plugins/lastfm.rs) |

## Dependencias

- Recibe los eventos de [reproduccion](reproduccion.md).
- **[catalogo](catalogo.md)** (`ytm::http`): el cliente HTTP común para hablar con Last.fm.
- **La usan:** [reproduccion](reproduccion.md) (`plugins::emit`), [ventana](ventana.md) y
  [personalizacion](personalizacion.md) (la pestaña Plugins).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** `mod tests` de `src/plugins/discord.rs` (cabecera, Discord simulado, actividad) y
  `src/plugins/lastfm.rs` (firma, reglas de scrobble). De extremo a extremo:
  [probar-plugins](../runbooks/probar-plugins.md).
- **Sin verificar:** Discord en Flatpak (otra ruta del socket).
- **Historial:** [docs/history/verificacion/plugins.md](../history/verificacion/plugins.md).

## Pendiente

- Más plugins: letras de otras fuentes, ecualizador, notificaciones ([ROADMAP](../ROADMAP.md)).

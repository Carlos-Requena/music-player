---
area: plugins
titulo: Plugins (Discord, Last.fm y ListenBrainz)
resumen: Discord Rich Presence («Escuchando…»), scrobbling a Last.fm y escuchas en ListenBrainz, alimentados por los eventos del reproductor en un hilo propio.
archivos: [src/plugins.rs, src/plugins/discord.rs, src/plugins/lastfm.rs, src/plugins/listenbrainz.rs]
opciones: []
adr: [ADR-15, ADR-19]
---

# Plugins (Discord, Last.fm y ListenBrainz)

Opciones › Plugins. Los controles del sistema (souvlaki) se activan aquí pero viven en
[reproduccion](reproduccion.md), porque en macOS van en el hilo principal.

## Qué hace

- **Discord**: «Escuchando…» con la carátula y la barra de tiempo. Hace falta un «Application ID»
  (uno incluido al compilar con `MUSICPLAYER_DISCORD_ID`, o el del usuario; ver
  [COMPILAR](../../COMPILAR.md#discord)).
- **Last.fm**: «escuchando ahora» al empezar y scrobble cuando la pista dura más de 30 s y se ha
  escuchado la mitad o 4 minutos de escucha real (los saltos no cuentan).
- **ListenBrainz**: lo mismo que Last.fm (`playing_now` y la escucha con las mismas reglas), con
  solo el token del usuario. Su nombre de usuario (de `/1/validate-token`) es el de las
  recomendaciones de Explorar ([catalogo](catalogo.md),
  [ADR-19](../decisions/ADR-19-explorar-con-listenbrainz.md)); pausar el envío no las quita,
  desconectar sí.

## Reglas y decisiones

- **Un hilo propio reparte los eventos** ([ADR-15](../decisions/ADR-15-plugins-en-un-hilo-propio.md)):
  `Player` llama a `emit(Event)` al empezar una pista (`Track`), al pausar o reanudar (`Playing`),
  con cada posición (`Position`) y al terminar la cola (`Stopped`). Nunca frenan la interfaz.
- **Configuración en `<config>/musicplayer/plugins.json`**, legible solo por el usuario (lleva el
  secreto y la sesión de Last.fm y el token de ListenBrainz).
- Los estados vuelven a la interfaz como `Plugins.discordStatus`, `Plugins.lastfmStatus` y
  `Plugins.listenbrainzStatus`.

## Cómo funciona

- **Discord:** socket IPC local, mensajes `[opcode u32 LE][longitud u32 LE][JSON]`; saludo
  (`opcode 0`, `client_id`) y `SET_ACTIVITY` con `type: 2` («Escuchando»).
- **Last.fm:** API 2.0 firmada (md5 de los parámetros ordenados + secreto). Autorización en dos
  pasos: `auth.getToken` → web → `auth.getSession`.
- **ListenBrainz:** `POST /1/submit-listens` con `Authorization: Token …`, `listen_type`
  `playing_now` o `single` (con `listened_at`) y `origin_url` de YouTube Music. Las peticiones
  pasan por `listenbrainz::post` de [catalogo](catalogo.md), que las espacia un segundo.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/plugins.rs` | Singleton `Plugins`, configuración y reparto de eventos |
| `src/plugins/discord.rs` | Rich Presence por IPC |
| `src/plugins/lastfm.rs` | Firma, autorización y reglas de scrobble |
| `src/plugins/listenbrainz.rs` | Envío de escuchas a ListenBrainz |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Avisar de un evento | [`emit`](../../src/plugins.rs) |
| Hilo que reparte | [`worker`](../../src/plugins.rs) |
| Mensaje de Discord | [`frame`](../../src/plugins/discord.rs) |
| Actividad de escucha | [`activity`](../../src/plugins/discord.rs) |
| Firma de Last.fm | [`sign`](../../src/plugins/lastfm.rs) |
| Regla de scrobble | [`should_scrobble`](../../src/plugins/lastfm.rs) |
| Escucha de ListenBrainz | [`Submitter`](../../src/plugins/listenbrainz.rs), [`metadata`](../../src/plugins/listenbrainz.rs) |
| Usuario de Explorar | [`listenbrainz_user`](../../src/plugins.rs) |

## Dependencias

- Recibe los eventos de [reproduccion](reproduccion.md).
- **[catalogo](catalogo.md)** (`ytm::http`, `listenbrainz::post`, `listenbrainz::validate_token`):
  el cliente HTTP común y el de ListenBrainz.
- **La usan:** [reproduccion](reproduccion.md) (`plugins::emit`), [catalogo](catalogo.md)
  (`plugins::listenbrainz_user`), [ventana](ventana.md) y
  [personalizacion](personalizacion.md) (la pestaña Plugins).

## Estado actual

- **Última verificación:** 2026-11-17, plugin de ListenBrainz ([historial](../history/verificacion/plugins.md)).
- **Pruebas:** `mod tests` de `src/plugins/discord.rs` (cabecera, Discord simulado, actividad) y
  `src/plugins/lastfm.rs` (firma, reglas de scrobble) y `src/plugins/listenbrainz.rs` (datos de la
  escucha). De extremo a extremo:
  [probar-plugins](../runbooks/probar-plugins.md).
- **Sin verificar:** Discord en Flatpak (otra ruta del socket); ListenBrainz con un token real
  (conectar, «escuchando ahora» y la escucha).
- **Historial:** [docs/history/verificacion/plugins.md](../history/verificacion/plugins.md).

## Pendiente

- Más plugins: letras de otras fuentes, notificaciones ([ROADMAP](../ROADMAP.md)). El ecualizador y
  el amplificador están en la pestaña Plugins, pero viven en [reproduccion](reproduccion.md): son
  filtros de mpv, no escuchan eventos.

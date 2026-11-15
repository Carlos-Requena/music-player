# Verificar la reproducción

Si tocaste reproducción, resolución, la cola o algo que dependa de lo que suena, una prueba con
`--autoplay` tiene que terminar con `sonando true` y sin `error`
([AGENTES §8](../AGENTES.md#8-norma-verificar-antes-de-dar-algo-por-terminado)). Prepara antes el
`HOME` de pruebas ([verificar-interfaz](verificar-interfaz.md#aislar-las-pruebas)).

## La prueba de siempre

```bash
HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer \
  --shot "$PRUEBA/r.png" --delay 20000 --section albumes --index 5 \
  --autoplay --autoplay-delay 6000 --then-next 15000
```

- La última línea de stdout es `estado: …`: tiene que decir `sonando true` y ningún `error`.
- Stderr escribe `arranque de pista: N ms` por cada pista: con precarga, unas décimas.

## Sondas sin ventana (`--probe`)

| Sonda | Qué hace |
|---|---|
| `--probe home` · `explore` · `albums` · `playlists` | Secciones del catálogo |
| `--probe search "texto"` | Búsqueda |
| `--probe queue VIDEO_ID` | Radio de una canción |
| `--probe album PLAYLIST_ID` | Canciones de un álbum o playlist (página real) |
| `--probe lyrics "título" "artista"` | Letra de LRCLIB |
| `--probe play VIDEO_ID` | Mide el arranque (con `MUSICPLAYER_SILENT=1`) |
| `--probe resolve id1,id2` | Resolución con el yt-dlp residente |
| `--probe fast id1,id2` | Solo la vía rápida, y por qué falla cada pista |
| `--probe playable ID` | Qué dice YouTube Music de la pista |
| `--probe account` | Si YouTube reconoce la sesión guardada |

`MUSICPLAYER_YTDLP_CLIENTS=web_music,…` fuerza los clientes de yt-dlp para comparar.

## Una pista que no suena

1. `--probe fast ID`: ¿la vía rápida la da? ¿Qué dice YouTube?
2. `--probe playable ID`: si es `UNPLAYABLE`, exige cuenta ([resolucion](../areas/resolucion.md)).
3. `yt-dlp -F "https://music.youtube.com/watch?v=ID"` directamente: si yt-dlp tampoco puede, no es
   el código (actualiza yt-dlp o espera unos minutos).
4. Las líneas del resolvedor en stderr.

## No castigues a YouTube

Agrupa las pruebas: cada ejecución hace peticiones reales. Si aparecen 403, «Requested format is
not available» o «Sign in to confirm you're not a bot», para unos minutos y compruébalo con
`yt-dlp` antes de tocar nada.

## Al terminar

- Comprueba que no quedan procesos de prueba: `pgrep -fl "mpv --idle"` y `pgrep -fl ytdlp_daemon`;
  cierra solo los que lanzaste tú (los del propietario, si tiene la app abierta, no).

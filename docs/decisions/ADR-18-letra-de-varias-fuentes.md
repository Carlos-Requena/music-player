---
adr: ADR-18
titulo: Letra de varias fuentes (LRCLIB, NetEase y Kugou), pedidas a la vez y elegidas en la interfaz
estado: aceptada
fecha: 2026-11-16
areas: [letra]
---

# ADR-18 · Letra de varias fuentes (LRCLIB, NetEase y Kugou), pedidas a la vez y elegidas en la interfaz

- **Estado:** Aceptada. Amplía [ADR-13](ADR-13-letra-de-lrclib-con-un-solo-gestor.md) (que fijaba solo LRCLIB).
- **Registrada:** 2026-11-16
- **Ámbito:** [letra](../areas/letra.md)

## Decisión

La letra se pide **a la vez** a LRCLIB, NetEase Cloud Music (YRC) y Kugou (KRC), las tres sin
cuenta. Rust publica en `Player.lyrics` **todas** las que encuentra, ordenadas de mejor a peor
(`lyrics::rank`: duración que encaja, tiempos por palabra, fuente), y cada una en cuanto llega.
La interfaz elige cuál mostrar (`Catalog.lyricsChosen`): la elegida para esa canción
(`origen:<videoId>`, pulsando el nombre de la fuente en el pie), si no la preferida en Opciones
(`letraOrigen`), y si no la primera. Cuando la letra solo trae el tiempo de cada línea, la línea se
ilumina **entera de golpe**; el barrido estimado queda como opción (`letraSinTiempos`).

## Alternativas descartadas

- **Solo LRCLIB**: le falta mucho anime y casi nunca trae tiempos por palabra; el barrido se
  inventaba (75 ms por letra) y no encajaba con la voz, que es de lo que se quejaba el propietario.
- **Musixmatch («richsync»)**: tiene tiempos por palabra, pero su API exige un token que se saca
  imitando su aplicación de escritorio y corta con captchas.
- **QQ Music (QRC)**: también por sílaba, pero cifrado con un 3DES modificado: más código para
  un catálogo que ya cubren NetEase y Kugou.
- **Apple Music y Spotify**: exigen la cuenta del usuario en esos servicios.
- **Alinear la letra con la voz en local** (Whisper u otro modelo): cientos de MB de memoria, en
  contra de la primera prioridad del propietario.
- **Elegir la fuente en Rust** (leyendo las opciones desde Rust): obligaba a pasar las
  preferencias por canción al hilo de la letra; en QML cambiar de fuente es instantáneo porque
  todas las letras ya están en `Catalog.lyricsSources`.

## Motivo

Prueba del 2026-11-16 con `--probe lyrics`: en «紅蓮華» (LiSA), «Idol» (YOASOBI), «Unravel» (TK)
y «Blinding Lights», NetEase o Kugou traen el tiempo de cada sílaba con la duración exacta de la
pista; LRCLIB, solo de cada línea.

## Consecuencias

- `Player.lyrics` es una lista de fuentes (`[{ id, label, words, lines }]`), no de líneas.
- NetEase y Kugou son API no documentadas: pueden cambiar sin aviso. Cada fuente falla por su
  cuenta (aviso `letra:` en stderr) y las demás siguen.
- Una fuente nueva es una variante de `lyrics::Source` y su función de búsqueda; la interfaz no
  cambia.

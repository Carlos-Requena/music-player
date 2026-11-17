---
adr: ADR-19
titulo: Explorar muestra las recomendaciones de ListenBrainz (Troi) pedidas a su API desde Rust
estado: ampliada por ADR-20
fecha: 2026-11-17
areas: [catalogo, plugins]
---

# ADR-19 · Explorar muestra las recomendaciones de ListenBrainz (Troi) pedidas a su API desde Rust

- **Estado:** Ampliada por [ADR-20](ADR-20-fuente-de-explorar-a-elegir.md) (la fuente de Explorar se elige en Opciones).
- **Registrada:** 2026-11-17
- **Ámbito:** [catalogo](../areas/catalogo.md), [plugins](../areas/plugins.md)

## Decisión

- La sección **Explorar** deja de pedir `FEmusic_explore` a YouTube Music y muestra lo que
  recomienda **ListenBrainz**, cuyas listas genera Troi en su servidor: las listas «hecho para
  ti» (Weekly Exploration, Weekly Jams, Daily Jams), las recomendaciones colaborativas, las
  novedades de los artistas que escuchas y lo más escuchado de la semana en ListenBrainz.
- **Todo por HTTP desde Rust** (`src/listenbrainz.rs`), en el hilo de carga del catálogo: ni Troi
  ni Python ni un proceso nuevo.
- ListenBrainz devuelve grabaciones de MusicBrainz (título, artista, MBID), no vídeos. Cada una
  **se convierte en una canción de YouTube Music con una búsqueda** (filtro de canciones; de
  álbumes para las novedades) y el resultado se guarda en disco por MBID, para no repetir la
  búsqueda en cada carga.
- Las listas personales necesitan **escuchas en ListenBrainz**: un plugin nuevo
  (`src/plugins/listenbrainz.rs`) las envía con el token del usuario, con las mismas reglas que
  Last.fm. El nombre de usuario sale del token. Sin token, Explorar muestra solo lo más escuchado
  en ListenBrainz.

## Alternativas descartadas

- **Troi local en Python** (`pip install troi`, como proceso aparte igual que yt-dlp): sus
  patches consultan igualmente las APIs de ListenBrainz y MusicBrainz y necesitan la misma cuenta
  con escuchas. Añade un intérprete de Python vivo o segundos de arranque en cada generación, y una
  dependencia GPL-2.0 que instalar, solo para ganar patches poco comunes (`world-trip`,
  `area-random-recordings`). Razonada, no medida.
- **LB Radio sin cuenta, sembrada con los «Me gusta» de YouTube Music**: no pide cuenta, pero
  es menos personal («artistas parecidos»). Queda como posible zona futura.
- **Mantener el Explorar de YouTube y añadir una sección «Descubrir»**: el propietario prefirió
  sustituirlo.

## Motivo

El propietario quiere recomendaciones de Troi en Explorar. ListenBrainz ya ejecuta Troi y publica
el resultado en su API (`/1/user/{u}/playlists/createdfor`, `/1/playlist/{mbid}`,
`/1/cf/recommendation/user/{u}/recording`, `/1/user/{u}/fresh_releases`,
`/1/stats/sitewide/recordings`). Pedirlo desde Rust no cuesta memoria ni procesos, que es la
primera prioridad del proyecto ([AGENTES §1](../AGENTES.md#1-qué-es)).

## Consecuencias

- Explorar ya no muestra las listas de éxitos ni los ánimos de YouTube Music («Ánimo y géneros»
  sigue en Playlists sin sesión).
- La primera carga de una lista nueva hace una búsqueda en YouTube Music por canción que no esté
  en la caché (unas 50 por lista nueva); van en el hilo del catálogo, de pocas en pocas, y no
  frenan la interfaz. Una canción que no se encuentra se omite.
- ListenBrainz admite una petición por segundo y pide un User-Agent propio: el cliente espera
  entre peticiones.
- Una lista de ListenBrainz no es una playlist de YouTube: no se puede guardar entera en la cuenta
  desde el menú contextual; sus canciones, sí.

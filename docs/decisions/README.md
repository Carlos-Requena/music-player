# Decisiones de arquitectura (ADR)

Una decisión por archivo: qué se decidió, qué se descartó, por qué y qué consecuencias tiene.
Sirve para no reabrir una decisión sin un motivo nuevo. El detalle de cada área está en su ficha
([docs/areas/](../areas/)); aquí van las decisiones que cruzan la arquitectura o que fijó el
propietario. Cómo se escribe una: [runbooks/registrar-decision.md](../runbooks/registrar-decision.md)
y [la plantilla](../templates/adr.md).

**Estados:** *aceptada* (vigente) · *ampliada por ADR-NN* (vigente, pero otra la completa o cambia
una parte) · *sustituida por ADR-NN* (ya no vale; manda la nueva). El texto de una ADR no se
reescribe: si algo cambia, se añade otra y se actualiza el estado de la antigua.

## Índice

<!-- generado:adr -->
> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla.

| ADR | Decisión | Estado | Áreas | Registrada |
|---|---|---|---|---|
| [ADR-01](ADR-01-qt-qml-y-rust.md) | Qt 6 / QML para la interfaz y Rust con cxx-qt para el núcleo | aceptada | — | 2026-11-13 |
| [ADR-02](ADR-02-mpv-en-proceso-aparte.md) | mpv en un proceso aparte, controlado por su socket IPC JSON | aceptada | [reproduccion](../areas/reproduccion.md) | 2026-11-13 |
| [ADR-03](ADR-03-via-rapida-y-yt-dlp-de-respaldo.md) | Vía rápida por la API /player con el cliente de visionOS, y yt-dlp de respaldo | aceptada | [resolucion](../areas/resolucion.md) | 2026-11-13 |
| [ADR-04](ADR-04-json-hacia-qml.md) | Datos estructurados de Rust a QML como JSON en una propiedad QString | aceptada | [catalogo](../areas/catalogo.md) | 2026-11-13 |
| [ADR-05](ADR-05-precarga-de-urls.md) | Precargar la URL de lo que probablemente se va a pedir | aceptada | [resolucion](../areas/resolucion.md) | 2026-11-13 |
| [ADR-06](ADR-06-canciones-por-la-pagina-de-la-lista.md) | Canciones de un álbum o playlist desde su página VL, no desde la cola next | aceptada | [catalogo](../areas/catalogo.md) | 2026-11-14 |
| [ADR-07](ADR-07-inicio-de-sesion-en-proceso-aparte.md) | La ventana de inicio de sesión va en un proceso aparte; el reproductor no carga ningún motor web | aceptada | [sesion](../areas/sesion.md) | 2026-11-14 |
| [ADR-08](ADR-08-yt-dlp-residente.md) | yt-dlp residente para no pagar el arranque de Python en cada pista | aceptada | [resolucion](../areas/resolucion.md) | 2026-11-13 |
| [ADR-09](ADR-09-cache-de-secciones-en-disco.md) | Cada sección se guarda en disco y se muestra al abrir mientras llega la nueva | aceptada | [catalogo](../areas/catalogo.md) | 2026-11-13 |
| [ADR-10](ADR-10-mini-reproductor-oculta-la-ventana.md) | El mini reproductor oculta la ventana grande y libera su memoria gráfica | aceptada | [ventana](../areas/ventana.md) | 2026-11-13 |
| [ADR-11](ADR-11-skins-en-json-y-opciones-genericas.md) | Skins en JSON y opciones de disposición como un mapa clave → valor | aceptada | [personalizacion](../areas/personalizacion.md) | 2026-11-13 |
| [ADR-12](ADR-12-historial-con-los-avisos-del-reproductor.md) | Registrar las escuchas con los avisos del reproductor de YouTube Music, activado por defecto | aceptada | [historial](../areas/historial.md) | 2026-11-14 |
| [ADR-13](ADR-13-letra-de-lrclib-con-un-solo-gestor.md) | Letra de LRCLIB y un solo gestor de clics para toda la vista, sin hover | ampliada por ADR-18 | [letra](../areas/letra.md) | 2026-11-14 |
| [ADR-14](ADR-14-lomos-con-matrices-propias.md) | La estantería Lomos con matrices 3D propias y funciones continuas | aceptada | [vistas](../areas/vistas.md) | 2026-11-13 |
| [ADR-15](ADR-15-plugins-en-un-hilo-propio.md) | Los plugins reciben los eventos del reproductor en un hilo propio | aceptada | [plugins](../areas/plugins.md) | 2026-11-13 |
| [ADR-16](ADR-16-documentacion-por-areas.md) | Documentación por áreas, una fuente por tema y comprobada con scripts/docs.py | aceptada | — | 2026-11-15 |
| [ADR-17](ADR-17-fondo-fluido-con-sombreador-propio.md) | El fondo «Fluido» es un sombreador propio, precompilado con qsb y guardado en el repositorio | aceptada | [personalizacion](../areas/personalizacion.md) | 2026-11-16 |
| [ADR-18](ADR-18-letra-de-varias-fuentes.md) | Letra de varias fuentes (LRCLIB, NetEase y Kugou), pedidas a la vez y elegidas en la interfaz | aceptada | [letra](../areas/letra.md) | 2026-11-16 |
| [ADR-19](ADR-19-explorar-con-listenbrainz.md) | Explorar muestra las recomendaciones de ListenBrainz (Troi) pedidas a su API desde Rust | ampliada por ADR-20 | [catalogo](../areas/catalogo.md), [plugins](../areas/plugins.md) | 2026-11-17 |
| [ADR-20](ADR-20-fuente-de-explorar-a-elegir.md) | La fuente de Explorar se elige en Opciones (ListenBrainz por defecto o YouTube Music) | aceptada | [catalogo](../areas/catalogo.md) | 2026-11-17 |
<!-- /generado -->

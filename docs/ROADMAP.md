# Hoja de ruta

Ordenada por lo que más acerca la app a sustituir a Pear Desktop. Lo marcado **(decidir)**
necesita una decisión del propietario antes de empezar.

## Hecho

- Ventana de vidrio y estilo Escenario, navegación superior, modo ambiente con el color de la
  carátula.
- Vistas Lomos, Cubeta y Muro, elegibles por sección y alternables al vuelo.
- Catálogo real sin sesión: inicio, explorar, novedades, playlists por estado de ánimo,
  búsqueda de canciones, álbumes y playlists.
- Reproducción con mpv + yt-dlp, cola, siguiente/anterior, posición, volumen.
- Arranque instantáneo de pistas con precarga (ver [ARCHITECTURE.md](ARCHITECTURE.md)).
- Letra sincronizada (LRCLIB), resaltado palabra a palabra.
- Inicio de sesión con la sesión del navegador; secciones Artistas, Canciones y Me gusta.
- Detalle de álbum, playlist y artista con Reproducir y Aleatorio; artistas en la búsqueda.
- Modo inspeccionar: girar la caja, abrirla, sacar el disco.
- Rendimiento: caché de secciones, mini reproductor que libera la ventana grande, yt-dlp
  residente, mpv aligerado, carga perezosa de carátulas.
- Plugins: controles del sistema (macOS y MPRIS), Discord Rich Presence y Last.fm.

## Siguiente

1. **Probar y empaquetar en CachyOS**: compilar, revisar Wayland, desenfoque y rendimiento con
   el controlador de la máquina, y un `PKGBUILD`.
2. **Editor de disposición** (ver Personalización).
3. Guardar en la biblioteca y marcar «Me gusta» desde la app.

## Personalización

Hecho: skins en JSON (cuatro incluidas y carpeta del usuario), panel a izquierda o derecha,
modo ambiente y desenfoque activables, tamaño de las carátulas del Muro.

6. **Editor de disposición**: arrastrar, ocultar y redimensionar paneles (letra, cola, barra,
   navegación) sobre la propia ventana, guardando en `opciones`.
7. **Skins claras**: hacen falta tokens para los velos y fondos de superposición, que hoy
   asumen fondo oscuro.
8. **Skins con QML propio** (sustituir componentes enteros, no solo colores).
9. **Más plugins**: letras de otras fuentes, ecualizador (filtros de mpv), notificaciones.

## Rendimiento

Hecho (ver ARCHITECTURE). Queda:

10. Liberar memoria al **minimizar** en macOS (Qt conserva los búferes): habría que destruir y
    recrear la ventana, o pasar al mini reproductor automáticamente al minimizar.
11. Probar si libmpv embebido ahorra algo frente al proceso mpv (~20 MB en reposo hoy).

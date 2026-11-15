# Hoja de ruta

Ordenada por lo que más acerca la app a sustituir a Pear Desktop. Lo marcado **(decidir)**
necesita una decisión del propietario antes de empezar; en diseño, con alternativas
([AGENTES §6](AGENTES.md#6-normas-de-interfaz)). Lo ya hecho está en el
[changelog técnico](history/CHANGELOG-TECNICO.md).

## Siguiente

1. **Probar y empaquetar en CachyOS**: compilar, revisar Wayland, desenfoque y rendimiento con el
   controlador de la máquina, y un `PKGBUILD`.
2. **Editor de disposición** (decidir): arrastrar, ocultar y redimensionar paneles (letra, cola,
   barra, navegación) sobre la propia ventana, guardando en `opciones`
   ([personalizacion](areas/personalizacion.md)).
3. Guardar álbumes en la biblioteca y «Me gusta» desde el menú contextual, con quitarlo; hoy solo
   se da pinchando la mascota ([catalogo](areas/catalogo.md)).

## Personalización

4. **Skins claras**: hacen falta tokens para los velos y fondos de superposición, que asumen fondo
   oscuro.
5. **Skins con QML propio** (decidir): sustituir componentes enteros, no solo colores.
6. **Más plugins**: letras de otras fuentes, ecualizador (filtros de mpv), notificaciones.

## Rendimiento

7. Liberar memoria al **minimizar** en macOS (Qt conserva los búferes): destruir y recrear la
   ventana, o pasar al mini reproductor automáticamente al minimizar (decidir)
   ([ventana](areas/ventana.md)).
8. Probar si **libmpv embebido** ahorra algo frente al proceso mpv (~20 MB en reposo)
   ([ADR-02](decisions/ADR-02-mpv-en-proceso-aparte.md)).

## Deuda conocida

Lo que falta para poder confiar en un cambio sin probarlo todo a mano. Si tu tarea toca uno de
estos puntos, no lo empeores ([AGENTES §10](AGENTES.md#10-deuda-conocida-no-la-empeores)).

- **Sin CI:** `cargo build --release`, `cargo test` y `python3 scripts/docs.py check` se pasan a
  mano.
- **Sin pruebas de lo que habla con la red** (`ytm.rs`, `library.rs`, `resolver.rs`, `player.rs`):
  dependen de `--probe` y de capturas. Las respuestas de InnerTube guardadas como ejemplo
  permitirían probar el análisis sin red.
- **Linux sin verificar a fondo:** Wayland, MPRIS en GNOME y KDE, la ventana de inicio de sesión
  con Qt WebEngine y el coste de la letra con el controlador de CachyOS.
- **Verificaciones sin registrar:** casi todas las fichas dicen «sin registrar»: se rellenan la
  próxima vez que se toque cada área.
- **Archivos generados de la guía en git** (`docs/guia/guia.aux`, `.log`, `.toc`…): deberían
  ignorarse.

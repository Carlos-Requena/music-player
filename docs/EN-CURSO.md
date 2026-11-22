# Trabajo en curso

Nota de la tarea larga que está a medias, para quien la retome sin memoria de la conversación
(otra persona, otro agente o el mismo tras compactar el contexto). Cómo se usa:
[runbooks/retomar-trabajo.md](runbooks/retomar-trabajo.md).

- **Se actualiza al terminar cada paso**, no al final.
- **Se vacía al unir la rama** (deja solo «Ninguna tarea en curso»): lo que valga la pena guardar
  pasa antes a su ficha, a una ADR o al historial.

---

## Versión de Windows · rama `feature/windows`

- **Objetivo:** «Ahora hace falta una versión para windows» (el propietario).
- **Áreas:** [reproduccion](areas/reproduccion.md), [sesion](areas/sesion.md),
  [plugins](areas/plugins.md), [resolucion](areas/resolucion.md), [ventana](areas/ventana.md).
- **Decisiones tomadas en la conversación:** inicio de sesión con WebView2 (preguntó si tenía poca
  resolución: no, si se declara el DPI por monitor) e instalador `.exe` con Inno Setup. Escritas
  en [ADR-24](decisions/ADR-24-version-de-windows.md) y en AGENTES §11.
- **Hecho:** código de Windows (`src/tuberia.rs`, `audio::command`, Discord, señales, controles
  multimedia, `login/src/login_windows.rs`), `scripts/crear-instalador-windows.ps1`,
  `scripts/windows/reproductor.iss`, `assets/icon.ico` y la documentación. En macOS: release sin
  avisos, `cargo test`, `docs.py check`, `--autoplay` y captura de Opciones › Cuenta. Para Windows,
  solo `cargo check` desde macOS de lo que no usa Qt.
- **Falta:** compilar y probar en un PC con Windows: `scripts\crear-instalador-windows.ps1`,
  instalar, que suene, iniciar sesión con WebView2 (nitidez a 125–150 %), Discord, teclas
  multimedia, que no aparezcan consolas y que al cerrar no quede ningún `mpv.exe`. Apuntar lo
  visto en el historial de cada área y vaciar esta nota.
- **Cómo retomarla:** `git switch feature/windows` y [COMPILAR.md, Windows](../COMPILAR.md#windows).
- **Cuidado:** `player.rs`, `main.rs` y `signals.cpp` no se han compilado nunca para Windows; los
  primeros errores de compilación saldrán ahí.

<!--
Esqueleto (cópialo encima de «Ninguna tarea en curso» y bórrala):

## <Tarea> · rama `<feature/nombre>`

- **Objetivo:** <qué pidió el propietario, con sus palabras si importan>.
- **Áreas:** [<area>](areas/<area>.md).
- **Decisiones tomadas en la conversación:** <cada una, con dónde se ha escrito ya (ficha, ADR,
  AGENTES §11) o «falta escribirla»>.
- **Hecho:** <pasos terminados, con el commit si lo hay>.
- **Falta:** <pasos, en orden>.
- **Cómo retomarla:** <el primer comando o archivo que hay que abrir>.
- **Cuidado:** <lo que se probó y no funcionó, para no repetirlo>.
-->

---
area: personalizacion
titulo: Opciones, skins y aspecto
resumen: Preferencias guardadas (vista por sección, skin, opciones genéricas), la hoja de Opciones, los tokens visuales de Theme, el vidrio y el modo ambiente.
archivos: [src/settings.rs, qml/Theme.qml, qml/SettingsSheet.qml, qml/Ambient.qml, qml/TintProbe.qml, skins/vidrio.json, skins/medianoche.json, skins/grafito.json, skins/neon.json]
opciones: [ambiente, desenfoque]
adr: [ADR-11]
---

# Opciones, skins y aspecto

Opciones (el engranaje), por categorías en una barra lateral: Cuenta, Reproducción, Apariencia,
Vistas y Plugins. Cómo crear una skin o una mascota, para quien usa la app: [README](../../README.md#crear-una-skin).

## Qué hace

- **Skins**: Vidrio, Medianoche, Grafito y Neón incluidas, más las del usuario en
  `<config>/musicplayer/skins/` (archivo JSON o carpeta con imagen de fondo). Cambiar de skin no
  necesita reiniciar.
- **Opciones de disposición** genéricas (`AppSettings.opcion`/`setOpcion`), guardadas en
  `<config>/musicplayer/settings.json`. Las de cada área están en el `opciones:` de su ficha; la
  tabla completa, en [INDEX](../INDEX.md#opciones).
- **Modo ambiente** (`ambiente`): focos de color suaves, uno teñido por lo enfocado y otro por lo
  que suena. Vivo (por defecto), Suave y Tenue (un solo foco), **Plano** y No. **Plano**, por
  petición del propietario para pantallas antiguas que muestran los degradados con escalones:
  todo el fondo de un solo color sólido (el de fondo de la skin mezclado con el de lo enfocado,
  `Theme.ambientFlat`), sin focos, sin el suelo oscuro y sin el halo de la carátula de «Sonando».
  **Desenfoque** (`desenfoque`): desactivarlo ahorra memoria y batería.

## Reglas y decisiones

- **Skins en JSON y opciones como mapa clave → valor**
  ([ADR-11](../decisions/ADR-11-skins-en-json-y-opciones-genericas.md)): una skin con el mismo id
  que una incluida la sustituye; las mal formadas se ignoran con un aviso en stderr.
- **Colores solo por `Theme`**; lo que falte en una skin toma el valor de Vidrio (`pick`). Un color
  nuevo: [runbooks/nuevo-color-de-skin.md](../runbooks/nuevo-color-de-skin.md).
- **Opción nueva**: [runbooks/nueva-opcion.md](../runbooks/nueva-opcion.md). Vacío = valor por
  defecto (`fallback` de su fila).
- **`TintProbe` (Canvas)** necesita su propio `loadImage` y su `Timer`, y estar dentro de la zona
  visible ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **Opciones que tocan Rust** (`calidad`, `historial`, `ytdlp`) se aplican al cargar y al cambiar,
  en `set_opcion`.

## Interfaz

`SettingsSheet.qml`: barra lateral de categorías; las filas sueltas se declaran en `optionRows`
(`cat`, `key`, `label`, `hint`, `fallback`, `options`); las de Cuenta y Plugins son bloques
propios. `--settings-cat id` abre una categoría para capturarla.

En Apariencia, diseño elegido por el propietario con sus muestras:

- **Skin**: cuatro tarjetas por fila con una miniatura pintada con los colores de cada skin
  (`SkinPreview`: barra de arriba, cuatro carátulas, barra de reproducción con su acento; las de
  carpeta con fondo lo muestran detrás), el nombre debajo y un aro en la elegida (`ChosenRing`).
  Debajo, la descripción de la elegida.
- **Mascota**: recuadros con su pose de reposo, «Ninguna» vacío y «Añadir…» (borde discontinuo),
  que abre la carpeta de mascotas.
- **Encabezados con dos botones** (`FolderHeading`): abrir la carpeta del usuario (se crea si
  falta) y recargar.

Los datos de las miniaturas salen de `skins_list` (Rust): `colores`, `radio` e `imagen` (fondo de la
skin o pose `reposo` de la mascota, con la ruta de su carpeta).

## Archivos

| Archivo | Contenido |
|---|---|
| `src/settings.rs` | Singleton `AppSettings`: vistas, skin, mascota, opciones; skins incluidas y del usuario |
| `qml/Theme.qml` | Tokens visuales: colores de la skin, opciones de aspecto, iconos, `renderEpoch` |
| `qml/SettingsSheet.qml` | Hoja de Opciones |
| `qml/Ambient.qml` | Modo ambiente |
| `qml/TintProbe.qml` | Color dominante de una carátula |
| `skins/*.json` | Las cuatro skins incluidas |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Leer y guardar una opción | [`opcion`](../../src/settings.rs), [`set_opcion`](../../src/settings.rs) |
| Vistas por defecto | [`DEFAULT_VIEWS`](../../src/settings.rs) |
| Skins incluidas | [`BUILTIN_SKINS`](../../src/settings.rs) |
| Juntar skins incluidas y del usuario | [`all_skins`](../../src/settings.rs) |
| Color con valor por defecto | [`pick`](../../qml/Theme.qml) |
| Imagen de una skin de carpeta | [`skinImage`](../../qml/Theme.qml) |
| Filas de Opciones | [`optionRows`](../../qml/SettingsSheet.qml) |
| Datos de las miniaturas | [`skins_list`](../../src/settings.rs), [`preview_image`](../../src/settings.rs) |
| Miniatura de una skin | [`SkinPreview`](../../qml/SettingsSheet.qml) |

## Dependencias

- **[resolucion](resolucion.md)** (`resolver::set_premium`, `daemon::set_enabled`): aplicar
  `calidad` e `ytdlp`.
- **[historial](historial.md)** (`history::set_enabled`): aplicar `historial`.
- **[sesion](sesion.md)** (`Account`): la pestaña Cuenta.
- **[plugins](plugins.md)** (`Plugins`): la pestaña Plugins.
- **[catalogo](catalogo.md)** (`Catalog`): secciones en «Vista de cada sección».
- **La usan:** todas (por `Theme` y `AppSettings`); [mascotas](mascotas.md) lee la elegida con
  `Theme.mascotImage`.

## Estado actual

- **Última verificación:** 2026-11-16, ambiente «Plano» en Inicio y en «Sonando» y la fila de
  Apariencia con sus cinco valores, capturas ([historial](../history/verificacion/personalizacion.md)).
- **Pruebas:** `preview_image` y `skins_list` en `cargo test`; capturas con `--settings-cat`.
- **Sin verificar:** «Plano» en una pantalla antigua de verdad (solo en Retina); skins claras (los velos asumen fondo oscuro); la miniatura de una skin de
  carpeta con fondo; abrir la carpeta en Linux (`xdg-open`).
- **Historial:** [docs/history/verificacion/personalizacion.md](../history/verificacion/personalizacion.md).

## Pendiente

- Editor de disposición, skins claras y skins con QML propio ([ROADMAP](../ROADMAP.md)).

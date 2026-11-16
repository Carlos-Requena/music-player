---
area: letra
titulo: Letra sincronizada
resumen: Letra de LRCLIB línea a línea y, si la trae, palabra a palabra, al estilo Better Lyrics, con tres calidades y retraso ajustable por canción.
archivos: [src/lyrics.rs, qml/LyricsView.qml, qml/LyricsTiming.qml]
opciones: [letraCalidad, letraTamano, letraFuente, letraPeso, letraAlineacion, letraAnimada, retraso:*]
adr: [ADR-13]
---

# Letra sincronizada

Pestaña «Letra» del panel lateral y de «Sonando». El aspecto se elige en Opciones › Apariencia; el
retraso, bajo la propia letra.

## Qué hace

- La línea que suena, entera y brillante; las palabras con tiempo se iluminan con un barrido; las
  líneas vacías son pausas instrumentales (y la intro larga también).
- **Calidad** (`letraCalidad`): «Calidad» (todo a 60 Hz), «Equilibrado» (barrido a 30 Hz, por
  defecto) y «Bajo» (10 Hz, sin cascada ni brillo).
- **Tamaño, fuente y grosor** (`letraTamano`, `letraFuente`, `letraPeso`) y animación
  (`letraAnimada`).
- **Alineación** (`letraAlineacion`): centrada (por defecto, la pidió el propietario), con cada
  renglón centrado en su zona, o a la izquierda. Las palabras se reparten en renglones según su
  ancho medido (`rows`) y cada renglón es un `Row`: un `Flow` no sabe centrar renglón a renglón.
  Centrada, la línea que suena va también en el centro vertical (`anchorRatio` 0,5; a la
  izquierda, al 37 % como Better Lyrics), y la letra nunca deja hueco arriba: al empezar llena la
  zona desde arriba y la línea que suena baja hasta el centro.
- **Retraso por canción** (`retraso:<videoId>`): «−» la adelanta y «+» la atrasa medio segundo;
  pulsar el texto la vuelve a poner en hora. Positivo: la letra va más tarde. Es un **pie
  discreto** centrado bajo la letra (`LyricsTiming`, diseño B elegido por el propietario entre
  cuatro): solo texto tenue «−  letra en hora  +», sin cápsula ni bordes; con retraso se ilumina y
  dice cuánto («Letra −0,5 s»). Lo pone la propia `LyricsView` (`showTiming`) en «Sonando» y en el
  panel lateral, y la letra se recorta encima de él.

## Reglas y decisiones

- **LRCLIB**, una base de datos abierta, sin sesión
  ([ADR-13](../decisions/ADR-13-letra-de-lrclib-con-un-solo-gestor.md)).
- **Un solo gestor de clics para toda la vista**, que calcula la línea con `childAt`, y **sin
  «hover»**: un gestor por línea sobre contenido animado subía la CPU a ~25 %
  ([TRAMPAS](../TRAMPAS.md#qt-quick-y-qml)).
- **El brillo es una copia desenfocada detrás**, no un `layer.effect` sobre la línea (el texto
  pasaría por una textura y se vería borroso). **Sin medios píxeles** en la elevación de las
  palabras: también emborronan.
- **Texto sin `Text.CurveRendering`** en «Calidad»: costaba ~95 MB más.
- **Ninguna palabra se sale de su línea:** una más ancha que la línea (en un recuadro estrecho,
  como «supercalifragilisticexpialidocious») se encoge hasta caber; las demás conservan su tamaño.
  Su ancho a tamaño completo lo mide una sola `FontMetrics` común (`metrics`): deducirlo del ancho
  pintado creaba un bucle de enlaces. En «Sonando», el tamaño base baja con el ancho del recuadro
  (`width / 12`, de 24 a 34).
- El retraso lo guardan `Catalog.lyricsDelay` y `Catalog.setLyricsDelay`; `Catalog.lyricsTime` da
  la posición corregida.

## Medidas

CPU acumulada de la app en 25 s reproduciendo la misma canción (ruido de ±1 s; ×4 = % de un
núcleo), 2026-11-14, M4 Pro, release ([método](../runbooks/medir-rendimiento.md#cpu)):

| | Panel lateral | «Sonando» | Memoria |
|---|---|---|---|
| Calidad (todo a 60 Hz) | 7,4–8,7 s | 9,2 s | ~286 MB |
| Equilibrado (barrido a 30 Hz) | 4,8–5,0 s | 6,4 s | ~285 MB |
| Bajo (10 Hz, sin cascada ni brillo) | 3,1–3,9 s | 4,2 s | ~276 MB |
| Referencia: pestaña Cola | 3,5 s | — | 274 MB |

La diferencia entre modos es de fotogramas: cada uno redibuja la ventana con su vidrio
desenfocado.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/lyrics.rs` | Petición a LRCLIB y lectura del LRC: líneas, pausas y palabras |
| `qml/LyricsView.qml` | La vista de la letra |
| `qml/LyricsTiming.qml` | Ajuste del retraso |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Pedir la letra | [`fetch`](../../src/lyrics.rs) |
| Leer el LRC | [`parse`](../../src/lyrics.rs) |
| Pausa larga de la intro | [`INTRO_GAP`](../../src/lyrics.rs) |
| Línea bajo el clic | [`lineUnder`](../../qml/LyricsView.qml) |
| Reloj del barrido | [`advance`](../../qml/LyricsView.qml) |
| Retraso guardado | [`setLyricsDelay`](../../qml/Catalog.qml) |

## Dependencias

- **[reproduccion](reproduccion.md)** (`Player.position`, `Player.seek`): posición y saltar a una
  línea.
- **[catalogo](catalogo.md)** (`Catalog.lyrics`, `Catalog.lyricsTime`): la letra ya convertida y el
  retraso.
- **[personalizacion](personalizacion.md)** (`AppSettings`): las opciones de aspecto.
- **La usan:** [ventana](ventana.md) (el panel y «Sonando»).

## Estado actual

- **Última verificación:** 2026-11-14, medidas de CPU y memoria de los tres modos en release
  (M4 Pro).
- **Pruebas:** `mod tests` de `src/lyrics.rs` (pausas e intro, varios tiempos por línea y
  palabras, sin texto no hay letra).
- **Sin verificar:** el coste de cada modo en Linux con el controlador de CachyOS.
- **Historial:** [docs/history/verificacion/letra.md](../history/verificacion/letra.md).

## Pendiente

- Letras de otras fuentes cuando LRCLIB no la tenga ([ROADMAP](../ROADMAP.md)).

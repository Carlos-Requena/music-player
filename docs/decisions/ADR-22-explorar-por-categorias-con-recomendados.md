---
adr: ADR-22
titulo: Explorar se muestra por categorías y empieza por «Recomendados», sacada del Inicio de YouTube Music
estado: aceptada
fecha: 2026-11-21
areas: [catalogo, vistas]
---

# ADR-22 · Explorar se muestra por categorías y empieza por «Recomendados», sacada del Inicio de YouTube Music

- **Estado:** Aceptada.
- **Registrada:** 2026-11-21
- **Ámbito:** [catalogo](../areas/catalogo.md), [vistas](../areas/vistas.md)

## Decisión

Amplía [ADR-19](ADR-19-explorar-con-listenbrainz.md) y [ADR-20](ADR-20-fuente-de-explorar-a-elegir.md):

- **Explorar en Muro es una cuadrícula de categorías** (`qml/CategoriasView.qml`): una tarjeta
  por zona, con su primera carátula a sangre y el nombre encima («Portada con rótulo», la A de
  tres que se propusieron). Al pulsarla se abre como un detalle (`Library.openZona`). Lomos y
  Cubeta siguen mostrando los elementos de todas las zonas seguidos.
- **La primera categoría es «Recomendados»** con las dos fuentes de Explorar. Sale del Inicio
  de YouTube Music (`ytm::recomendados`): las filas de canciones que YouTube propone ahí
  («Selecciones rápidas», personalizada con la sesión). El propietario pidió «lo que equivalga a
  おすすめ» de YouTube Music, que usa en japonés.
- **La fila se reconoce por su forma, no por su título**: un carrusel en columnas
  (`numItemsPerColumn`) de filas `musicResponsiveListItemRenderer`. El título cambia con el
  idioma y con la sesión («Selecciones rápidas», «Mixes de canciones», 「曲のミックス」…).
- **Si la petición falla, se queda la copia guardada** de Recomendados: si desapareciera, las
  tarjetas se correrían un sitio bajo el ratón.

## Alternativas descartadas

- **«Relacionado» de las últimas canciones del Historial**: recomendaciones propias a partir de lo
  que se escucha, ~7 peticiones. Fue la recomendada, pero el propietario eligió la de YouTube.
- **«Recomendado para ti» de ListenBrainz**: necesita escuchas allí; el propietario no tiene.
- **Reconocer la fila por su título**: se rompe con otro idioma o cuando YouTube cambia el nombre.
- **Tarjetas en mosaico 2×2 o en abanico** (B y C): el propietario eligió la A, que además carga una
  sola imagen por tarjeta.
- **Desplegar la categoría dentro de Explorar** en vez de abrirla como detalle: sin Reproducir ni
  Aleatorio.

## Motivo

El propietario quería ver Explorar como una cuadrícula de categorías más separadas, con un brillo
al pasar el ratón, y una de recomendaciones en primer lugar. El Explorar de YouTube Music (la
fuente que usa) no trae ninguna.

## Consecuencias

- Explorar hace una petición más (`FEmusic_home`), a la vez que la de `FEmusic_explore`: tarda lo
  que la más lenta. Con ListenBrainz, Recomendados se publica primero, sola.
- Con cuatro o cinco tarjetas en vez de un centenar de carátulas, Explorar ocupa menos memoria
  (cifras en la ficha de [vistas](../areas/vistas.md#medidas)).
- No se puede volver al Muro de carátulas en Explorar sin tocar `SectionView.qml`; Lomos y Cubeta
  siguen disponibles.

---
adr: ADR-07
titulo: La ventana de inicio de sesión va en un proceso aparte; el reproductor no carga ningún motor web
estado: aceptada
fecha: 2026-11-14
areas: [sesion]
---

# ADR-07 · La ventana de inicio de sesión va en un proceso aparte; el reproductor no carga ningún motor web

- **Estado:** Aceptada.
- **Registrada:** 2026-11-14 (reconstruida el 2026-11-15 a partir de la documentación de entonces; las alternativas sin medida son razonadas, no probadas)
- **Ámbito:** [sesion](../areas/sesion.md)

## Decisión

En macOS, `musicplayer --login <temporal>` abre un `WKWebView` (WebKit del sistema) sin arrancar Qt; en Linux, el binario aparte `musicplayer-login` (crate `login/`, Qt WebEngine, opcional). Ambos escriben las cookies de youtube.com y salen. Como alternativa, importar del navegador con yt-dlp.

## Alternativas descartadas

- **Qt WebEngine dentro del reproductor**: cargaría Chromium (cientos de MB) en el proceso de la app para usarlo una vez.
- **Disfrazar el agente de usuario de Chrome**: Google lo bloquea porque contradice las cabeceras `Sec-CH-UA`.
- **Solo importar del navegador**: en macOS exige «Acceso total al disco».

## Motivo

La sesión hace falta una vez; la memoria del reproductor es la primera prioridad.

## Consecuencias

- La ventana gasta memoria solo mientras está abierta.
- En Linux puede no estar (sin `qt6-webengine`): la app ofrece importar del navegador.
- La prevención de rastreo de WebKit se desactiva para no perder las cookies en las redirecciones.

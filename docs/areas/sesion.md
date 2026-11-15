---
area: sesion
titulo: Sesión de YouTube Music
resumen: Iniciar sesión (ventana propia o cookies del navegador), guardar solo las cookies de youtube.com y firmar las peticiones con SAPISIDHASH.
archivos: [src/account.rs, src/login_mac.mm, login/src/main.rs, login/src/login_linux.cpp]
opciones: []
adr: [ADR-07]
---

# Sesión de YouTube Music

Opciones › Cuenta. Con sesión hay biblioteca, pistas que YouTube reserva a cuentas, calidad
Premium y registro de escuchas.

## Qué hace

- **Ventana de inicio de sesión** (macOS siempre; Linux si se compiló con Qt WebEngine): abre la
  página de Google y, al volver a YouTube Music con `SAPISID`, guarda las cookies.
- **Importar del navegador** (Linux, y alternativa en macOS): `yt-dlp --cookies-from-browser`.
  En macOS exige «Acceso total al disco» (la app lo detecta y abre los ajustes de privacidad).
- **Comprobar al arrancar** (`Account.verify`): si YouTube ya no reconoce la sesión, la borra y
  avisa. Al iniciar o cerrar sesión se reinicia mpv y se recarga la biblioteca.

## Reglas y decisiones

- **La ventana va en un proceso aparte** y el reproductor no enlaza ningún motor web
  ([ADR-07](../decisions/ADR-07-inicio-de-sesion-en-proceso-aparte.md)).
- **Sin disfrazar el agente de usuario**: hacerse pasar por Chrome contradice las cabeceras
  `Sec-CH-UA` que el motor envía siempre y Google lo bloquea («este navegador puede no ser
  seguro»). En macOS sí se pone la `applicationNameForUserAgent` de Safari: sin ella Google lo
  trata como navegador embebido.
- **Solo las cookies de `youtube.com`**, en `cookies.txt` con permisos 600.
- **yt-dlp y mpv reciben una copia** (`cookies_copy`): yt-dlp reescribe el archivo de `--cookies`
  al terminar ([TRAMPAS](../TRAMPAS.md#youtube-yt-dlp-y-mpv)).
- **Las cookies solo se mandan a hosts `*.youtube.com`.**

## Cómo funciona

### Firma

Cada petición a InnerTube con sesión lleva `Cookie`, `X-Goog-AuthUser: 0`, `X-Origin` y
`Authorization: SAPISIDHASH <segundos>_<sha1("<segundos> <SAPISID> https://music.youtube.com")>`.

### macOS

`Account.signInWeb` lanza `musicplayer --login <temporal>` y espera. Ese proceso no arranca Qt:
`src/login_mac.mm` abre un `WKWebView` con un almacén de datos no persistente. Cuando la página
vuelve a `music.youtube.com` y existe `SAPISID`, escribe las cookies en formato Netscape (600) y
sale con 0; si se cierra la ventana, con 1.

Google pasa la sesión a youtube.com con una cadena de redirecciones y la prevención de rastreo de
WebKit perdía esas cookies (YouTube acababa en `/oops`). Se desactiva (ajuste privado
`_setResourceLoadStatisticsEnabled:`) y, si aun así youtube.com no recibe `SAPISID`, se copian a
`.youtube.com` las cookies de la cuenta de `.google.com`.

Depuración: `MUSICPLAYER_LOGIN_SHOT=ruta.png` guarda la primera página y `MUSICPLAYER_LOGIN_URL`
cambia la inicial.

### Linux

`Account.signInWeb` lanza `musicplayer-login <temporal>` (crate `login/`, Qt WebEngine Widgets con
un perfil privado), con el mismo protocolo. `login/build.rs` solo lo compila si encuentra
`qt6-webengine`; si no, responde 3 a `--check` y la app ofrece importar del navegador.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/account.rs` | Singleton `Account`: iniciar, comprobar y cerrar sesión, leer cookies, firmar |
| `src/login_mac.mm` | Ventana de macOS (WKWebView), compilada con `cc` desde `build.rs` |
| `login/src/main.rs` | Binario `musicplayer-login` de Linux |
| `login/src/login_linux.cpp` | La ventana de Qt WebEngine |

### Dónde está cada cosa

| Concepto | Símbolo |
|---|---|
| Cabeceras firmadas | [`headers`](../../src/account.rs) |
| Hacer algo con la sesión, si la hay | [`with_session`](../../src/account.rs) |
| Copia de las cookies para yt-dlp y mpv | [`cookies_copy`](../../src/account.rs) |
| Filtrar a youtube.com | [`youtube_lines`](../../src/account.rs) |
| Lanzar la ventana | [`login_web`](../../src/account.rs) |
| Importar del navegador | [`import`](../../src/account.rs) |
| Diagnóstico (`--probe account`) | [`diagnose`](../../src/account.rs) |

## Dependencias

- **[catalogo](catalogo.md)** (`ytm::account_name`): comprobar la sesión pidiendo el nombre de la
  cuenta.
- **[reproduccion](reproduccion.md)** (`audio::which`, reinicio de mpv): encontrar yt-dlp y
  reiniciar el motor con las opciones nuevas.
- **La usan:** [catalogo](catalogo.md), [resolucion](resolucion.md), [historial](historial.md),
  [personalizacion](personalizacion.md) (la pestaña Cuenta de Opciones).

## Estado actual

- **Última verificación:** sin registrar.
- **Pruebas:** `mod tests` de `src/account.rs` (solo cookies de youtube.com, bloqueo de Safari,
  sin `SAPISID` no hay sesión, formato de la firma).
- **Sin verificar:** la ventana de Linux con Wayland.
- **Historial:** [docs/history/verificacion/sesion.md](../history/verificacion/sesion.md).

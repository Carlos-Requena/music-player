---
area: sesion
titulo: Sesión de YouTube Music
resumen: Iniciar sesión (ventana propia o cookies del navegador), guardar solo las cookies de youtube.com y firmar las peticiones con SAPISIDHASH.
archivos: [src/account.rs, src/login_mac.mm, login/src/main.rs, login/src/login_linux.cpp, login/src/login_windows.rs]
opciones: []
adr: [ADR-07, ADR-24]
---

# Sesión de YouTube Music

Opciones › Cuenta. Con sesión hay biblioteca, pistas que YouTube reserva a cuentas, calidad
Premium y registro de escuchas.

## Qué hace

- **Ventana de inicio de sesión** (macOS y Windows siempre; Linux si se compiló con Qt WebEngine): abre la
  página de Google y, al volver a YouTube Music con `SAPISID`, guarda las cookies.
- **Importar del navegador** (alternativa): `yt-dlp --cookies-from-browser`.
  En macOS exige «Acceso total al disco» (la app lo detecta y abre los ajustes de privacidad). En
  Windows, Chrome, Edge y Brave cifran sus cookies de forma que yt-dlp no siempre puede leerlas:
  Firefox va primero en la lista y la interfaz lo avisa.
- **Comprobar al arrancar** (`Account.verify`): si YouTube ya no reconoce la sesión, la borra y
  avisa. Al iniciar o cerrar sesión se reinicia mpv y se recarga la biblioteca.

## Reglas y decisiones

- **La ventana va en un proceso aparte** y el reproductor no enlaza ningún motor web
  ([ADR-07](../decisions/ADR-07-inicio-de-sesion-en-proceso-aparte.md)).
- **Sin disfrazar el agente de usuario**: hacerse pasar por Chrome contradice las cabeceras
  `Sec-CH-UA` que el motor envía siempre y Google lo bloquea («este navegador puede no ser
  seguro»). En macOS sí se pone la `applicationNameForUserAgent` de Safari: sin ella Google lo
  trata como navegador embebido.
- **Solo las cookies de `youtube.com`**, en `cookies.txt` con permisos 600 (en Windows,
  `%APPDATA%\musicplayer`, que ya solo puede leer el usuario).
- **Windows: WebView2**, elegido por el propietario
  ([ADR-24](../decisions/ADR-24-version-de-windows.md)): ya viene con Windows y no añade nada al
  instalador. Nitidez: el proceso se declara consciente del DPI por monitor antes de crear la
  ventana; sin eso Windows la dibuja a 96 ppp y la amplía, borrosa.
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

### Windows

`Account.signInWeb` lanza `musicplayer-login.exe <temporal>` (el mismo crate `login/`,
`login/src/login_windows.rs` con `webview2-com`), junto al ejecutable. Abre una ventana Win32 con
WebView2 en modo InPrivate (las cookies no tocan el disco; `%LOCALAPPDATA%\musicplayer\webview2`
solo guarda la caché del motor). Al terminar de cargar `music.youtube.com`, pregunta a la página
por `ytcfg LOGGED_IN` y, si hay sesión, pide al gestor de cookies las de
`https://music.youtube.com`, se queda con las de youtube.com y sale con 0; cerrar la ventana, 1;
sin WebView2, 2. Como en macOS, la prevención de rastreo perdía las cookies de la cadena de
redirecciones de Google (YouTube acababa en `/oops`): el entorno se crea con
`EnableTrackingPrevention` a falso y, si YouTube sigue sin sesión y Google la tiene (`SAPISID`),
se copian a `.youtube.com` las cookies de la cuenta de `.google.com` y se vuelve a abrir YouTube
Music, una vez. Si otra ventana usa la carpeta de datos con otras opciones, se usa
`%LOCALAPPDATA%\musicplayer\webview2-2`. `MUSICPLAYER_LOGIN_URL` cambia la página inicial.

## Archivos

| Archivo | Contenido |
|---|---|
| `src/account.rs` | Singleton `Account`: iniciar, comprobar y cerrar sesión, leer cookies, firmar |
| `src/login_mac.mm` | Ventana de macOS (WKWebView), compilada con `cc` desde `build.rs` |
| `login/src/main.rs` | Binario `musicplayer-login` de Linux y Windows |
| `login/src/login_linux.cpp` | La ventana de Qt WebEngine |
| `login/src/login_windows.rs` | La ventana de WebView2 (Windows) |

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

- **Última verificación:** 2026-11-22, ventana de Windows en Windows 11: abre la pantalla de Google con las opciones nuevas y con la carpeta ocupada; el propietario vio acabar el inicio de sesión en `/oops` antes del arreglo ([historial](../history/verificacion/sesion.md)).
- **Pruebas:** `mod tests` de `src/account.rs` (solo cookies de youtube.com, bloqueo de Safari,
  sin `SAPISID` no hay sesión, formato de la firma).
- **Sin verificar:** la ventana de Linux con Wayland; en Windows, **el inicio de sesión completo**
  (que la sesión llegue a YouTube Music sin prevención de rastreo o con la copia de cookies, y las
  cookies guardadas) y la nitidez a 125–150 %; importar del navegador en Windows.
- **Historial:** [docs/history/verificacion/sesion.md](../history/verificacion/sesion.md).

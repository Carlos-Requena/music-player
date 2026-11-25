# Historial de verificación · Sesión de YouTube Music

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/sesion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-22 · Windows: el inicio de sesión acababa en `/oops`

- **Fallo:** en Windows 11, tras entrar en Google la ventana mostraba la página de las teles de YouTube (`/oops`), como le pasaba a macOS con WebKit: la prevención de rastreo de WebView2 pierde las cookies de la cadena de redirecciones.
- **Cambio:** `login/src/login_windows.rs` crea el entorno con `EnableTrackingPrevention` a falso y, si YouTube sigue sin sesión y Google la tiene, copia a `.youtube.com` las cookies de la cuenta de `.google.com` y vuelve a abrir YouTube Music (una vez). Con la carpeta de datos ocupada por otra ventana con otras opciones (`0x8007139F`), usa `webview2-2`.
- **Cómo:** Windows 11, `cargo build --release` y `cargo test --release` de `login/` sin avisos y en verde; `target\release\musicplayer-login.exe <temporal>` con `LOCALAPPDATA` aislado (abre «Inicia sesión · Acceder a YouTube Music», captura revisada) y con la carpeta real ocupada por la ventana antigua del propietario (pasa a `webview2-2` y abre). En el navegador integrado, `www.youtube.com/signin?action_handle_signin=true…` sin sesión lleva a `/oops`.
- **No verificado:** el inicio de sesión completo con una cuenta (no se pueden escribir credenciales en pruebas): ni que la sesión llegue sin la copia, ni la copia de cookies, ni el archivo guardado.

## 2026-11-22 · ventana de inicio de sesión de Windows con WebView2

- **Cómo:** `cargo build --release` sin avisos y `cargo test` en verde en macOS (M4 Pro); `PATH=$HOME/.cargo/bin:$PATH cargo check --target x86_64-pc-windows-msvc` -p musicplayer-login` y `cargo clippy` igual; en macOS, captura `--settings --settings-cat cuenta` con `HOME` aislado.
- **Resultado:** el login de Windows compila sin avisos de rustc ni de clippy; la pestaña Cuenta de macOS sale igual que antes.
- **No verificado:** la ventana en Windows (que Google acepte WebView2, la nitidez a 125–150 %, las cookies guardadas, el modo InPrivate) y los textos de Opciones en Windows.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.

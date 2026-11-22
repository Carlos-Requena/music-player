# Historial de verificación · Sesión de YouTube Music

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/sesion.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-22 · ventana de inicio de sesión de Windows con WebView2

- **Cómo:** `cargo build --release` sin avisos y `cargo test` en verde en macOS (M4 Pro); `PATH=$HOME/.cargo/bin:$PATH cargo check --target x86_64-pc-windows-msvc` -p musicplayer-login` y `cargo clippy` igual; en macOS, captura `--settings --settings-cat cuenta` con `HOME` aislado.
- **Resultado:** el login de Windows compila sin avisos de rustc ni de clippy; la pestaña Cuenta de macOS sale igual que antes.
- **No verificado:** la ventana en Windows (que Google acepte WebView2, la nitidez a 125–150 %, las cookies guardadas, el modo InPrivate) y los textos de Opciones en Windows.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.

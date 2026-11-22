# Historial de verificación · Plugins (Discord, Last.fm y ListenBrainz)

Cómo se verificó esta área, fecha a fecha. Es un registro: las cifras y lo que «no se verificó»
son de cuando se escribieron. El estado actual está en su [ficha](../../areas/plugins.md#estado-actual).

Lo nuevo va arriba: añade una sección `## AAAA-MM-DD · qué se verificó` encima de las anteriores.

## 2026-11-22 · Discord por tubería con nombre en Windows

- **Cómo:** `cargo build --release` sin avisos y `cargo test` en verde en macOS (M4 Pro); `PATH=$HOME/.cargo/bin:$PATH cargo check --target x86_64-pc-windows-msvc` de `src/plugins/discord.rs` con piezas de relleno.
- **Resultado:** compila sin avisos para Windows; las pruebas de Discord siguen en verde en macOS (la del Discord simulado queda solo para Unix).
- **No verificado:** Discord en Windows.

## 2026-11-17 · Plugin de ListenBrainz (rama `feature/explorar-listenbrainz`)

- **Cambio:** `src/plugins/listenbrainz.rs` (envío de escuchas con token), su fila en Opciones ›
  Plugins y `plugins::listenbrainz_user`; `plugins::Track` lleva el `videoId`.
- **Verificado:** `cargo test` (datos de la escucha); captura de Opciones › Plugins con un usuario
  guardado; `validate-token` y `submit-listens` según la documentación de ListenBrainz.
- **No verificado:** con un token real (no hay cuenta del propietario todavía): conectar,
  «escuchando ahora» y que la escucha llegue.

## Hasta el 2026-11-15

Las verificaciones de antes de la estructura por áreas no se apuntaron por área: lo que quedó
escrito está en el [changelog técnico](../CHANGELOG-TECNICO.md) y en la historia de git.

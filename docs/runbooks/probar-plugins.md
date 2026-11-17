# Probar Discord, Last.fm y ListenBrainz

`cargo test` cubre el protocolo de Discord (contra un socket simulado), la firma de Last.fm y sus
reglas de scrobble. Para Discord de extremo a extremo, un servidor falso.

## Discord de extremo a extremo

1. `HOME` de pruebas ([verificar-interfaz](verificar-interfaz.md#aislar-las-pruebas)) con
   `plugins.json`:

   ```bash
   DIR="$PRUEBA/Library/Application Support/musicplayer"   # Linux: "$PRUEBA/.config/musicplayer"
   mkdir -p "$DIR" && echo '{"discord": true, "discord_id": "1234"}' > "$DIR/plugins.json"
   ```

2. Un servidor que escuche en `$XDG_RUNTIME_DIR/discord-ipc-0` e imprima lo que recibe. Los
   sockets Unix admiten ~104 bytes de ruta: usa una ruta relativa corta
   (`export XDG_RUNTIME_DIR=d` desde `$PRUEBA`, con la carpeta creada).
3. Arranca con `--autoplay` y comprueba que llegan el saludo (`opcode 0`, `client_id: 1234`) y un
   `SET_ACTIVITY` con `type: 2`, el título y la barra de tiempo.

El formato de los mensajes está en [plugins](../areas/plugins.md#cómo-funciona).

## Last.fm

No hay servidor falso: las reglas se prueban con `cargo test` (`src/plugins/lastfm.rs`). Con una
cuenta real lo prueba el propietario (que «escuchando ahora» aparezca y que el scrobble llegue tras
la mitad de la pista).

## ListenBrainz y Explorar

- **Envío de escuchas:** `cargo test` (`src/plugins/listenbrainz.rs`). Con un token real lo prueba
  el propietario: en listenbrainz.org/user/<usuario> aparece «Playing now» y, tras la mitad de la
  pista, la escucha.
- **Explorar sin cuenta propia:** cualquier usuario público sirve, sin token.
  `HOME="$PRUEBA" ./target/release/musicplayer --probe explore mr_monkey` imprime las zonas.
  Para verlo en la ventana, un `plugins.json` de prueba con un token falso (no se valida al
  leerlo; el envío queda desactivado):

  ```bash
  echo '{"listenbrainz_token": "falso", "listenbrainz_user": "mr_monkey"}' > "$DIR/plugins.json"
  ```

- La primera carga busca cada canción en YouTube Music (unas 150): no la repitas sin motivo; la
  caché de búsquedas (`<caché>/musicplayer/listenbrainz-youtube.json` del `HOME` de pruebas) hace
  que las siguientes solo pidan a ListenBrainz.

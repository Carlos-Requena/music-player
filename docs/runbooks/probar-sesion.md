# Probar el camino con sesión

**Norma:** nunca importes las cookies del navegador del propietario ni uses su `cookies.txt` en
una prueba ([AGENTES §7](../AGENTES.md#7-norma-los-datos-del-propietario-no-se-tocan)). Lo que
necesite una sesión real (la biblioteca de su cuenta, el historial, Premium) lo comprueba él: dile
exactamente qué mirar.

## Sesión caducada (lo que sí se prueba solo)

La app debe avisar de que la sesión caducó, borrarla y seguir funcionando sin ella.

1. `HOME` de pruebas ([verificar-interfaz](verificar-interfaz.md#aislar-las-pruebas)).
2. Escribe un `cookies.txt` falso con un `SAPISID` inventado, en formato Netscape:

   ```bash
   DIR="$PRUEBA/Library/Application Support/musicplayer"   # Linux: "$PRUEBA/.config/musicplayer"
   mkdir -p "$DIR"
   printf '# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t2000000000\tSAPISID\tinventado123\n' > "$DIR/cookies.txt"
   chmod 600 "$DIR/cookies.txt"
   ```

3. Arranca con captura de la pestaña Cuenta:

   ```bash
   HOME="$PRUEBA" MUSICPLAYER_SILENT=1 ./target/release/musicplayer \
     --settings-cat cuenta --shot "$PRUEBA/s.png" --delay 8000
   ```

4. Comprueba: el aviso de sesión caducada, que `cookies.txt` ya no está y que Inicio carga.

## Lo demás

- `cargo test` cubre la lectura de cookies (solo youtube.com), el bloqueo de Safari y el formato de
  la firma (`src/account.rs`).
- `--probe account` dice si YouTube reconoce la sesión guardada; con la del propietario, solo si
  él lo pide.
- La ventana de inicio de sesión: `MUSICPLAYER_LOGIN_SHOT=ruta.png` guarda la primera página y
  `MUSICPLAYER_LOGIN_URL` cambia la inicial ([sesion](../areas/sesion.md#macos)). Llegar a iniciar
  sesión lo hace el propietario: tú no escribes contraseñas.

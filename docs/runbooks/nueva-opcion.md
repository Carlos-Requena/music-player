# Añadir una opción

Las opciones son un mapa clave → valor ([ADR-11](../decisions/ADR-11-skins-en-json-y-opciones-genericas.md)):
una nueva no toca Rust salvo que Rust tenga que reaccionar a ella. Explicado con un ejemplo:
[GUIA §7.1](../GUIA.md#71-añadir-una-opción-en-ajustes).

## Pasos

1. **¿De qué área es?** Su ficha en [docs/areas/](../areas/). La clave, en `camelCase` y en
   español (`letraTamano`).
2. **La fila**, en `optionRows` de `qml/SettingsSheet.qml`, con su categoría (`cat`:
   `reproduccion`, `apariencia` o `vistas`), `label`, `hint` si hace falta, `fallback` (el valor por
   defecto) y `options`.
3. **Leerla** donde se use, con `void AppSettings.revision` delante para que el enlace se
   actualice:

   ```qml
   readonly property bool segundos: { void AppSettings.revision; return AppSettings.opcion("segundos") !== "no" }
   ```

   Vacío es el valor por defecto. Si la usan varios archivos, en `Theme.qml`.
4. **Si Rust tiene que reaccionar**, en `src/settings.rs`: al cargar (como `ytdlp`, `calidad`,
   `historial`) y en `set_opcion`.
5. **Documentarla:** la clave en el `opciones:` de la ficha y su comportamiento en «Qué hace».
   Una clave con sufijo variable se escribe `prefijo:*` (como `retraso:*`).
6. **Comprobar:** `python3 scripts/docs.py index` y `check` (falla si la clave del código no está en
   ninguna ficha), y una captura con `--settings-cat <categoría>` y otra con la opción puesta
   ([verificar-interfaz](verificar-interfaz.md#aislar-las-pruebas)).

## Errores habituales

- Olvidar `void AppSettings.revision`: el valor no cambia hasta reiniciar.
- Guardar el valor por defecto: `setOpcion(clave, "")` lo borra y deja el `fallback`.
- Un botón de opción sin 44 px de área o sin foco visible.

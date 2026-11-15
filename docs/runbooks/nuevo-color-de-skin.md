# Añadir un color a las skins

Los colores solo pasan por `Theme` ([AGENTES §6](../AGENTES.md#6-normas-de-interfaz)). Un color
que deba cambiar con la skin es una clave nueva de `colores`.

## Pasos

1. En `qml/Theme.qml`: `readonly property color miColor: pick("miColor", "#FF8800")`; el segundo
   valor es el de por defecto (el de Vidrio).
2. `"miColor": "#…"` en la sección `colores` de **las cuatro** skins de `skins/` (`vidrio`,
   `medianoche`, `grafito`, `neon`).
3. Úsalo como `Theme.miColor`. Nunca un color escrito a mano en un componente.
4. Si quien usa la app puede ponerlo en su skin, añádelo a la lista de claves del
   [README](../../README.md#crear-una-skin).
5. Capturas con al menos dos skins ([verificar-interfaz](verificar-interfaz.md)).

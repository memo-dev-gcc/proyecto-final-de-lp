# Cómo conectarnos para jugar

## Qué necesitamos

- Cuatro navegadores y una red Wi-Fi o LAN que permita comunicación entre equipos.
- Una computadora anfitriona con Elixir y Erlang/OTP. Las otras tres no necesitan instalar Elixir.
- El repositorio descargado en el anfitrión. La primera descarga de dependencias requiere internet; jugar por LAN no requiere un servidor en internet.

## 1. Encender el servidor

En la carpeta del proyecto, el anfitrión ejecuta:

```sh
mix local.hex --force
mix deps.get
mix run --no-halt
```

El primer comando solo es necesario al configurar Hex. El servidor escucha en el puerto 4000. Se deja esta terminal abierta durante toda la demostración.

## 2. Encontrar la IP del anfitrión

En macOS: `ipconfig getifaddr en0`, o Ajustes del Sistema → Wi-Fi → Detalles → Dirección IP.
En Windows: `ipconfig` y buscar Dirección IPv4 del adaptador Wi-Fi.
En Linux: `hostname -I` y escoger la IP de la red local.

Ejemplo ilustrativo: `192.168.1.25`. Debe reemplazarse por la IP real; puede cambiar al cambiar de red.

## 3. Abrir el juego en los cuatro navegadores

Si la IP real fuera la del ejemplo, todos abren:

```text
http://192.168.1.25:4000
```

No utilizar localhost desde las otras computadoras: localhost siempre significa la propia computadora. El anfitrión debe usar también su IP LAN antes de copiar la invitación. Si se cambia PORT, se cambia el puerto de la dirección.

## 4. Entrar a la misma sala

Los cuatro escriben el mismo código, por ejemplo AULA01. Cada uno introduce su nombre y elige un vehículo disponible. Todos pulsan Estoy listo; comienza la cuenta atrás. Para esta demostración se utiliza Entrar a la sala, no Probar movimiento.

## 5. Revisar la sincronización

Un piloto se mueve con WASD y los otros confirman que lo ven. Se repite con disparos y cambios de vida. Se documentan equipos, red y resultado. Las pruebas automatizadas usan cuatro clientes en un equipo; esta prueba física sigue siendo parte de la validación final.

## Si no conecta

- Comprobar que la terminal siga ejecutando Elixir y que la página funcione en el anfitrión.
- Confirmar misma red, IP correcta y puerto 4000.
- Permitir conexiones entrantes de Erlang en el firewall; no desactivar todo el firewall.
- Si el campus aísla dispositivos, usar una red propia o un punto de acceso que permita comunicación entre clientes.
- En otro lugar o red distinta se necesita desplegar el servidor en internet; el repositorio GitHub almacena código y documentos, no ejecuta este servidor.

## Demostración con un solo equipo

Probar movimiento abre una arena sin rivales y permite revisar controles y paredes. Para probar el multijugador sin otros equipos, abrir cuatro pestañas con el mismo código y cuatro vehículos distintos. Solo la pestaña activa recibe teclado.

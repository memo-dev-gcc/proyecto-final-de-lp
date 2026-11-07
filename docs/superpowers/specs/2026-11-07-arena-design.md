# Arena de acero

Implementar el diseño aprobado en el primer avance: combate de carros 2D para cuatro jugadores, servidor autoritativo Elixir con actores y funciones puras, interfaz Canvas inspirada en el concepto generado. Proyecto independiente en Projects/arena-de-acero.

## Diseño y decisiones
- Un navegador por jugador; salas mediante código compartible. Cuatro pilotos distintos, uno por jugador: Rayo rápido y frágil; Muro lento resistente; Chispa daño bajo y disparo frecuente; Martillo daño alto y recarga lenta.
- Lobby, selección exclusiva, preparado, cuenta atrás al estar cuatro preparados, partida 180 segundos y revancha. Ganador por supervivencia; empate si varios sobreviven al tiempo o ninguno sobrevive.
- Física top-down con cuatro orientaciones, pasos continuos de simulación fija, paredes indestructibles, un proyectil por disparo, colisiones con paredes y carros, sin habilidades ni bots. Actualización 30 Hz; servidor limita desplazamiento/cadencia. El movimiento continuo simplifica sensación visual sin cambiar cuatro direcciones del avance.
- Servidor: Bandit + Plug + WebSockAdapter + Jason; GenServer de partida y proceso WebSock por jugador bajo Bandit. Registry y DynamicSupervisor para salas. Datos de partida inmutables y módulo Reglas puro, sin IO ni reloj externo.
- Protocolo JSON: bienvenida, estado, error desde servidor; entrar(nombre,personaje,sala), elegir(personaje), listo(valor), input(direccion,disparar), revancha desde cliente. El socket asigna identidad; nunca se aceptan posiciones/daño del cliente.
- Desconexión libera slot en lobby, elimina en partida, vuelve a lobby sin jugadores. Sin persistencia: reiniciar servidor borra salas. Reconexión de transporte vuelve a lobby o informa partida en curso.
- Interfaz española, arte pixel propio dibujado por Canvas, salud de cuatro pilotos, sonido local opcional, efectos limitados, controles flechas/WASD + espacio, pantalla completa, invitación por enlace. Soporte teclado y botones táctiles.
- Nombres consistentes español con términos técnicos ingleses: estado_partida, player_id, tick_ms, proyectiles, cooldown_ticks. Comentarios/documentación españoles.
- No base de datos, cuentas, servicios externos, assets descargados obligatorios ni build frontend.

## Dirección visual
Asfalto #252933, acero #697381, concreto #c9c7ba, amarillo #f5c542, azul #5ba3ff, rojo #ee5c55 y verde #76cf5b. Paneles metálicos y señalización industrial con propósito: cuatro colores identifican jugadores. Arena central como protagonista; lobby superpuesto claro y compacto; tipografía Impact para título y sistema sans/monospace para información. Sprites de cuatro siluetas distintas, paredes repetibles y textura de asfalto determinista.

## Aceptación
Cuatro sesiones reales ven el mismo estado, se preparan y juegan; quinto rechazado sin afectar partida; disparos y daño validados en servidor; eliminados no pueden actuar; revancha limpia estado; desconexiones se gestionan; nombres inválidos y mensajes malformados no tumban servidor. README explica BEAM, procesos, funciones y ejecución LAN.

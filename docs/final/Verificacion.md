# Verificación de la entrega final

Entorno: macOS, Elixir 1.20.5, Erlang/OTP 29, Node.js y Chromium de Playwright. Versión de proyecto 1.0.0.

## Resultado

- mix format --check-formatted: correcto.
- mix compile --warnings-as-errors: correcto.
- mix test: 26 pruebas aprobadas.
- npm run test:network: una prueba aprobada, con cuatro WebSockets reales y comparación de estados.
- npm run test:e2e: cinco pruebas aprobadas.
- Dos PDFs renderizados y revisados visualmente: informe de cinco páginas y manual de cuatro.
- Los documentos del Avance II permanecen intactos.

## Comportamientos cubiertos

Conexión de cuatro jugadores, rechazo de un quinto, selección exclusiva, preparados, cuenta atrás, mensajes inválidos, identidad autorizada, movimiento por teclado, foco y pérdida de foco, paredes, colisiones entre vehículos, cadencia, daño, empate y victoria, desconexión y revancha.

Objetos: curación máxima y reaparición; escudo frente a varios impactos; turbo y renovación; cinco disparos potentes y regreso al daño base; cajas y objeto único; carga de mina, armado, activación, daño al dueño cercano, caducidad y bloqueo de onda por paredes y cajas; recogida simultánea sin duplicación; eliminados sin recogida; revancha sin efectos residuales.

En navegador se observó la recogida real del turbo y la colocación de una mina con E, con actualización del HUD. Las capturas se incluyen en docs/capturas con prefijo final_.

## Alcance de la evidencia

Los cuatro clientes automatizados se ejecutaron en una computadora. No se presenta como una prueba realizada en cuatro computadoras físicas ni una medición de rendimiento de un servidor público. La guía de conexión explica cómo repetir la comprobación por LAN con los compañeros.

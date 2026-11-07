MANUAL DEL LENGUAJE · AVANCE II

# Elixir para Arena de acero

Fundamentos y uso en el proyecto

## 1  Qué es Elixir y por qué se utiliza

Elixir es un lenguaje funcional que se ejecuta sobre la máquina virtual BEAM, también utilizada por Erlang. BEAM administra procesos ligeros y su comunicación mediante mensajes. En el proyecto permite coordinar jugadores conectados sin compartir memoria mutable entre sus procesos.

El lenguaje fue asignado al equipo y encaja con los requisitos de concurrencia e inmutabilidad. Su principal aporte es la coordinación del servidor. La interfaz HTML/Canvas dibuja el juego, mientras que las reglas permanecen en Elixir. WebSockets transporta mensajes; no sustituye la lógica que calcula movimiento y daño.

## 2  Instalación y primeros comandos

El entorno probado utiliza Elixir 1.20.5 y Erlang/OTP 29. Para instalarlo se sigue la guía oficial del sistema operativo. En macOS con Homebrew se puede ejecutar brew install elixir. En Windows, IEx puede iniciarse con iex.bat para evitar el alias iex de PowerShell.

```elixir
elixir --version   # consultar versión
iex                # consola interactiva
# Dentro de IEx:
2 + 3
"Arena" <> " de acero"
# Salir: Ctrl+C dos veces
```

## 3  Tipos y estructuras más utilizadas

| Tipo | Ejemplo | Uso en el juego |
| --- | --- | --- |
| Número | 85, 4.2 | Vida, posición y velocidad. |
| Booleano | true, false | Preparado y disparar. |
| String | "rayo" | Personaje e identificador recibido por JSON. |
| Átomo | :ok, :error | Etiquetas internas de resultados. |
| Tupla | {:ok, estado} | Respuesta con estado o error. |
| Lista | [bala_1, bala_2] | Proyectiles e impactos. |
| Mapa | %{vida: 85, x: 100} | Jugador y estado de la partida. |

El código distingue claves átomo, como :vida, de claves string, como "tipo". Jason decodifica los objetos JSON con claves string. Los mensajes externos se validan y no se convierten libremente a átomos.


---

## 4  Módulos y funciones puras

Un módulo agrupa funciones. def define una función pública y defp una privada. nombre/aridad identifica cuántos argumentos recibe: tick/1 recibe uno. Una función pura depende de sus argumentos y no realiza efectos externos; para los mismos datos produce el mismo resultado.

```elixir
defmodule EjemploReglas do
  def recibir_dano(jugador, dano) when dano >= 0 do
    %{jugador | vida: max(0, jugador.vida - dano)}
  end
end

original = %{vida: 85, x: 100}
nuevo = EjemploReglas.recibir_dano(original, 20)
# original.vida sigue siendo 85; nuevo.vida es 65
```

Este ejemplo es didáctico. En el juego, Arena.Reglas aplica cambios sobre mapas nuevos; las funciones de daño no modifican el mapa anterior. Reasignar el nombre de una variable no hace mutable el valor al que estaba asociado.

## 5  Pattern matching y control de flujo

El operador = hace coincidir patrones. Permite extraer datos de una tupla y distinguir respuestas correctas de errores. case elige una rama según la estructura y los valores del resultado. Las guardas, como when dano >= 0, restringen las condiciones de una función.

```elixir
case Arena.Reglas.agregar(estado, "p1", "Ana", "rayo") do
  {:ok, actualizado} -> actualizado
  {:error, motivo} -> IO.puts(motivo)
end
```

El ejemplo utiliza IO.puts para mostrar un error y, por ello, esa rama tiene un efecto externo. En el proyecto los callbacks de procesos manejan estos resultados; las reglas retornan datos en lugar de imprimir o enviar información por red.

## 6  Enum y el operador pipe

Enum transforma colecciones sin un contador mutable. filter selecciona elementos, map transforma y reduce acumula un resultado nuevo. El pipe |> coloca el resultado anterior como primer argumento de la siguiente función.

```elixir
jugadores = [%{vida: 85}, %{vida: 0}, %{vida: 100}]
vivos =
  jugadores
  |> Enum.filter(fn jugador -> jugador.vida > 0 end)
  |> Enum.count()
# vivos == 2
```

En Arena.Reglas.tick/1 se encadenan pasos de movimiento, disparo, colisiones y resolución del final. Separar estos cálculos facilita entender y probar una regla a la vez.


---

## 7  Procesos y paso de mensajes

Un proceso Elixir es una tarea ligera administrada por BEAM, no otra computadora ni un proceso completo del sistema operativo. Cada proceso tiene una identidad PID y un buzón. send envía mensajes; receive busca un mensaje que coincida con un patrón.

```elixir
principal = self()
spawn(fn -> send(principal, {:piloto_listo, "Ana"}) end)
receive do
  {:piloto_listo, nombre} -> nombre
after
  1000 -> :sin_respuesta
end
```

La concurrencia permite que varias conexiones estén activas a la vez. No significa que todos cambien el mismo mapa simultáneamente. En este juego el coordinador procesa sus mensajes de forma secuencial y conserva un único estado autorizado por sala.

## 8  GenServer y supervisión

GenServer organiza un proceso que mantiene estado y responde a mensajes. init prepara el estado; handle_call recibe solicitudes con respuesta; handle_cast atiende envíos asíncronos; handle_info maneja otros mensajes, incluidos ticks y monitores. Call espera una respuesta; cast no la espera.

```elixir
# Ejemplo mínimo, independiente de Arena.Partida
defmodule ContadorDemo do
  use GenServer
  def start_link, do: GenServer.start_link(__MODULE__, 0)
  def init(valor), do: {:ok, valor}
  def handle_call(:leer, _origen, valor) do
    {:reply, valor, valor}
  end
  def handle_cast(:sumar, valor) do
    {:noreply, valor + 1}
  end
end
{:ok, pid} = ContadorDemo.start_link()
GenServer.cast(pid, :sumar)
GenServer.call(pid, :leer)  # devuelve 1
```

El supervisor inicia y vigila procesos según su política. Arena.Application usa supervisión, Registry localiza salas y DynamicSupervisor crea coordinadores cuando se solicitan. Las salas son temporales: no se promete recuperar una partida perdida ni persistir datos después de reiniciar.

El proceso Arena.Socket representa la conexión de un jugador. Un monitor avisa al coordinador cuando esa conexión termina, permitiendo retirar o eliminar el vehículo. Los cálculos puros siguen separados de este manejo de mensajes.


---

## 9  Herramientas y ejecución del proyecto

Mix administra dependencias, compilación y tareas. Hex distribuye paquetes y mix.lock fija las versiones resueltas. El proyecto utiliza Bandit y Plug para HTTP, WebSockAdapter/WebSock para la conexión persistente y Jason para JSON. No necesita base de datos.

```elixir
mix local.hex --force
mix deps.get
mix run --no-halt
# En otro terminal, o antes de iniciar el servidor:
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Para explorar el proyecto de forma interactiva, iniciar iex -S mix. La aplicación también inicia su servidor: cerrar antes otra instancia que use el mismo puerto. En IEx, h muestra ayuda y c permite compilar un archivo; para esta aplicación se recomienda compilar mediante Mix.

## 10  Ejercicio reproducible y pruebas

```elixir
# Dentro de iex -S mix:
estado = Arena.Reglas.nueva()
{:ok, nuevo} = Arena.Reglas.agregar(estado, "demo", "Ana", "rayo")
map_size(estado.jugadores)  # 0
map_size(nuevo.jugadores)  # 1
```

El ejercicio demuestra que agregar devuelve un estado diferente sin cambiar el anterior. ExUnit verifica reglas con datos controlados y también el ciclo de vida de salas. Las pruebas de navegador comprueban teclado, interfaz y cuatro clientes reales; no sustituyen la revisión del comportamiento en la red del aula.

## 11  Errores habituales

| Problema | Acción recomendada |
| --- | --- |
| mix no se reconoce | Instalar Elixir y revisar PATH; abrir de nuevo la terminal. |
| Puerto ocupado | Cerrar la instancia anterior o usar PORT=4100 y abrir ese puerto. |
| MatchError | Revisar la forma del resultado y manejar {:error, motivo}. |
| Movimiento no responde | Enfocar la arena y comprobar conexión y modo de juego. |

## 12  Referencias oficiales

Elixir Core Team. Introducción e instalación. https://hexdocs.pm/elixir/introduction.html
Elixir Core Team. Pattern matching. https://hexdocs.pm/elixir/pattern-matching.html
Elixir Core Team. Processes. https://hexdocs.pm/elixir/processes.html
Elixir Core Team. GenServer. https://hexdocs.pm/elixir/GenServer.html
Bandit. https://hexdocs.pm/bandit/Bandit.html
WebSock. https://hexdocs.pm/websock/WebSock.html
WebSockAdapter. https://hexdocs.pm/websock_adapter/WebSockAdapter.html

Los ejemplos del manual son didácticos y se distinguen de las funciones reales del repositorio. El documento acompaña el Avance II de Arena de acero.

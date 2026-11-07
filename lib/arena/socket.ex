defmodule Arena.Socket do
  @moduledoc "Un actor WebSock por navegador: valida mensajes y representa su identidad ante la partida."
  @behaviour WebSock
  @impl true
  def init(_) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

    {:push,
     {:text,
      Jason.encode!(%{
        tipo: "hola",
        player_id: id,
        personajes: Arena.Reglas.personajes(),
        mapa: Arena.Reglas.mapa(),
        ancho: 1120,
        alto: 640
      })},
     %{id: id, partida: nil, sala: nil, ventana: System.monotonic_time(:millisecond), mensajes: 0}}
  end

  @impl true
  def handle_in({texto, [opcode: :text]}, estado) do
    ahora = System.monotonic_time(:millisecond)

    estado =
      if ahora - estado.ventana > 1000, do: %{estado | ventana: ahora, mensajes: 0}, else: estado

    estado = %{estado | mensajes: estado.mensajes + 1}

    if estado.mensajes > 100 do
      {:ok, estado}
    else
      case Jason.decode(texto) do
        {:ok, %{} = mensaje} -> procesar(mensaje, estado)
        _ -> error("Mensaje inválido.", estado)
      end
    end
  catch
    :exit, _ -> error("La sala se cerró. Vuelve a entrar.", %{estado | partida: nil, sala: nil})
  end

  def handle_in(_, estado), do: error("Usa mensajes de texto JSON.", estado)

  defp procesar(
         %{"tipo" => "practica", "nombre" => nombre, "personaje" => personaje},
         %{partida: nil} = estado
       ) do
    codigo = Base.encode16(:crypto.strong_rand_bytes(4))

    with {:ok, partida, sala} <- Arena.Salas.obtener(codigo),
         :ok <- Arena.Partida.entrar(partida, self(), estado.id, nombre, personaje),
         :ok <- Arena.Partida.practica(partida, estado.id) do
      Process.monitor(partida)
      nuevo = %{estado | partida: partida, sala: sala}
      {:push, {:text, Jason.encode!(%{tipo: "dentro", player_id: estado.id, sala: sala})}, nuevo}
    else
      {:error, texto} -> error(texto, estado)
    end
  end

  defp procesar(
         %{"tipo" => "entrar", "nombre" => nombre, "personaje" => personaje, "sala" => codigo},
         %{partida: nil} = estado
       ) do
    with {:ok, partida, sala} <- Arena.Salas.obtener(codigo),
         :ok <- Arena.Partida.entrar(partida, self(), estado.id, nombre, personaje) do
      Process.monitor(partida)
      nuevo = %{estado | partida: partida, sala: sala}
      {:push, {:text, Jason.encode!(%{tipo: "dentro", player_id: estado.id, sala: sala})}, nuevo}
    else
      {:error, texto} -> error(texto, estado)
    end
  end

  defp procesar(%{"tipo" => "ping"}, estado), do: {:push, {:text, "{\"tipo\":\"pong\"}"}, estado}

  defp procesar(
         %{"tipo" => "input", "direccion" => direccion, "disparar" => disparar},
         %{partida: partida} = estado
       )
       when is_pid(partida) and is_boolean(disparar) do
    Arena.Partida.input(partida, estado.id, direccion, disparar)
    {:ok, estado}
  end

  defp procesar(%{"tipo" => tipo} = mensaje, %{partida: partida} = estado)
       when is_pid(partida) and tipo in ["elegir", "listo", "revancha"] do
    case Arena.Partida.accion(partida, estado.id, mensaje) do
      :ok -> {:ok, estado}
      {:error, texto} -> error(texto, estado)
    end
  end

  defp procesar(_, estado), do: error("Acción inválida. Entra a una sala para jugar.", estado)

  defp error(texto, estado),
    do: {:push, {:text, Jason.encode!(%{tipo: "error", mensaje: texto})}, estado}

  @impl true
  def handle_info({:snapshot, json}, estado), do: {:push, {:text, json}, estado}

  def handle_info({:DOWN, _, :process, pid, _}, %{partida: pid} = estado),
    do: error("La sala se cerró. Vuelve a entrar.", %{estado | partida: nil, sala: nil})

  def handle_info(_, estado), do: {:ok, estado}
end

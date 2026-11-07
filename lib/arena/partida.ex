defmodule Arena.Partida do
  @moduledoc "Actor de una sala. Serializa acciones, avanza simulación y publica un único snapshot a sus sockets."
  use GenServer, restart: :temporary
  alias Arena.Reglas
  @tick_ms 33
  def start_link(opts),
    do:
      GenServer.start_link(__MODULE__, opts,
        name: {:via, Registry, {Arena.Registro, Keyword.fetch!(opts, :sala)}}
      )

  def entrar(pid, socket_pid, id, nombre, personaje),
    do: GenServer.call(pid, {:entrar, socket_pid, id, nombre, personaje})

  def accion(pid, id, mensaje), do: GenServer.call(pid, {:accion, id, mensaje})

  def input(pid, id, direccion, disparar),
    do: GenServer.cast(pid, {:input, id, direccion, disparar})

  def estado(pid), do: GenServer.call(pid, :estado)
  @impl true
  def init(opts) do
    automatico = Keyword.get(opts, :automatico, true)
    if automatico, do: Process.send_after(self(), :tick, @tick_ms)
    Process.send_after(self(), :limpiar, 15_000)
    {:ok, %{juego: Reglas.nueva(), clientes: %{}, sala: opts[:sala], automatico: automatico}}
  end

  @impl true
  def handle_call({:entrar, socket_pid, id, nombre, personaje}, _from, estado) do
    case Reglas.agregar(estado.juego, id, nombre, personaje) do
      {:ok, juego} ->
        monitor_ref = Process.monitor(socket_pid)

        nuevo = %{
          estado
          | juego: juego,
            clientes: Map.put(estado.clientes, id, {socket_pid, monitor_ref})
        }

        publicar(nuevo)
        {:reply, :ok, nuevo}

      {:error, _} = error ->
        {:reply, error, estado}
    end
  end

  def handle_call({:accion, id, mensaje}, _from, estado) do
    case Reglas.accion(estado.juego, id, mensaje) do
      {:ok, juego} ->
        nuevo = %{estado | juego: juego}
        publicar(nuevo)
        {:reply, :ok, nuevo}

      {:error, _} = error ->
        {:reply, error, estado}
    end
  end

  def handle_call(:estado, _from, estado), do: {:reply, Reglas.snapshot(estado.juego), estado}
  @impl true
  def handle_cast({:input, id, direccion, disparar}, estado),
    do: {:noreply, %{estado | juego: Reglas.input(estado.juego, id, direccion, disparar)}}

  @impl true
  def handle_info(:tick, estado) do
    if estado.automatico, do: Process.send_after(self(), :tick, @tick_ms)
    nuevo = %{estado | juego: Reglas.tick(estado.juego)}

    if nuevo.juego.fase in ["jugando", "cuenta"] or nuevo.juego != estado.juego,
      do: publicar(nuevo)

    {:noreply, nuevo}
  end

  def handle_info({:DOWN, ref, :process, _pid, _motivo}, estado) do
    case Enum.find(estado.clientes, fn {_, {_, monitor_ref}} -> ref == monitor_ref end) do
      {id, _} ->
        nuevo = %{
          estado
          | clientes: Map.delete(estado.clientes, id),
            juego: Reglas.quitar(estado.juego, id)
        }

        if map_size(nuevo.clientes) == 0 do
          {:stop, :normal, nuevo}
        else
          publicar(nuevo)
          {:noreply, nuevo}
        end

      nil ->
        {:noreply, estado}
    end
  end

  def handle_info(:limpiar, %{clientes: clientes} = estado) when map_size(clientes) == 0,
    do: {:stop, :normal, estado}

  def handle_info(:limpiar, estado), do: {:noreply, estado}
  def handle_info(_, estado), do: {:noreply, estado}

  defp publicar(estado) do
    json =
      Jason.encode!(%{tipo: "estado", sala: estado.sala, estado: Reglas.snapshot(estado.juego)})

    for {_, {socket_pid, _}} <- estado.clientes, do: send(socket_pid, {:snapshot, json})
  end
end

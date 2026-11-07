defmodule Arena.PartidaTest do
  use ExUnit.Case, async: false
  alias Arena.Partida

  setup do
    if Process.whereis(Arena.Registro) == nil,
      do: start_supervised!({Registry, keys: :unique, name: Arena.Registro})

    :ok
  end

  test "cuatro procesos reciben el mismo estado y quinto es rechazado" do
    sala = start_supervised!({Partida, [sala: "TEST", automatico: false]})
    actores = for _ <- 1..5, do: spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Enum.each(actores, &Process.exit(&1, :kill)) end)

    for {carro, n} <- Enum.with_index(["rayo", "muro", "chispa", "martillo"]) do
      assert :ok = Partida.entrar(sala, Enum.at(actores, n), "p#{n}", "Piloto #{n}", carro)
    end

    assert {:error, _} = Partida.entrar(sala, Enum.at(actores, 4), "p4", "Extra", "rayo")
    estado = Partida.estado(sala)
    assert length(estado.jugadores) == 4
    for n <- 0..3, do: Partida.accion(sala, "p#{n}", %{"tipo" => "listo", "valor" => true})
    assert Partida.estado(sala).fase == "cuenta"
    for _ <- 1..90, do: send(sala, :tick)
    assert Partida.estado(sala).fase == "jugando"
    Process.exit(hd(actores), :kill)
    # DOWN es asíncrono: esperar hasta observar la desconexión sin asumir orden entre emisores.
    assert_eventually(fn ->
      Enum.find(Partida.estado(sala).jugadores, &(&1.id == "p0")).conectado == false
    end)
  end

  test "monitor de socket libera el vehículo y sala vacía termina" do
    sala = start_supervised!({Partida, [sala: "VACIA", automatico: false]})
    actor = spawn(fn -> Process.sleep(:infinity) end)
    assert :ok = Partida.entrar(sala, actor, "a", "Ana", "rayo")
    ref = Process.monitor(sala)
    Process.exit(actor, :kill)
    assert_receive {:DOWN, ^ref, :process, ^sala, :normal}, 1000
  end

  test "prueba individual tiene un jugador, no termina por soledad y limpia su sala al salir" do
    sala = start_supervised!({Partida, [sala: "SOLO", automatico: false]})
    actor = spawn(fn -> Process.sleep(:infinity) end)
    assert :ok = Partida.entrar(sala, actor, "humano", "Memo", "rayo")
    assert :ok = Partida.practica(sala, "humano")
    assert Partida.estado(sala).modo == "practica"
    assert Partida.estado(sala).fase == "jugando"
    assert length(Partida.estado(sala).jugadores) == 1
    Partida.input(sala, "humano", "derecha", false)
    send(sala, :tick)
    assert hd(Partida.estado(sala).jugadores).x > 100
    for _ <- 1..5500, do: send(sala, :tick)
    assert Partida.estado(sala).fase == "jugando"
    assert Partida.estado(sala).resultado == nil
    ref = Process.monitor(sala)
    Process.exit(actor, :kill)
    assert_receive {:DOWN, ^ref, :process, ^sala, :normal}, 1000
  end

  defp assert_eventually(comprobar, intentos \\ 30)
  defp assert_eventually(comprobar, 0), do: assert(comprobar.())

  defp assert_eventually(comprobar, intentos) do
    if comprobar.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          assert_eventually(comprobar, intentos - 1)
        )
  end
end

defmodule Arena.ReglasTest do
  use ExUnit.Case, async: true
  alias Arena.Reglas

  defp sala_completa do
    Enum.reduce(
      Enum.with_index(["rayo", "muro", "chispa", "martillo"]),
      Reglas.nueva(),
      fn {carro, n}, estado ->
        {:ok, nuevo} = Reglas.agregar(estado, "p#{n}", "Piloto #{n}", carro)
        nuevo
      end
    )
  end

  defp jugando do
    estado = sala_completa()

    estado =
      Enum.reduce(Map.keys(estado.jugadores), estado, fn id, e ->
        {:ok, nuevo} = Reglas.accion(e, id, %{"tipo" => "listo", "valor" => true})
        nuevo
      end)

    Enum.reduce(1..90, estado, fn _, e -> Reglas.tick(e) end)
  end

  test "no admite quinto jugador ni vehículo ocupado" do
    estado = sala_completa()
    assert {:error, _} = Reglas.agregar(estado, "extra", "Extra", "rayo")
    {:ok, uno} = Reglas.agregar(Reglas.nueva(), "a", "A", "rayo")
    assert {:error, _} = Reglas.agregar(uno, "b", "B", "rayo")
  end

  test "solo cuatro preparados inician y desconectar cancela cuenta atrás" do
    estado = jugando()
    assert estado.fase == "jugando"
    assert estado.restantes == 5400
    lobby = sala_completa()
    {:ok, lobby} = Reglas.accion(lobby, "p0", %{"tipo" => "listo", "valor" => true})
    assert Reglas.tick(lobby).fase == "lobby"

    cuenta =
      Enum.reduce(["p1", "p2", "p3"], lobby, fn id, e ->
        {:ok, e} = Reglas.accion(e, id, %{"tipo" => "listo", "valor" => true})
        e
      end)

    assert cuenta.fase == "cuenta"
    assert Reglas.quitar(cuenta, "p0").fase == "lobby"
  end

  test "movimiento se calcula en servidor y respeta paredes y límite" do
    estado = jugando()
    inicial = estado.jugadores["p0"].x
    estado = Reglas.input(estado, "p0", "derecha", false) |> Reglas.tick()
    assert estado.jugadores["p0"].x > inicial
    estado = put_in(estado.jugadores["p0"].x, 55)
    estado = Reglas.input(estado, "p0", "izquierda", false)
    estado = Enum.reduce(1..10, estado, fn _, e -> Reglas.tick(e) end)
    assert estado.jugadores["p0"].x >= 54
  end

  test "input caduca al dejar de recibir controles" do
    estado = jugando() |> Reglas.input("p0", "derecha", false)
    estado = Enum.reduce(1..15, estado, fn _, e -> Reglas.tick(e) end)
    x = estado.jugadores["p0"].x
    assert Reglas.tick(estado).jugadores["p0"].x == x
  end

  test "proyectil daña al rival y cooldown impide disparar cada tick" do
    estado = jugando()
    estado = put_in(estado.jugadores["p0"].x, 100)
    estado = put_in(estado.jugadores["p0"].y, 100)
    estado = put_in(estado.jugadores["p1"].x, 180)
    estado = put_in(estado.jugadores["p1"].y, 100)
    vida = estado.jugadores["p1"].vida
    estado = Reglas.input(estado, "p0", "derecha", true)
    estado = Enum.reduce(1..7, estado, fn _, e -> Reglas.tick(e) end)
    assert estado.jugadores["p1"].vida == vida - 20
    assert estado.siguiente_id == 1
  end

  test "disparo choca con pared sin dañar al otro lado" do
    estado = jugando()
    estado = put_in(estado.jugadores["p0"].x, 240)
    estado = put_in(estado.jugadores["p0"].y, 140)
    estado = put_in(estado.jugadores["p1"].x, 440)
    estado = put_in(estado.jugadores["p1"].y, 140)
    vida = estado.jugadores["p1"].vida
    estado = Reglas.input(estado, "p0", "derecha", true)
    estado = Enum.reduce(1..10, estado, fn _, e -> Reglas.tick(e) end)
    assert estado.jugadores["p1"].vida == vida
    assert estado.proyectiles == []
  end

  test "último superviviente gana y revancha limpia la partida" do
    estado =
      jugando()
      |> Reglas.quitar("p1")
      |> Reglas.quitar("p2")
      |> Reglas.quitar("p3")
      |> Reglas.tick()

    assert estado.fase == "final"
    assert estado.resultado == "p0"
    {:ok, lobby} = Reglas.accion(estado, "p0", %{"tipo" => "revancha"})
    assert lobby.fase == "lobby"
    assert map_size(lobby.jugadores) == 1
    assert lobby.jugadores["p0"].vida == 85
    assert lobby.proyectiles == []
  end

  test "timeout con varios supervivientes es empate y eliminados no actúan" do
    estado = jugando()
    estado = put_in(estado.jugadores["p0"].vida, 0)
    assert Reglas.input(estado, "p0", "derecha", true) == estado
    assert Reglas.tick(%{estado | restantes: 1}).resultado == "empate"
  end

  test "entradas inválidas no alteran el estado y no se puede elegir en combate" do
    estado = jugando()
    assert {:error, _} = Reglas.accion(estado, "p0", %{"tipo" => "elegir", "personaje" => "muro"})
    assert Reglas.input(estado, "p0", "teleport", true) == estado
    assert Reglas.input(estado, "extra", "derecha", true) == estado
  end

  test "los daños simultáneos de los dos últimos jugadores producen empate" do
    estado = jugando()
    estado = put_in(estado.jugadores["p0"].vida, 20)
    estado = put_in(estado.jugadores["p1"].vida, 20)
    estado = put_in(estado.jugadores["p2"].vida, 0)
    estado = put_in(estado.jugadores["p3"].vida, 0)

    balas = [
      %{id: 1, owner: "p0", personaje: "rayo", x: 1008, y: 100, dx: 1, dy: 0, dano: 20, ttl: 50},
      %{id: 2, owner: "p1", personaje: "muro", x: 112, y: 100, dx: -1, dy: 0, dano: 20, ttl: 50}
    ]

    nuevo = Reglas.tick(%{estado | proyectiles: balas})
    assert nuevo.jugadores["p0"].vida == 0
    assert nuevo.jugadores["p1"].vida == 0
    assert nuevo.resultado == "empate"
  end

  test "un carro no puede atravesar otro carro vivo" do
    estado = jugando()
    estado = put_in(estado.jugadores["p1"].x, 130)
    estado = put_in(estado.jugadores["p1"].y, 100)
    estado = Reglas.input(estado, "p0", "derecha", false) |> Reglas.tick()
    assert estado.jugadores["p0"].x == 100
  end
end

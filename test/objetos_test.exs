defmodule Arena.ObjetosTest do
  use ExUnit.Case, async: true
  alias Arena.{Reglas, Objetos}

  defp demo do
    {:ok, e} = Reglas.agregar(Reglas.nueva(), "p0", "Ana", "rayo")
    %{e | fase: "jugando", modo: "practica"}
  end

  defp objeto(e, tipo),
    do: %{
      e
      | objetos: [%{id: "test", x: 100, y: 100, tipo: tipo, disponible_en: 0, periodico: true}]
    }

  test "botiquín cura sin superar máximo y reaparece después del tiempo" do
    e = demo() |> put_in([:jugadores, "p0", :vida], 70) |> objeto("vida") |> Reglas.tick()
    assert e.jugadores["p0"].vida == 85
    assert hd(e.objetos).disponible_en == 451
    e = put_in(e.jugadores["p0"].vida, 10)
    assert Reglas.tick(e).jugadores["p0"].vida == 10
    assert Reglas.tick(%{e | tick: 450}).jugadores["p0"].vida == 40
  end

  test "turbo caduca y no se multiplica al renovar" do
    e = demo() |> objeto("turbo") |> Reglas.tick()
    assert e.jugadores["p0"].turbo_hasta == 181
    renovado = %{e | tick: 50} |> objeto("turbo") |> Reglas.tick()
    assert renovado.jugadores["p0"].turbo_hasta == 231
    activo = e |> Reglas.input("p0", "derecha", false) |> Reglas.tick()
    assert_in_delta activo.jugadores["p0"].x, 105.67, 0.001
    normal = %{e | tick: 181} |> Reglas.input("p0", "derecha", false) |> Reglas.tick()
    assert_in_delta normal.jugadores["p0"].x, 104.2, 0.001
  end

  test "escudo absorbe un solo impacto y el segundo hace daño" do
    e = demo() |> objeto("escudo") |> Reglas.tick()
    assert e.jugadores["p0"].escudo
    jugadores = Objetos.danar(e.jugadores, %{"p0" => [20, 30]})
    assert jugadores["p0"].vida == 55
    refute jugadores["p0"].escudo
  end

  test "potente da cinco disparos reforzados sin cambiar daño base" do
    e =
      demo()
      |> objeto("potente")
      |> Reglas.tick()
      |> Reglas.input("p0", "quieto", true)
      |> Reglas.tick()

    assert hd(e.proyectiles).dano == 30
    assert e.jugadores["p0"].potentes == 4
    assert Reglas.personajes()["rayo"].dano == 20

    e =
      Enum.reduce(1..70, e, fn _, s -> Reglas.input(s, "p0", "quieto", true) |> Reglas.tick() end)

    assert Enum.map(e.proyectiles, & &1.dano) == [30, 30, 30, 30, 30, 20]
    assert e.jugadores["p0"].potentes == 0
  end

  test "caja bloquea carro y dos disparos la destruyen dejando un solo objeto" do
    e = demo()
    caja = %{id: "c", x: 140, y: 80, w: 40, h: 40, vida: 40, drop: "escudo"}
    e = %{e | cajas: [caja], objetos: []}
    e = put_in(e.jugadores["p0"].x, 125)
    assert (e |> Reglas.input("p0", "derecha", false) |> Reglas.tick()).jugadores["p0"].x == 125
    e = put_in(e.jugadores["p0"].x, 100)
    e = Reglas.input(e, "p0", "quieto", true)

    e =
      Enum.reduce(1..20, e, fn _, s -> Reglas.input(s, "p0", "quieto", true) |> Reglas.tick() end)

    assert e.cajas == []
    assert length(e.objetos) == 1
    assert hd(e.objetos).tipo == "escudo"
  end

  test "mina consume carga, limita otra mina y no explota antes de armarse" do
    e = demo()
    assert {:ok, e} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
    assert e.jugadores["p0"].minas_carga == 0
    assert length(e.minas) == 1
    assert {:error, _} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
    assert length(Reglas.tick(e).minas) == 1
  end

  test "mina armada daña al rival y al dueño cercano y desaparece" do
    e = demo()
    {:ok, e} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
    {:ok, lobby} = Reglas.agregar(Reglas.nueva(), "p1", "Beto", "muro")
    rival = %{lobby.jugadores["p1"] | x: 70, y: 100}
    e = put_in(e.jugadores["p1"], rival)
    e = %{e | tick: 30}
    e = Reglas.tick(e)
    assert e.minas == []
    assert e.jugadores["p1"].vida == 100
    assert e.jugadores["p0"].vida == 40
  end

  test "revancha restaura cajas, objetos, efectos y cargas" do
    e = demo() |> objeto("escudo") |> Reglas.tick()
    {:ok, e} = Reglas.accion(%{e | fase: "final"}, "p0", %{"tipo" => "revancha"})
    assert e.cajas == Reglas.nueva().cajas
    refute e.jugadores["p0"].escudo
    assert e.jugadores["p0"].minas_carga == 1
    assert e.minas == []
  end

  test "paredes y cajas bloquean la onda de la mina" do
    for {y, cajas} <- [
          {300, []},
          {100, [%{id: "proteccion", x: 120, y: 80, w: 40, h: 40, vida: 40, drop: "vida"}]}
        ] do
      e = demo()
      {:ok, lobby} = Reglas.agregar(Reglas.nueva(), "p1", "Beto", "muro")
      e = put_in(e.jugadores["p0"].x, 174)
      e = put_in(e.jugadores["p0"].y, y)
      e = put_in(e.jugadores["p1"], %{lobby.jugadores["p1"] | x: 100, y: y})
      mina = %{id: 0, owner: "p0", x: 100, y: y, armar_en: 0, vence_en: 900}
      e = Reglas.tick(%{e | minas: [mina], cajas: cajas})
      assert e.jugadores["p0"].vida == 85
      assert e.jugadores["p1"].vida == 100
    end
  end

  test "dos jugadores sobre un objeto no lo duplican" do
    e = demo() |> objeto("escudo")
    {:ok, lobby} = Reglas.agregar(Reglas.nueva(), "p1", "Beto", "muro")
    e = put_in(e.jugadores["p1"], %{lobby.jugadores["p1"] | x: 100, y: 100}) |> Reglas.tick()
    assert Enum.count(e.jugadores, fn {_, p} -> p.escudo end) == 1
  end

  test "eliminados no recogen objetos y colocar mina contra pared no consume carga" do
    e = demo() |> objeto("escudo") |> put_in([:jugadores, "p0", :vida], 0) |> Reglas.tick()
    refute e.jugadores["p0"].escudo
    e = demo() |> put_in([:jugadores, "p0", :x], 55)
    assert {:error, _} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
    assert e.jugadores["p0"].minas_carga == 1
  end

  test "recoger otra carga no permite más de una mina activa y la mina caduca" do
    {:ok, e} = Reglas.accion(demo(), "p0", %{"tipo" => "mina"})
    e = e |> objeto("mina") |> Reglas.tick()
    assert e.jugadores["p0"].minas_carga == 1
    assert {:error, _} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
    e = Reglas.tick(%{e | tick: 900})
    assert e.minas == []
    assert {:ok, _} = Reglas.accion(e, "p0", %{"tipo" => "mina"})
  end
end

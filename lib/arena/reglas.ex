defmodule Arena.Reglas do
  @moduledoc "Reglas puras: reciben mapas inmutables y devuelven estados nuevos. Sin procesos, IO ni reloj del sistema."
  @ancho 1120
  @alto 640
  @radio 14
  @personajes %{
    "rayo" => %{
      nombre: "Rayo",
      vehiculo: "Buggy",
      color: "#f5c542",
      vida: 85,
      velocidad: 4.2,
      dano: 20,
      recarga: 14
    },
    "muro" => %{
      nombre: "Muro",
      vehiculo: "Blindado",
      color: "#5ba3ff",
      vida: 145,
      velocidad: 2.6,
      dano: 20,
      recarga: 17
    },
    "chispa" => %{
      nombre: "Chispa",
      vehiculo: "Auto de combate",
      color: "#76cf5b",
      vida: 100,
      velocidad: 3.5,
      dano: 12,
      recarga: 8
    },
    "martillo" => %{
      nombre: "Martillo",
      vehiculo: "Camioneta",
      color: "#ee5c55",
      vida: 110,
      velocidad: 3.0,
      dano: 34,
      recarga: 26
    }
  }
  @spawns [
    {100, 100, "derecha"},
    {1020, 100, "abajo"},
    {100, 540, "arriba"},
    {1020, 540, "izquierda"}
  ]
  @direcciones %{
    "arriba" => {0, -1},
    "abajo" => {0, 1},
    "izquierda" => {-1, 0},
    "derecha" => {1, 0},
    "quieto" => {0, 0}
  }

  def personajes, do: @personajes

  def mapa do
    [
      %{x: 0, y: 0, w: 1120, h: 40},
      %{x: 0, y: 600, w: 1120, h: 40},
      %{x: 0, y: 40, w: 40, h: 560},
      %{x: 1080, y: 40, w: 40, h: 560},
      %{x: 280, y: 120, w: 120, h: 40},
      %{x: 720, y: 120, w: 120, h: 40},
      %{x: 120, y: 240, w: 40, h: 120},
      %{x: 960, y: 280, w: 40, h: 120},
      %{x: 280, y: 280, w: 120, h: 40},
      %{x: 720, y: 320, w: 120, h: 40},
      %{x: 500, y: 240, w: 120, h: 160},
      %{x: 280, y: 480, w: 120, h: 40},
      %{x: 720, y: 480, w: 120, h: 40}
    ]
  end

  def nueva do
    %{
      fase: "lobby",
      modo: "multi",
      jugadores: %{},
      proyectiles: [],
      impactos: [],
      tick: 0,
      cuenta: 90,
      restantes: 5400,
      resultado: nil,
      siguiente_id: 0
    }
  end

  def agregar(estado, player_id, nombre, personaje) do
    cond do
      estado.fase != "lobby" ->
        {:error, "La partida ya está en curso. Espera a la siguiente ronda."}

      map_size(estado.jugadores) >= 4 ->
        {:error, "Esta sala está llena. Prueba otro código."}

      Map.has_key?(estado.jugadores, player_id) ->
        {:error, "Ya estás en esta sala."}

      not Map.has_key?(@personajes, personaje) ->
        {:error, "Elige un vehículo válido."}

      ocupado?(estado, personaje, player_id) ->
        {:error, "Ese vehículo ya tiene piloto. Elige otro."}

      not is_binary(nombre) or String.length(String.trim(nombre)) not in 1..18 ->
        {:error, "Tu nombre debe tener entre 1 y 18 caracteres."}

      true ->
        slots = Enum.map(estado.jugadores, fn {_, p} -> p.slot end)
        slot = Enum.find(0..3, &(&1 not in slots))
        jugador = crear_jugador(player_id, String.trim(nombre), personaje, slot)
        {:ok, put_in(estado.jugadores[player_id], jugador)}
    end
  end

  defp crear_jugador(id, nombre, personaje, slot) do
    stats = @personajes[personaje]
    {x, y, direccion} = Enum.at(@spawns, slot)

    %{
      id: id,
      nombre: nombre,
      personaje: personaje,
      slot: slot,
      x: x,
      y: y,
      direccion: direccion,
      vida: stats.vida,
      max_vida: stats.vida,
      listo: false,
      conectado: true,
      movimiento: "quieto",
      disparar: false,
      cooldown_ticks: 0,
      ultima_input_tick: -100
    }
  end

  defp ocupado?(estado, personaje, id),
    do: Enum.any?(estado.jugadores, fn {otro, p} -> otro != id and p.personaje == personaje end)

  def accion(estado, id, mensaje) do
    if Map.has_key?(estado.jugadores, id),
      do: aplicar_accion(estado, id, mensaje),
      else: {:error, "Primero entra a la sala."}
  end

  defp aplicar_accion(%{fase: "lobby"} = estado, id, %{
         "tipo" => "elegir",
         "personaje" => personaje
       }) do
    if Map.has_key?(@personajes, personaje) and not ocupado?(estado, personaje, id) do
      actual = estado.jugadores[id]

      {:ok,
       put_in(estado.jugadores[id], crear_jugador(id, actual.nombre, personaje, actual.slot))}
    else
      {:error, "Ese vehículo no está disponible."}
    end
  end

  defp aplicar_accion(%{fase: fase} = estado, id, %{"tipo" => "listo", "valor" => valor})
       when fase in ["lobby", "cuenta"] and is_boolean(valor) do
    estado = put_in(estado.jugadores[id].listo, valor)

    preparados =
      map_size(estado.jugadores) == 4 and Enum.all?(estado.jugadores, fn {_, p} -> p.listo end)

    {:ok, %{estado | fase: if(preparados, do: "cuenta", else: "lobby"), cuenta: 90}}
  end

  defp aplicar_accion(%{fase: "final"} = estado, _id, %{"tipo" => "revancha"}) do
    jugadores =
      estado.jugadores
      |> Enum.filter(fn {_, p} -> p.conectado end)
      |> Map.new(fn {id, p} -> {id, crear_jugador(id, p.nombre, p.personaje, p.slot)} end)

    {:ok, %{nueva() | jugadores: jugadores}}
  end

  defp aplicar_accion(_, _, _), do: {:error, "Acción no disponible en este momento."}

  def quitar(%{fase: fase} = estado, id) when fase in ["lobby", "cuenta"] do
    %{estado | jugadores: Map.delete(estado.jugadores, id), fase: "lobby", cuenta: 90}
  end

  def quitar(estado, id) do
    if Map.has_key?(estado.jugadores, id) do
      update_in(
        estado.jugadores[id],
        &%{&1 | conectado: false, vida: 0, movimiento: "quieto", disparar: false}
      )
    else
      estado
    end
  end

  def input(%{fase: "jugando"} = estado, id, direccion, disparar) when is_boolean(disparar) do
    case estado.jugadores[id] do
      %{vida: vida, conectado: true} when vida > 0 ->
        if Map.has_key?(@direcciones, direccion) do
          update_in(
            estado.jugadores[id],
            &%{&1 | movimiento: direccion, disparar: disparar, ultima_input_tick: estado.tick}
          )
        else
          estado
        end

      _ ->
        estado
    end
  end

  def input(estado, _, _, _), do: estado

  def tick(%{fase: "cuenta", cuenta: 1} = estado), do: %{estado | fase: "jugando", cuenta: 0}
  def tick(%{fase: "cuenta"} = estado), do: %{estado | cuenta: estado.cuenta - 1}

  def tick(%{fase: "jugando"} = estado) do
    %{
      estado
      | tick: estado.tick + 1,
        restantes:
          if(estado.modo == "practica", do: estado.restantes, else: max(0, estado.restantes - 1)),
        impactos: Enum.filter(Enum.map(estado.impactos, &%{&1 | ttl: &1.ttl - 1}), &(&1.ttl > 0))
    }
    |> mover_jugadores()
    |> disparar_jugadores()
    |> avanzar_proyectiles()
    |> resolver_final()
  end

  def tick(estado), do: estado

  defp mover_jugadores(estado) do
    Enum.reduce(Enum.sort(Map.keys(estado.jugadores)), estado, fn id, actual ->
      p = actual.jugadores[id]

      if p.vida > 0 and p.conectado do
        activo = actual.tick - p.ultima_input_tick <= 12
        direccion = if activo, do: p.movimiento, else: "quieto"
        {dx, dy} = @direcciones[direccion]
        velocidad_base = @personajes[p.personaje].velocidad
        nx = p.x + dx * velocidad_base
        ny = p.y + dy * velocidad_base

        libre =
          not pared?(nx, ny, @radio) and
            not Enum.any?(actual.jugadores, fn {otro, q} ->
              otro != id and q.vida > 0 and distancia2(nx, ny, q.x, q.y) < 4 * @radio * @radio
            end)

        nuevo = %{
          p
          | x: if(libre, do: nx, else: p.x),
            y: if(libre, do: ny, else: p.y),
            direccion: if(direccion == "quieto", do: p.direccion, else: direccion),
            cooldown_ticks: max(0, p.cooldown_ticks - 1)
        }

        put_in(actual.jugadores[id], nuevo)
      else
        actual
      end
    end)
  end

  defp disparar_jugadores(estado) do
    Enum.reduce(Enum.sort(Map.keys(estado.jugadores)), estado, fn id, actual ->
      p = actual.jugadores[id]

      if p.vida > 0 and p.conectado and p.disparar and p.cooldown_ticks == 0 and
           actual.tick - p.ultima_input_tick <= 12 do
        {dx, dy} = @direcciones[p.direccion]
        stats = @personajes[p.personaje]

        bala = %{
          id: actual.siguiente_id,
          owner: id,
          personaje: p.personaje,
          x: p.x + dx * 20,
          y: p.y + dy * 20,
          dx: dx,
          dy: dy,
          dano: stats.dano,
          ttl: 100
        }

        actual = put_in(actual.jugadores[id].cooldown_ticks, stats.recarga)

        %{
          actual
          | proyectiles: actual.proyectiles ++ [bala],
            siguiente_id: actual.siguiente_id + 1
        }
      else
        actual
      end
    end)
  end

  defp avanzar_proyectiles(estado) do
    # Acumular daños antes de aplicarlos permite eliminaciones simultáneas.
    {balas, danos, impactos} =
      Enum.reduce(estado.proyectiles, {[], %{}, estado.impactos}, fn bala,
                                                                     {vivas, danos, efectos} ->
        b = %{bala | x: bala.x + bala.dx * 12, y: bala.y + bala.dy * 12, ttl: bala.ttl - 1}

        objetivo =
          Enum.find(Enum.sort(estado.jugadores), fn {id, p} ->
            id != b.owner and p.vida > 0 and distancia2(b.x, b.y, p.x, p.y) <= 18 * 18
          end)

        cond do
          b.ttl <= 0 ->
            {vivas, danos, efectos}

          pared?(b.x, b.y, 3) ->
            {vivas, danos, [%{x: b.x, y: b.y, ttl: 6, tipo: "pared"} | efectos]}

          objetivo != nil ->
            {id, _} = objetivo

            {vivas, Map.update(danos, id, b.dano, &(&1 + b.dano)),
             [%{x: b.x, y: b.y, ttl: 9, tipo: "carro"} | efectos]}

          true ->
            {[b | vivas], danos, efectos}
        end
      end)

    jugadores =
      Enum.reduce(danos, estado.jugadores, fn {id, dano}, ps ->
        update_in(ps[id].vida, &max(0, &1 - dano))
      end)

    %{estado | proyectiles: Enum.reverse(balas), jugadores: jugadores, impactos: impactos}
  end

  defp resolver_final(%{modo: "practica"} = estado), do: estado

  defp resolver_final(estado) do
    vivos = estado.jugadores |> Map.values() |> Enum.filter(&(&1.vida > 0 and &1.conectado))

    cond do
      length(vivos) == 1 -> %{estado | fase: "final", resultado: hd(vivos).id}
      vivos == [] or estado.restantes == 0 -> %{estado | fase: "final", resultado: "empate"}
      true -> estado
    end
  end

  defp distancia2(x, y, ox, oy), do: (x - ox) * (x - ox) + (y - oy) * (y - oy)

  defp pared?(x, y, radio) do
    x < radio or y < radio or x > @ancho - radio or y > @alto - radio or
      Enum.any?(mapa(), fn r ->
        x + radio > r.x and x - radio < r.x + r.w and y + radio > r.y and y - radio < r.y + r.h
      end)
  end

  def snapshot(estado) do
    jugadores =
      estado.jugadores
      |> Map.values()
      |> Enum.sort_by(& &1.slot)
      |> Enum.map(
        &Map.take(&1, [
          :id,
          :nombre,
          :personaje,
          :slot,
          :x,
          :y,
          :direccion,
          :vida,
          :max_vida,
          :listo,
          :conectado
        ])
      )

    Map.take(estado, [
      :fase,
      :modo,
      :tick,
      :cuenta,
      :restantes,
      :resultado,
      :proyectiles,
      :impactos
    ])
    |> Map.put(:jugadores, jugadores)
  end
end

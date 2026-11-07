defmodule Arena.Objetos do
  @moduledoc "Interacciones puras: mejoras, cajas y minas. Todos los tiempos son ticks del estado recibido."
  alias Arena.Reglas

  def iniciales do
    [
      {220, 100, "turbo"},
      {1220, 100, "escudo"},
      {220, 700, "vida"},
      {1220, 700, "potente"},
      {720, 100, "mina"},
      {720, 700, "vida"},
      {100, 400, "escudo"},
      {1340, 400, "turbo"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{x, y, tipo}, i} ->
      %{id: "obj_#{i}", x: x, y: y, tipo: tipo, disponible_en: 0, periodico: true}
    end)
  end

  def cajas do
    [
      {460, 120, "vida"},
      {940, 120, "potente"},
      {460, 640, "escudo"},
      {940, 640, "turbo"},
      {580, 240, "mina"},
      {820, 520, "vida"},
      {420, 400, "potente"},
      {980, 360, "escudo"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{x, y, drop}, i} ->
      %{id: "caja_#{i}", x: x, y: y, w: 40, h: 40, vida: 40, drop: drop}
    end)
  end

  def caja_en(cajas, x, y, radio),
    do:
      Enum.find(cajas, fn r ->
        x + radio > r.x and x - radio < r.x + r.w and y + radio > r.y and y - radio < r.y + r.h
      end)

  def recoger(estado) do
    {objetos, jugadores, impactos} =
      Enum.reduce(estado.objetos, {[], estado.jugadores, estado.impactos}, fn objeto,
                                                                              {lista, ps, efectos} ->
        piloto =
          if objeto.disponible_en <= estado.tick do
            Enum.find(Enum.sort(ps), fn {_, p} ->
              p.vida > 0 and p.conectado and distancia2(p.x, p.y, objeto.x, objeto.y) <= 24 * 24 and
                util?(p, objeto.tipo)
            end)
          end

        case piloto do
          {id, p} ->
            ps = Map.put(ps, id, aplicar(p, objeto.tipo, estado.tick))

            lista =
              if objeto.periodico,
                do: [%{objeto | disponible_en: estado.tick + 450} | lista],
                else: lista

            {lista, ps, [%{x: objeto.x, y: objeto.y, ttl: 9, tipo: "objeto"} | efectos]}

          _ ->
            {[objeto | lista], ps, efectos}
        end
      end)

    %{estado | objetos: Enum.reverse(objetos), jugadores: jugadores, impactos: impactos}
  end

  defp util?(p, "vida"), do: p.vida < p.max_vida
  defp util?(p, "escudo"), do: not p.escudo
  defp util?(p, "mina"), do: p.minas_carga < 1
  defp util?(_, _), do: true
  defp aplicar(p, "vida", _), do: %{p | vida: min(p.max_vida, p.vida + 30)}
  defp aplicar(p, "escudo", _), do: %{p | escudo: true}
  defp aplicar(p, "turbo", tick), do: %{p | turbo_hasta: tick + 180}
  defp aplicar(p, "potente", _), do: %{p | potentes: 5}
  defp aplicar(p, "mina", _), do: %{p | minas_carga: 1}

  def danar(jugadores, danos) do
    Enum.reduce(danos, jugadores, fn {id, impactos}, ps ->
      update_in(ps[id], fn p ->
        Enum.reduce(impactos, p, fn dano, p ->
          if p.escudo, do: %{p | escudo: false}, else: %{p | vida: max(0, p.vida - dano)}
        end)
      end)
    end)
  end

  def golpear_caja(estado, caja, dano) do
    if caja.vida > dano do
      %{
        estado
        | cajas:
            Enum.map(estado.cajas, fn c ->
              if c.id == caja.id, do: %{c | vida: c.vida - dano}, else: c
            end)
      }
    else
      drop = %{
        id: "drop_" <> caja.id,
        x: caja.x + 20,
        y: caja.y + 20,
        tipo: caja.drop,
        disponible_en: estado.tick,
        periodico: false
      }

      %{
        estado
        | cajas: Enum.reject(estado.cajas, &(&1.id == caja.id)),
          objetos: estado.objetos ++ [drop]
      }
    end
  end

  def colocar_mina(estado, id) do
    p = estado.jugadores[id]

    {dx, dy} =
      %{"arriba" => {0, -1}, "abajo" => {0, 1}, "izquierda" => {-1, 0}, "derecha" => {1, 0}}[
        p.direccion
      ]

    x = p.x - dx * 30
    y = p.y - dy * 30

    cond do
      p.vida <= 0 or not p.conectado ->
        {:error, "Tu vehículo no puede colocar minas."}

      p.minas_carga < 1 ->
        {:error, "No tienes minas. Busca una carga en la arena."}

      Enum.any?(estado.minas, &(&1.owner == id)) ->
        {:error, "Ya tienes una mina activa."}

      not libre?(estado, x, y, 10) ->
        {:error, "No hay espacio detrás de tu vehículo para la mina."}

      true ->
        mina = %{
          id: estado.siguiente_mina,
          owner: id,
          x: x,
          y: y,
          armar_en: estado.tick + 30,
          vence_en: estado.tick + 900
        }

        estado = put_in(estado.jugadores[id].minas_carga, 0)

        {:ok,
         %{estado | minas: estado.minas ++ [mina], siguiente_mina: estado.siguiente_mina + 1}}
    end
  end

  def avanzar_minas(estado) do
    {minas, danos, impactos} =
      Enum.reduce(estado.minas, {[], %{}, estado.impactos}, fn mina, {vivas, danos, efectos} ->
        activa =
          estado.tick >= mina.armar_en and
            Enum.any?(estado.jugadores, fn {id, p} ->
              id !=
                mina.owner and p.vida > 0 and p.conectado and
                distancia2(p.x, p.y, mina.x, mina.y) <= 26 * 26
            end)

        cond do
          estado.tick >= mina.vence_en ->
            {vivas, danos, efectos}

          activa ->
            danos =
              Enum.reduce(estado.jugadores, danos, fn {id, p}, ds ->
                if p.vida > 0 and distancia2(p.x, p.y, mina.x, mina.y) <= 75 * 75 and
                     linea_libre?(estado, mina.x, mina.y, p.x, p.y) do
                  Map.update(ds, id, [45], &(&1 ++ [45]))
                else
                  ds
                end
              end)

            {vivas, danos, [%{x: mina.x, y: mina.y, ttl: 10, tipo: "explosion"} | efectos]}

          true ->
            {[mina | vivas], danos, efectos}
        end
      end)

    %{
      estado
      | minas: Enum.reverse(minas),
        jugadores: danar(estado.jugadores, danos),
        impactos: impactos
    }
  end

  def libre?(estado, x, y, radio) do
    not Enum.any?(Reglas.mapa() ++ estado.cajas, fn r ->
      x + radio > r.x and x - radio < r.x + r.w and y + radio > r.y and y - radio < r.y + r.h
    end)
  end

  defp linea_libre?(estado, x, y, tx, ty) do
    pasos = max(1, ceil(:math.sqrt(distancia2(x, y, tx, ty)) / 8))

    Enum.all?(1..pasos, fn n ->
      libre?(estado, x + (tx - x) * n / pasos, y + (ty - y) * n / pasos, 2)
    end)
  end

  defp distancia2(x, y, tx, ty), do: (x - tx) * (x - tx) + (y - ty) * (y - ty)
end

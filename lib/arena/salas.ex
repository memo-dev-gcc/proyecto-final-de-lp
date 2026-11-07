defmodule Arena.Salas do
  @moduledoc "Localiza salas en Registry y crea su actor bajo DynamicSupervisor."
  def obtener(codigo) when is_binary(codigo) do
    codigo = codigo |> String.trim() |> String.upcase()

    if Regex.match?(~r/^[A-Z0-9]{3,8}$/, codigo) do
      case Registry.lookup(Arena.Registro, codigo) do
        [{pid, _}] -> {:ok, pid, codigo}
        [] -> crear(codigo)
      end
    else
      {:error, "Usa un código de 3 a 8 letras o números."}
    end
  end

  def obtener(_), do: {:error, "Código de sala inválido."}

  defp crear(codigo) do
    if DynamicSupervisor.count_children(Arena.SalasSupervisor).active >= 32 do
      {:error, "Hay muchas salas abiertas. Intenta en unos segundos."}
    else
      case DynamicSupervisor.start_child(Arena.SalasSupervisor, {Arena.Partida, sala: codigo}) do
        {:ok, pid} -> {:ok, pid, codigo}
        {:error, {:already_started, pid}} -> {:ok, pid, codigo}
        _ -> {:error, "No se pudo crear la sala. Intenta otra vez."}
      end
    end
  end
end

defmodule Arena.Application do
  use Application
  @impl true
  def start(_tipo, _args) do
    hijos = [
      {Registry, keys: :unique, name: Arena.Registro},
      {DynamicSupervisor, strategy: :one_for_one, name: Arena.SalasSupervisor}
    ]

    hijos =
      if Application.get_env(:arena, :iniciar_http, true) do
        puerto = System.get_env("PORT", "4000") |> String.to_integer()
        hijos ++ [{Bandit, plug: Arena.Router, port: puerto, ip: {0, 0, 0, 0}}]
      else
        hijos
      end

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Arena.Supervisor)
  end
end

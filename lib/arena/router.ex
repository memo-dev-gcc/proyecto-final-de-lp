defmodule Arena.Router do
  use Plug.Router
  plug(:seguridad)

  plug(Plug.Static,
    at: "/",
    from: {:arena, "priv/static"},
    only: ~w(index.html estilos.css juego.js render.js favicon.svg)
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:arena, "priv/static/index.html"))
  end

  get "/health" do
    conn |> put_resp_content_type("application/json") |> send_resp(200, "{\"estado\":\"ok\"}")
  end

  get "/ws" do
    origin = get_req_header(conn, "origin")
    esperado = conn.host <> if(conn.port in [80, 443], do: "", else: ":#{conn.port}")

    valido =
      case origin do
        [] ->
          true

        [valor] ->
          uri = URI.parse(valor)
          uri.host != nil and uri.scheme in ["http", "https"] and uri.authority == esperado

        _ ->
          false
      end

    if valido do
      conn
      |> WebSockAdapter.upgrade(Arena.Socket, [],
        timeout: 45_000,
        max_frame_size: 2048,
        compress: false
      )
      |> halt()
    else
      send_resp(conn, 403, "Origen no permitido")
    end
  end

  match(_, do: send_resp(conn, 404, "No encontrado"))

  defp seguridad(conn, _) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "same-origin")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'"
    )
  end
end

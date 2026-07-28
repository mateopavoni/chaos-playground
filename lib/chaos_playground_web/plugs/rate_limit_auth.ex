defmodule ChaosPlaygroundWeb.Plugs.RateLimitAuth do
  @moduledoc """
  Rate limit para las rutas POST de login/logout. Claves separadas por IP y por
  email en el login: una clave combinada se esquiva rotando de IP, y una sola
  clave por IP penaliza de más a IPs compartidas (oficina/NAT) por un ataque
  contra un único email.
  """
  import Plug.Conn

  alias ChaosPlayground.RateLimit

  def init(opts), do: opts

  def call(%{request_path: "/users/log-in"} = conn, _opts) do
    email = get_in(conn.params, ["user", "email"]) || "unknown"

    check(conn, [
      {"login:ip:#{ip(conn)}", :timer.minutes(1), 20},
      {"login:email:#{email}", :timer.minutes(1), 5}
    ])
  end

  def call(conn, _opts), do: conn

  defp check(conn, rules) do
    if Enum.all?(rules, fn {key, scale, limit} -> match?({:allow, _}, RateLimit.hit(key, scale, limit)) end) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Demasiados intentos, esperá un momento.")
      |> Phoenix.Controller.redirect(to: "/users/log-in")
      |> halt()
    end
  end

  defp ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end

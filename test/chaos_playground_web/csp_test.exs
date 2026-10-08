defmodule ChaosPlaygroundWeb.CspTest do
  use ChaosPlaygroundWeb.ConnCase, async: true

  # El CSP no permite scripts/estilos inline ('self' a secas): un <script> inline en el layout
  # queda bloqueado por el navegador sin ningún error visible en el servidor (es lo que rompía
  # el toggle de tema). Este test falla antes de que eso llegue a un navegador.
  test "el CSP no permite inline y el layout no usa <script> inline", %{conn: conn} do
    conn = get(conn, "/")
    [csp] = get_resp_header(conn, "content-security-policy")

    assert csp =~ "script-src 'self'"
    refute csp =~ "unsafe-inline"

    inline = Regex.scan(~r/<script(?![^>]*\bsrc=)[^>]*>/, html_response(conn, 200))
    assert inline == []
  end

  test "el script de tema se sirve desde 'self'", %{conn: conn} do
    conn = get(conn, "/theme.js")
    assert response(conn, 200) =~ "phx:set-theme"
  end
end

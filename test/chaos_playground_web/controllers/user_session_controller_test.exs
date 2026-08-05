defmodule ChaosPlaygroundWeb.UserSessionControllerTest do
  # async: false — "logs the user in" hace un GET a "/" (PlaygroundLive), que monta
  # el motor OTP global compartido (ver CLAUDE.md: "el engine es global, no hay
  # aislamiento por test"). En paralelo con otro test tocando el mismo engine
  # puede haber una race de {:already_started, pid} al arrancar los nodos.
  use ChaosPlaygroundWeb.ConnCase, async: false

  import ChaosPlayground.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_chaos_playground_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "¡Bienvenido de nuevo!"
    end

    test "shows a distinct welcome message when coming from registration", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, ~p"/users/log-in", %{
          "source" => "register",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "cuenta fue creada"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Email o contraseña inválidos"
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "keeps the email when the password is wrong but the email exists", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      # el email vuelve al form: solo hay que reintentar la contraseña
      assert Phoenix.Flash.get(conn.assigns.flash, :email) == user.email
    end

    test "clears the email when it is not registered, with the same error message", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => "desconocido@example.com", "password" => "invalid_password"}
        })

      # mensaje IDENTICO al de contraseña incorrecta (no filtra si el email existe),
      # lo unico distinto es que el campo email no se repuebla
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Email o contraseña inválidos"
      refute Phoenix.Flash.get(conn.assigns.flash, :email)
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Sesión cerrada"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Sesión cerrada"
    end
  end
end

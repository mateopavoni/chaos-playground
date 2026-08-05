defmodule ChaosPlaygroundWeb.UserSessionController do
  use ChaosPlaygroundWeb, :controller

  alias ChaosPlayground.Accounts
  alias ChaosPlaygroundWeb.UserAuth

  def create(conn, %{"source" => "register"} = params) do
    create(conn, params, "¡Bienvenido! Tu cuenta fue creada.")
  end

  def create(conn, params) do
    create(conn, params, "¡Bienvenido de nuevo!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # El mensaje de error es IDENTICO exista o no el email: nada visible (texto, timing,
      # markup) revela si esta registrado. Lo unico que cambia es la comodidad del reintento:
      # si el email existe lo dejamos cargado para que solo reescriba la contraseña; si no
      # existe lo limpiamos (no repoblamos el flash) porque ahi si hay que corregir el email.
      conn = put_flash(conn, :error, "Email o contraseña inválidos")

      conn =
        if Accounts.get_user_by_email(email) do
          put_flash(conn, :email, String.slice(email, 0, 160))
        else
          conn
        end

      redirect(conn, to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Contraseña actualizada.")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Sesión cerrada.")
    |> UserAuth.log_out_user()
  end
end

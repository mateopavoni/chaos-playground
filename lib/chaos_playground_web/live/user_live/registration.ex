defmodule ChaosPlaygroundWeb.UserLive.Registration do
  use ChaosPlaygroundWeb, :live_view

  alias ChaosPlayground.Accounts
  alias ChaosPlayground.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm -ml-2 gap-1">
          <.icon name="hero-arrow-left" class="size-4" /> Volver al canvas
        </.link>

        <div class="text-center">
          <.header>
            Crear cuenta
            <:subtitle>
              ¿Ya tenés cuenta?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Iniciá sesión
              </.link>
            </:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="registration_form"
          action={~p"/users/log-in"}
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name="source" value="register" />
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            placeholder="vos@ejemplo.com"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Contraseña"
            placeholder="Mínimo 12 caracteres"
            autocomplete="new-password"
            spellcheck="false"
            required
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirmar contraseña"
            placeholder="Repetí la contraseña"
            autocomplete="new-password"
            spellcheck="false"
            required
          />

          <.button phx-disable-with="Creando cuenta…" class="btn btn-primary w-full">
            Crear cuenta
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ChaosPlaygroundWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = change_user_registration(%User{}, %{})
    client_ip = peer_ip(socket)

    {:ok,
     socket
     |> assign(:client_ip, client_ip)
     |> assign_form(changeset, trigger_submit: false)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    if under_registration_rate_limit?(socket) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:noreply,
           socket
           |> assign(:trigger_submit, true)
           |> assign_form(change_user_registration(user, %{}), form_params: user_params)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Demasiados registros desde acá, esperá un momento.")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  # get_connect_info solo se puede leer durante mount/3, no desde handle_event —
  # por eso la IP se captura una vez al montar y se guarda en assigns.
  #
  # :peer_data es el peer TCP crudo del socket WS — detrás del reverse proxy de Dokku
  # eso es siempre la IP del proxy, la misma para todos los clientes (el pipeline de
  # plugs del Endpoint, donde vive `plug RemoteIp`, no corre para el upgrade de
  # WebSocket, así que su reescritura de conn.remote_ip nunca llega acá). Por eso se
  # resuelve la IP real a mano con RemoteIp.from/1 sobre los :x_headers crudos
  # (X-Forwarded-For), con :peer_data como fallback para dev/tests sin proxy delante.
  defp peer_ip(socket) do
    x_headers = get_connect_info(socket, :x_headers) || []

    case RemoteIp.from(x_headers) do
      ip when is_tuple(ip) -> ip |> :inet.ntoa() |> to_string()
      nil -> peer_data_ip(socket)
    end
  end

  defp peer_data_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> "unknown"
    end
  end

  # rate limit de registro vive en la LiveView (no hay ruta POST propia,
  # el "submit" real que existe es el de /users/log-in vía phx-trigger-action).
  defp under_registration_rate_limit?(socket) do
    match?(
      {:allow, _},
      ChaosPlayground.RateLimit.hit(
        "register:ip:#{socket.assigns.client_ip}",
        :timer.hours(1),
        5
      )
    )
  end

  defp change_user_registration(user_or_changeset, attrs) do
    user_or_changeset
    |> User.email_changeset(attrs, validate_unique: false)
    |> User.password_changeset(attrs, hash_password: false)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset, opts \\ []) do
    form_params = Keyword.get(opts, :form_params)
    trigger_submit = Keyword.get(opts, :trigger_submit)

    form =
      if form_params do
        to_form(form_params, as: "user")
      else
        to_form(changeset, as: "user")
      end

    socket
    |> assign(:form, form)
    |> then(fn s ->
      if is_nil(trigger_submit), do: s, else: assign(s, :trigger_submit, trigger_submit)
    end)
  end
end

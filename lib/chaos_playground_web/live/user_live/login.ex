defmodule ChaosPlaygroundWeb.UserLive.Login do
  use ChaosPlaygroundWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Iniciar sesión</p>
            <:subtitle>
              <%= if @current_scope do %>
                Necesitás volver a autenticarte para hacer esta acción.
              <% else %>
                ¿No tenés cuenta? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-brand hover:underline"
                  phx-no-format
                >Registrate</.link> gratis.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            placeholder="vos@ejemplo.com"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <div class="fieldset mb-2">
            <label for={f[:password].id} class="label mb-1">Contraseña</label>
            <div class="relative">
              <input
                type="password"
                id={f[:password].id}
                name={f[:password].name}
                class="w-full input pr-11"
                placeholder="Tu contraseña"
                autocomplete="current-password"
                spellcheck="false"
              />
              <button
                type="button"
                id="login_password_toggle"
                class="absolute inset-y-0 right-0 flex items-center px-3 opacity-50 hover:opacity-100 cursor-pointer"
                aria-label="Mostrar contraseña"
                aria-controls={f[:password].id}
                phx-click={toggle_password_visibility(f[:password].id)}
              >
                <span id="login_password_eye"><.icon name="hero-eye" class="size-5" /></span>
                <span id="login_password_eye_off" class="hidden">
                  <.icon name="hero-eye-slash" class="size-5" />
                </span>
              </button>
            </div>
          </div>
          <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
            Iniciar sesión y quedar logueado <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Iniciar sesión solo esta vez
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  # Mostrar/ocultar contraseña: puro JS del lado del cliente (sin round-trip al server,
  # la contraseña nunca viaja por el socket solo para cambiar el type del input).
  defp toggle_password_visibility(input_id) do
    JS.toggle_attribute({"type", "text", "password"}, to: "##{input_id}")
    |> JS.toggle_attribute(
      {"aria-label", "Ocultar contraseña", "Mostrar contraseña"},
      to: "#login_password_toggle"
    )
    |> JS.toggle_class("hidden", to: "#login_password_eye")
    |> JS.toggle_class("hidden", to: "#login_password_eye_off")
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end

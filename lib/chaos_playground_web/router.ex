defmodule ChaosPlaygroundWeb.Router do
  use ChaosPlaygroundWeb, :router

  import ChaosPlaygroundWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChaosPlaygroundWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :ensure_guest_id
  end

  pipeline :rate_limit_auth do
    plug ChaosPlaygroundWeb.Plugs.RateLimitAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChaosPlaygroundWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:chaos_playground, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChaosPlaygroundWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", ChaosPlaygroundWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ChaosPlaygroundWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ChaosPlaygroundWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ChaosPlaygroundWeb.UserAuth, :mount_current_scope}] do
      live "/", PlaygroundLive
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
    end
  end

  scope "/", ChaosPlaygroundWeb do
    pipe_through [:browser, :rate_limit_auth]

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end

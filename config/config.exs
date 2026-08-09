# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :chaos_playground, :scopes,
  user: [
    default: true,
    module: ChaosPlayground.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: ChaosPlayground.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :chaos_playground,
  ecto_repos: [ChaosPlayground.Repo],
  generators: [timestamp_type: :utc_datetime]

# App is Spanish-only, sin selector de idioma — todos los mensajes de error
# de Ecto (unique_constraint, validate_length, etc.) salen en inglés si esto
# no está seteado, porque Gettext cae al locale "en" por default.
config :chaos_playground, ChaosPlaygroundWeb.Gettext, default_locale: "es"

# Configure the endpoint
config :chaos_playground, ChaosPlaygroundWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ChaosPlaygroundWeb.ErrorHTML, json: ChaosPlaygroundWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ChaosPlayground.PubSub,
  live_view: [signing_salt: "6MLA/d4D"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  chaos_playground: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  chaos_playground: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

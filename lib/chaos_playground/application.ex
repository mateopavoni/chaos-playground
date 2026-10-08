defmodule ChaosPlayground.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChaosPlaygroundWeb.Telemetry,
      ChaosPlayground.Repo,
      {DNSCluster, query: Application.get_env(:chaos_playground, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ChaosPlayground.PubSub},
      ChaosPlaygroundWeb.Presence,
      ChaosPlayground.RateLimit,
      ChaosPlayground.Engine.NodeRegistry,
      ChaosPlayground.Engine.NodeSupervisor,
      ChaosPlayground.Engine.EngineRegistry,
      ChaosPlayground.Engine.UserEngineSupervisor,
      ChaosPlayground.Engine.Reaper,
      # Start to serve requests, typically the last entry
      ChaosPlaygroundWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChaosPlayground.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChaosPlaygroundWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

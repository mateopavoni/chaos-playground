defmodule ChaosPlayground.Repo do
  use Ecto.Repo,
    otp_app: :chaos_playground,
    adapter: Ecto.Adapters.Postgres
end

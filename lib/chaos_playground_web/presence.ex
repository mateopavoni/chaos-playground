defmodule ChaosPlaygroundWeb.Presence do
  use Phoenix.Presence,
    otp_app: :chaos_playground,
    pubsub_server: ChaosPlayground.PubSub
end

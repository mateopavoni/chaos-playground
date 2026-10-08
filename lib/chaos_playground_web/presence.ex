defmodule ChaosPlaygroundWeb.Presence do
  use Phoenix.Presence,
    otp_app: :chaos_playground,
    pubsub_server: ChaosPlayground.PubSub

  @doc "Topic de Presence con las pestañas conectadas al canvas de `user_id`."
  def visitors_topic(user_id), do: "playground:visitors:#{user_id}"
end

defmodule ChaosPlayground.RateLimit do
  @moduledoc """
  Rate limiter compartido (login, registro, guardado de presets). Backend ETS,
  suficiente para un solo nodo — ver Hammer docs si esto pasa a correr multi-nodo.
  """
  use Hammer, backend: :ets
end

defmodule ChaosPlayground.Topologies do
  @moduledoc "Fachada de Ecto para topologías guardadas por el usuario."

  import Ecto.Query, warn: false

  alias ChaosPlayground.Repo
  alias ChaosPlayground.Topologies.SavedTopology

  def list_saved do
    Repo.all(from t in SavedTopology, order_by: [desc: t.inserted_at])
  end

  def save(attrs) do
    %SavedTopology{}
    |> SavedTopology.changeset(attrs)
    |> Repo.insert()
  end

  def get!(id), do: Repo.get!(SavedTopology, id)
end

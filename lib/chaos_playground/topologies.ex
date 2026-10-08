defmodule ChaosPlayground.Topologies do
  @moduledoc "Fachada de Ecto para topologías guardadas por el usuario dueño de cada una."

  import Ecto.Query, warn: false

  alias ChaosPlayground.Accounts.Scope
  alias ChaosPlayground.Repo
  alias ChaosPlayground.Topologies.SavedTopology

  def list_saved(%Scope{user: user}) do
    Repo.all(
      from t in SavedTopology, where: t.user_id == ^user.id, order_by: [desc: t.inserted_at]
    )
  end

  def save(%Scope{user: user}, attrs) do
    %SavedTopology{}
    |> SavedTopology.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def get(%Scope{user: user}, id) do
    case Repo.get_by(SavedTopology, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      saved -> {:ok, saved}
    end
  end
end

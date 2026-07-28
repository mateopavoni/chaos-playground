defmodule ChaosPlayground.Topologies.SavedTopology do
  @moduledoc """
  Una topología guardada por el usuario: nodos (id/type/x/y) + conexiones (pares [from, to])
  + nodo de entrada del tráfico. Mismo shape que usan los presets built-in
  (`ChaosPlayground.Engine.Presets`), así ambos se materializan con la misma función.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_topologies" do
    field :name, :string
    field :entry_node, :string
    field :nodes, {:array, :map}
    field :connections, {:array, {:array, :string}}
    belongs_to :user, ChaosPlayground.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(saved_topology, attrs) do
    saved_topology
    |> cast(attrs, [:name, :entry_node, :nodes, :connections, :user_id])
    |> validate_required([:name, :entry_node, :nodes, :user_id])
    |> validate_length(:name, min: 1, max: 60)
    |> unique_constraint(:name, name: :saved_topologies_user_id_name_index)
  end
end

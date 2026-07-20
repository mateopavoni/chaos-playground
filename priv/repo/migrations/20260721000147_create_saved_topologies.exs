defmodule ChaosPlayground.Repo.Migrations.CreateSavedTopologies do
  use Ecto.Migration

  def change do
    create table(:saved_topologies) do
      add :name, :string, null: false
      add :entry_node, :string, null: false
      add :nodes, :map, null: false
      add :connections, {:array, {:array, :string}}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saved_topologies, [:name])
  end
end

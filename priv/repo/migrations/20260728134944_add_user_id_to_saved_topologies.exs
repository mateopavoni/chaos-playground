defmodule ChaosPlayground.Repo.Migrations.AddUserIdToSavedTopologies do
  use Ecto.Migration

  def change do
    # Los presets guardados hasta ahora no tienen dueño y user_id va a ser
    # NOT NULL — es contenido de demo, no hay nada que valga la pena backfillear.
    execute "TRUNCATE saved_topologies", ""

    alter table(:saved_topologies) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    drop unique_index(:saved_topologies, [:name])
    create index(:saved_topologies, [:user_id])
    create unique_index(:saved_topologies, [:user_id, :name])
  end
end

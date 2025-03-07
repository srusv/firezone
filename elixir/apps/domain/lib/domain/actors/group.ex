defmodule Domain.Actors.Group do
  use Domain, :schema

  schema "actor_groups" do
    field :name, :string

    # Those fields will be set for groups we synced from IdP's
    belongs_to :provider, Domain.Auth.Provider, where: [deleted_at: nil]
    field :provider_identifier, :string

    has_many :policies, Domain.Policies.Policy,
      foreign_key: :actor_group_id,
      where: [deleted_at: nil]

    has_many :memberships, Domain.Actors.Membership, on_replace: :delete
    # TODO: where doesn't work on join tables so soft-deleted records will be preloaded,
    # ref https://github.com/firezone/firezone/issues/2162
    has_many :actors, through: [:memberships, :actor]

    field :created_by, Ecto.Enum, values: ~w[identity provider]a
    belongs_to :created_by_identity, Domain.Auth.Identity

    belongs_to :account, Domain.Accounts.Account

    field :deleted_at, :utc_datetime_usec
    timestamps()
  end
end

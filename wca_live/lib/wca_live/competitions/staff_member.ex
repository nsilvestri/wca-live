defmodule WcaLive.Competitions.StaffMember do
  use WcaLive.Schema
  import Ecto.Changeset

  alias WcaLive.Accounts.User
  alias WcaLive.Competitions.Competition

  # @allowed_roles ["delegate", "organizer", "scoretaker"]
  @allowed_roles ["delegate", "organizer", "staff-dataentry"]

  @required_fields [:roles]
  @optional_fields []

  schema "staff_members" do
    field :roles, {:array, :string}, default: []

    belongs_to :user, User
    belongs_to :competition, Competition
  end

  @doc false
  def changeset(staff_member, attrs) do
    staff_member
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_subset(:roles, @allowed_roles)
  end
end
# `Hibana.Validator`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/validator.ex#L1)

Schema-based request parameter validation.

## Usage

    defmodule MyApp.UserParams do
      use Hibana.Validator

      validate do
        field :name, :string, required: true, min: 2, max: 100
        field :email, :string, required: true, format: ~r/@/
        field :age, :integer, min: 0, max: 150
        field :role, :string, one_of: ["admin", "user", "mod"]
        field :tags, {:array, :string}, default: []
      end
    end

    # In controller
    def create(conn) do
      case MyApp.UserParams.validate(conn.body_params) do
        {:ok, params} -> json(conn, %{user: create_user(params)})
        {:error, errors} -> conn |> put_status(422) |> json(%{errors: errors})
      end
    end

# `do_validate`

# `field`
*macro* 

# `validate`
*macro* 

---

*Consult [api-reference.md](api-reference.md) for complete listing*

defmodule Hibana.Validator do
  @moduledoc """
  Schema-based request parameter validation with type casting.

  Define validation schemas using a declarative DSL, then validate request
  parameters with automatic type casting, required field checking, and
  constraint validation.

  ## Features

  - Declarative field definitions with `validate` and `field` macros
  - Automatic type casting (string to integer, float, boolean, arrays)
  - Required fields, default values
  - Constraints: `:min`, `:max`, `:format` (regex), `:one_of`
  - Generates `validate/1` and `validate!/1` functions

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

  ## Supported Types

  | Type | Casts from |
  |------|-----------|
  | `:string` | Any (via `to_string/1`) |
  | `:integer` | Strings like `"42"` |
  | `:float` | Strings like `"3.14"`, integers |
  | `:boolean` | `"true"`, `"false"` |
  | `{:array, type}` | Lists with elements of inner type |

  ## Field Options

  | Option | Type | Description |
  |--------|------|-------------|
  | `:required` | `boolean()` | Field must be present (default: `false`) |
  | `:default` | `any()` | Default value when field is absent |
  | `:min` | `integer()` | Minimum value (numbers) or length (strings) |
  | `:max` | `integer()` | Maximum value (numbers) or length (strings) |
  | `:format` | `Regex.t()` | String must match regex |
  | `:one_of` | `[any()]` | Value must be in the list |
  """

  defmacro __using__(_opts) do
    quote do
      import Hibana.Validator, only: [validate: 1, field: 2, field: 3]
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      @before_compile Hibana.Validator
    end
  end

  defmacro validate(do: block) do
    quote do
      unquote(block)
    end
  end

  defmacro field(name, type, opts \\ []) do
    quote do
      @fields {unquote(name), unquote(type), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    fields = Module.get_attribute(env.module, :fields) |> Enum.reverse()

    quote do
      import Hibana.Validator, only: [field: 2, field: 3]

      def fields, do: unquote(Macro.escape(fields))

      def validate(params) when is_map(params) do
        Hibana.Validator.do_validate(params, unquote(Macro.escape(fields)))
      end

      def validate!(params) do
        case validate(params) do
          {:ok, result} -> result
          {:error, errors} -> raise ArgumentError, "Validation failed: #{inspect(errors)}"
        end
      end
    end
  end

  @doc """
  Validates a map of parameters against a list of field definitions.

  This is the runtime validation engine called by generated `validate/1` functions.
  You typically do not call this directly; instead, define a validator module
  with `use Hibana.Validator` and call its `validate/1`.

  ## Parameters

    - `params` - A map of parameters to validate (atom or string keys)
    - `fields` - A list of `{name, type, opts}` tuples defining the schema

  ## Returns

    - `{:ok, validated_map}` - A map with validated and cast values (atom keys)
    - `{:error, errors}` - A list of `{field, message}` tuples

  ## Examples

      ```elixir
      Hibana.Validator.do_validate(
        %{"name" => "Alice", "age" => "25"},
        [{:name, :string, [required: true]}, {:age, :integer, [min: 0]}]
      )
      # => {:ok, %{name: "Alice", age: 25}}
      ```
  """
  def do_validate(params, fields) do
    params = stringify_keys(params)

    {result, errors} =
      Enum.reduce(fields, {%{}, []}, fn {name, type, opts}, {acc, errs} ->
        key = to_string(name)
        value = Map.get(params, key)
        required = Keyword.get(opts, :required, false)
        default = Keyword.get(opts, :default)

        cond do
          is_nil(value) and required ->
            {acc, [{name, "is required"} | errs]}

          is_nil(value) ->
            {Map.put(acc, name, default), errs}

          true ->
            case cast_and_validate(value, type, opts) do
              {:ok, casted} -> {Map.put(acc, name, casted), errs}
              {:error, msg} -> {acc, [{name, msg} | errs]}
            end
        end
      end)

    if errors == [] do
      {:ok, result}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp cast_and_validate(value, type, opts) do
    with {:ok, casted} <- cast(value, type),
         :ok <- validate_rules(casted, opts) do
      {:ok, casted}
    end
  end

  defp cast(value, :string) when is_binary(value), do: {:ok, value}
  defp cast(value, :string), do: {:ok, to_string(value)}
  defp cast(value, :integer) when is_integer(value), do: {:ok, value}

  defp cast(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "must be an integer"}
    end
  end

  defp cast(value, :float) when is_float(value), do: {:ok, value}
  defp cast(value, :float) when is_integer(value), do: {:ok, value / 1}

  defp cast(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "must be a number"}
    end
  end

  defp cast(value, :boolean) when is_boolean(value), do: {:ok, value}
  defp cast("true", :boolean), do: {:ok, true}
  defp cast("false", :boolean), do: {:ok, false}

  defp cast(value, {:array, inner_type}) when is_list(value) do
    results = Enum.map(value, &cast(&1, inner_type))
    errors = Enum.filter(results, &match?({:error, _}, &1))
    if errors == [], do: {:ok, Enum.map(results, fn {:ok, v} -> v end)}, else: hd(errors)
  end

  defp cast(_, type), do: {:error, "invalid type, expected #{inspect(type)}"}

  defp validate_rules(value, opts) do
    opts
    |> Enum.reduce(:ok, fn
      {:required, _}, acc ->
        acc

      {:default, _}, acc ->
        acc

      {:min, min}, :ok when is_binary(value) ->
        if String.length(value) >= min,
          do: :ok,
          else: {:error, "must be at least #{min} characters"}

      {:min, min}, :ok when is_number(value) ->
        if value >= min, do: :ok, else: {:error, "must be at least #{min}"}

      {:max, max}, :ok when is_binary(value) ->
        if String.length(value) <= max,
          do: :ok,
          else: {:error, "must be at most #{max} characters"}

      {:max, max}, :ok when is_number(value) ->
        if value <= max, do: :ok, else: {:error, "must be at most #{max}"}

      {:format, regex}, :ok when is_binary(value) ->
        if Regex.match?(regex, value), do: :ok, else: {:error, "has invalid format"}

      {:one_of, values}, :ok ->
        if value in values,
          do: :ok,
          else: {:error, "must be one of: #{Enum.join(values, ", ")}"}

      _, acc ->
        acc
    end)
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end

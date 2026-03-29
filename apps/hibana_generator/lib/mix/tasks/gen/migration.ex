defmodule Mix.Tasks.Gen.Migration do
  use Mix.Task

  @shortdoc "Generate a new migration"

  @moduledoc """
  Generates a new database migration file.

      mix gen.migration create_users

  This will create:
  - priv/repo/migrations/YYYYMMDDHHMMSS_create_users.exs

  ## Examples

      mix gen.migration create_users
      mix gen.migration add_email_to_users
      mix gen.migration create_posts title:string body:text published:boolean
  """

  @doc """
  Runs the migration generator.

  ## Parameters

    - `args` - Command-line arguments: `[name, field:type, ...]`

  ## Examples

      ```
      mix gen.migration create_users
      mix gen.migration add_email_to_users email:string
      ```
  """
  @impl true
  def run(args) do
    case OptionParser.parse(args, switches: []) do
      {_, [name | _]} ->
        generate_migration(name, args)

      _ ->
        Mix.raise("Usage: mix gen.migration <name> [fields]")
    end
  end

  defp generate_migration(name, args) do
    timestamp = :os.system_time(:second) |> format_timestamp()
    migration_name = "#{timestamp}_#{name |> String.replace(" ", "_")}"

    app_path = File.cwd!()
    priv_path = Path.join(app_path, "priv")

    repo_path = Path.join(priv_path, "repo")
    migrations_path = Path.join(repo_path, "migrations")

    File.mkdir_p!(migrations_path)

    fields = parse_fields(args -- [name])

    migration_content = generate_migration_content(name, fields)

    file_path = Path.join(migrations_path, "#{migration_name}.exs")
    File.write!(file_path, migration_content)

    Mix.shell().info("Generated migration at #{file_path}")
  end

  defp format_timestamp(ts) when is_integer(ts) do
    {{year, month, day}, {hour, minute, second}} = :calendar.now_to_local_time(:os.timestamp())
    :io.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [year, month, day, hour, minute, second])
    "#{year}#{pad(month)}#{pad(day)}#{pad(hour)}#{pad(minute)}#{pad(second)}"
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"

  defp parse_fields([]), do: []

  @valid_types ~w(string integer float boolean date datetime naive_datetime utc_datetime time binary id uuid decimal map array references)a

  defp parse_fields(field_args) do
    Enum.map(field_args, fn field ->
      case String.split(field, ":") do
        [name] -> {name, :string, []}
        [name, type] -> {name, safe_type(type), []}
        [name, type | options] -> {name, safe_type(type), parse_options(options)}
      end
    end)
  end

  defp safe_type(type) do
    atom = String.to_atom(type)

    if atom in @valid_types,
      do: atom,
      else: raise("Unknown field type: #{type}. Valid types: #{inspect(@valid_types)}")
  end

  @valid_options ~w(null default size precision scale primary_key unique index)a

  defp parse_options(options) do
    Enum.map(options, fn opt ->
      case String.split(opt, ":") do
        [key] -> {safe_option(key), true}
        [key, val] -> {safe_option(key), parse_value(val)}
      end
    end)
  end

  defp safe_option(key) do
    atom = String.to_atom(key)

    if atom in @valid_options,
      do: atom,
      else: raise("Unknown option: #{key}. Valid options: #{inspect(@valid_options)}")
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(val), do: val

  defp generate_migration_content(name, fields) do
    table_name = name |> String.replace("create_", "") |> String.replace("_", "")
    schema_fields = generate_migration_fields(fields)

    """
    defmodule #{Macro.camelize(name)} do
      use Ecto.Migration

      def change do
        create table(:#{table_name}) do
          #{schema_fields}

          timestamps()
        end

        #{generate_indexes(table_name, fields)}
      end
    end
    """
  end

  defp generate_migration_fields(fields) do
    Enum.map_join(fields, "\n", fn {name, type, opts} ->
      opts_str = format_field_opts(opts)
      "add :#{name}, :#{type}#{opts_str}"
    end)
  end

  defp format_field_opts([]), do: ""

  defp format_field_opts(opts) do
    opts
    |> Enum.map(fn
      {:null, false} -> ", null: false"
      {:default, val} -> ", default: #{val}"
      {:unique, true} -> ""
      _ -> ""
    end)
    |> Enum.join()
  end

  defp generate_indexes(_table, []), do: ""

  defp generate_indexes(table, fields) do
    fields
    |> Enum.filter(fn {_, _, opts} -> Keyword.get(opts, :unique, false) end)
    |> Enum.map(fn {name, _, _} ->
      "create index(:#{table}, [:#{name}], unique: true)"
    end)
    |> Enum.join("\n        ")
  end
end

defmodule Mix.Tasks.Gen.Model do
  use Mix.Task

  @shortdoc "Generate a new model"

  @moduledoc """
  Generates a new Ecto model/schema file.

      mix gen.model User name:string age:integer email:unique

  This will create:
  - lib/my_app/models/user.ex

  ## Options

  - `--path` - Custom path (default: models/)
  - `--migration` - Also generate migration (default: true)

  ## Field Types

  - string, text, integer, bigint, float, decimal, boolean
  - uuid, binary, datetime, naive_datetime, date, time
  - array, map, json

  ## Field Options

  - unique, index, null:false, default:value

  ## Examples

      mix gen.model User name:string email:unique
      mix gen.model Post title:string body:text published:boolean
  """

  @impl true
  def run(args) do
    {opts, [name | field_args], _} =
      OptionParser.parse(args,
        switches: [path: :string, migration: :boolean],
        aliases: [p: :path, m: :migration]
      )

    generate_model(name, field_args, opts)
  end

  defp generate_model(name, field_args, opts) do
    module_name = Macro.camelize(name)
    model_file = Macro.underscore(name)
    path = opts[:path] || "models"

    app_path = File.cwd!()
    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    model_path = Path.join([app_path, "lib", to_string(Mix.Project.config()[:app]), path])

    File.mkdir_p!(model_path)

    fields = parse_fields(field_args)

    model_content = """
    defmodule #{app_module}.#{module_name} do
      use Hibana.Ecto.Model

      schema "#{model_file}s" do
        #{generate_schema_fields(fields)}
        timestamps()
      end

      def changeset(struct, attrs) do
        struct
        |> cast(attrs, #{fields |> Enum.map(fn {f, _} -> ~c"#{f}" end) |> Enum.join(", ")})
        #{generate_validations(fields)}
      end
    end
    """

    file_path = Path.join(model_path, "#{model_file}.ex")
    File.write!(file_path, model_content)

    Mix.shell().info("Generated model at #{file_path}")

    if opts[:migration] != false do
      generate_migration(module_name, fields, app_module)
    end
  end

  defp parse_fields(field_args) do
    Enum.map(field_args, fn field ->
      case String.split(field, ":") do
        [name] -> {name, :string, []}
        [name, type] -> {name, String.to_atom(type), []}
        [name, type | options] -> {name, String.to_atom(type), parse_options(options)}
      end
    end)
  end

  defp parse_options(options) do
    Enum.map(options, fn opt ->
      case String.split(opt, ":") do
        [key] -> {String.to_atom(key), true}
        [key, val] -> {String.to_atom(key), parse_value(val)}
      end
    end)
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(val), do: val

  defp generate_schema_fields(fields) do
    Enum.map_join(fields, "\n      ", fn {name, type, _opts} ->
      "field :#{name}, :#{type}"
    end)
  end

  defp generate_validations(_fields) do
    ""
  end

  defp generate_migration(_module_name, _fields, _app_module) do
    ""
  end
end

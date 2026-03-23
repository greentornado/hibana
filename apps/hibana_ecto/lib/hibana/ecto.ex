defmodule Hibana.Ecto do
  @moduledoc """
  Ecto integration for Hibana.

  ## Usage

  ### MySQL Configuration
      config :my_app, MyApp.Repo,
        adapter: Hibana.Ecto.Adapters.MySQL,
        database: "my_app_dev",
        username: "root",
        password: "",
        hostname: "localhost"

  ### PostgreSQL Configuration
      config :my_app, MyApp.Repo,
        adapter: Hibana.Ecto.Adapters.PostgreSQL,
        database: "my_app_dev",
        username: "postgres",
        password: "",
        hostname: "localhost"

  ### MongoDB Configuration
      config :my_app, MyApp.Repo,
        adapter: Hibana.Ecto.Adapters.MongoDB,
        database: "my_app_dev",
        hostname: "localhost",
        port: 27017

  """

  defmacro __using__(_opts \\ []) do
    quote do
      import Ecto.Query
      import Ecto.Changeset
    end
  end
end

defmodule Hibana.Ecto.Adapters.MySQL do
  @moduledoc """
  MySQL adapter for Hibana.
  Uses Ecto.Adapters.MyXQL from ecto_sql.
  """
  defmacro __using__(opts) do
    quote do
      use Ecto.Adapters.MyXQL, unquote(opts)
    end
  end
end

defmodule Hibana.Ecto.Adapters.PostgreSQL do
  @moduledoc """
  PostgreSQL adapter for Hibana.
  Uses Ecto.Adapters.Postgres from ecto_sql.
  """
  defmacro __using__(opts) do
    quote do
      use Ecto.Adapters.Postgres, unquote(opts)
    end
  end
end

defmodule Hibana.Ecto.Adapters.MongoDB do
  @moduledoc """
  MongoDB adapter for Hibana.
  Uses MongoDB.Driver directly with Ecto-like syntax.
  """
  alias Mongo

  defmacro __using__(_opts \\ []) do
    quote do
      use Ecto.Adapter
    end
  end

  def start_link(opts) do
    database = Keyword.get(opts, :database, "hibana")
    hostname = Keyword.get(opts, :hostname, "localhost")
    port = Keyword.get(opts, :port, 27017)
    Mongo.start_link(hostname: hostname, port: port, database: database)
  end
end

defmodule Hibana.Ecto.Repo do
  @moduledoc """
  Base Repo for Hibana applications.

  ## Usage

  Define a repo in your application:

      defmodule MyApp.Repo do
        use Hibana.Ecto.Repo, otp_app: :my_app
      end

  Then configure in config/config.exs:

      config :my_app, MyApp.Repo,
        adapter: Hibana.Ecto.Adapters.MySQL,
        database: "my_app_dev",
        username: "root",
        password: "",
        hostname: "localhost"

  """

  defmacro __using__(opts) do
    quote do
      use Ecto.Repo, unquote(opts)
    end
  end
end

defmodule Hibana.Ecto.Model do
  @moduledoc """
  Base model for Hibana applications.
  """
  use Ecto.Schema

  defmacro __using__(_opts \\ []) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
    end
  end
end

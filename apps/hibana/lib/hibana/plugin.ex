defmodule Hibana.Plugin do
  @moduledoc """
  Behaviour for Hibana plugins.

  ## Example

      defmodule MyApp.AuthPlugin do
        @behaviour Hibana.Plugin

        def init(opts) do
          # Initialize plugin with options
          opts
        end

        def call(conn, _opts) do
          # Process the request
          conn
        end

        def before_send(conn, _opts) do
          # Called before response is sent
          conn
        end
      end

  """

  @doc """
  Called when the plugin is initialized. Use this to set up state and
  validate options.
  """
  @callback init(opts :: any()) :: any()

  @doc """
  Called for each request. This is the main entry point for the plugin.
  Must return the connection, possibly with modifications.
  """
  @callback call(conn :: Plug.Conn.t(), opts :: any()) :: Plug.Conn.t()

  @doc """
  Called just before the response is sent. Use this for cleanup or
  adding response headers.
  """
  @callback before_send(conn :: Plug.Conn.t(), opts :: any()) :: Plug.Conn.t()

  @doc """
  Optional. Called when the plugin is started.
  """
  @callback start_link(opts :: any()) :: {:ok, pid()} | {:error, term()}

  @optional_callbacks [before_send: 2, start_link: 1]

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Hibana.Plugin

      def init(opts) do
        opts
      end

      def call(conn, _opts) do
        conn
      end

      def before_send(conn, _opts) do
        conn
      end

      def start_link(opts) do
        Agent.start_link(fn -> opts end)
      end

      defoverridable init: 1, call: 2, before_send: 2, start_link: 1
    end
  end
end

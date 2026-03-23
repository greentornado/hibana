defmodule Hibana.GenServer do
  @moduledoc """
  Base GenServer module for Hibana applications.

  ## Features

  - Sensible defaults for common use cases
  - Automatic naming via `name: __MODULE__`
  - Standard init/1 callback pattern

  ## Example

      defmodule MyApp.StateManager do
        use Hibana.GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def get_state, do: GenServer.call(__MODULE__, :get_state)
        def update_state(new_state), do: GenServer.cast(__MODULE__, {:update_state, new_state})

        def handle_call(:get_state, _from, state) do
          {:reply, state, state}
        end

        def handle_cast({:update_state, new_state}, _state) do
          {:noreply, new_state}
        end
      end

  ## Usage

      {:ok, pid} = MyApp.StateManager.start_link([])
      GenServer.call(MyApp.StateManager, :get_state)
  """

  defmacro __using__(opts \\ []) do
    quote do
      use GenServer, unquote(opts)

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @doc """
      Default init/1 callback. Override this to provide custom initialization.
      """
      @impl true
      def init(opts) do
        {:ok, opts}
      end

      defoverridable start_link: 1, init: 1
    end
  end
end

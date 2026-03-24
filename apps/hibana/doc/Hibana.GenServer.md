# `Hibana.GenServer`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/gen_server.ex#L1)

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*

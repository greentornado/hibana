defmodule LiveviewCounter.CounterSocket do
  use Hibana.WebSocket

  def upgrade(conn) do
    Hibana.WebSocket.upgrade(conn, __MODULE__)
  end

  def init(_conn, _opts) do
    {:ok, %Plug.Conn{}, %{count: 0}}
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, %{"event" => "increment"}} ->
        new_state = %{state | count: state.count + 1}
        {:reply, {:text, Jason.encode!(%{count: new_state.count})}, new_state}

      {:ok, %{"event" => "decrement"}} ->
        new_state = %{state | count: state.count - 1}
        {:reply, {:text, Jason.encode!(%{count: new_state.count})}, new_state}

      {:ok, %{"event" => "reset"}} ->
        new_state = %{state | count: 0}
        {:reply, {:text, Jason.encode!(%{count: 0})}, new_state}

      _ ->
        {:ok, state}
    end
  end
end

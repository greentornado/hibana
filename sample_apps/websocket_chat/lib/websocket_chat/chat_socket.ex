defmodule WebsocketChat.ChatSocket do
  use Hibana.WebSocket

  def upgrade(conn) do
    Hibana.WebSocket.upgrade(conn, __MODULE__)
  end

  def init(conn, _opts) do
    {:ok, conn, %{}}
  end

  def handle_connect(_info, state) do
    {:ok, state}
  end

  def handle_disconnect(_reason, state) do
    {:ok, state}
  end

  def handle_in(message, state) do
    {:reply, {:text, "Echo: #{message}"}, state}
  end

  def handle_binary(_message, state) do
    {:reply, {:text, "Binary not supported"}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end
end

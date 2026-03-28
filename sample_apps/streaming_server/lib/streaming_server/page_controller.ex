defmodule StreamingServer.PageController do
  use Hibana.Controller

  def index(conn, _params) do
    json(conn, %{message: "Welcome to StreamingServer!", status: "running"})
  end

  def hello(conn, %{"name" => name}) do
    json(conn, %{hello: name})
  end
end

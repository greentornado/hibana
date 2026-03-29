defmodule RealtimeCluster.PageController do
  use Hibana.Controller

  def index(conn) do
    json(conn, %{message: "Welcome to RealtimeCluster!", status: "running"})
  end

  def hello(conn) do
    name = conn.params["name"] || "World"
    json(conn, %{hello: name})
  end
end

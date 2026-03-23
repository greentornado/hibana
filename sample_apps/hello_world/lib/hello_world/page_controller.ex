defmodule HelloWorld.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head><title>Hello World</title></head>
    <body>
      <h1>Welcome to HelloWorld App</h1>
      <ul>
        <li><a href="/hello">Say Hello</a></li>
        <li><a href="/hello/Elixir">Say Hello to Elixir</a></li>
      </ul>
    </body>
    </html>
    """)
  end

  def hello(conn) do
    text(conn, "Hello, World!")
  end

  def hello_with_name(conn) do
    name = conn.params["name"]
    text(conn, "Hello, #{name}!")
  end
end

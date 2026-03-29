defmodule Hibana.ControllerTest do
  use ExUnit.Case, async: true
  use Hibana.TestHelpers

  alias Hibana.Controller

  describe "__using__ macro" do
    test "imports Plug.Conn functions" do
      defmodule TestController do
        use Controller
      end

      assert function_exported?(TestController, :put_resp_content_type, 2)
    end

    test "imports Hibana.Controller functions" do
      defmodule TestController2 do
        use Controller
      end

      assert function_exported?(TestController2, :json, 2)
      assert function_exported?(TestController2, :html, 2)
      assert function_exported?(TestController2, :text, 2)
    end
  end

  describe "render/4" do
    defmodule MockView do
      def render("index.html", assigns) do
        "<h1>#{assigns[:title]}</h1>"
      end
    end

    test "renders template via view module" do
      conn = conn(:get, "/")
      conn = Controller.render(conn, MockView, "index.html", %{title: "Welcome"})

      assert conn.status == 200
      assert conn.resp_body == "<h1>Welcome</h1>"
    end
  end

  describe "json/2" do
    test "sends JSON response" do
      conn = conn(:get, "/api/users")
      conn = Controller.json(conn, %{users: ["alice", "bob"]})

      assert conn.status == 200
      assert conn.resp_body == ~s({"users":["alice","bob"]})
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
    end

    test "sends JSON with custom status" do
      conn =
        conn(:post, "/api/users")
        |> Controller.put_status(201)
        |> Controller.json(%{created: true})

      assert conn.status == 201
    end
  end

  describe "text/2" do
    test "sends plain text response" do
      conn = conn(:get, "/hello")
      conn = Controller.text(conn, "Hello, World!")

      assert conn.status == 200
      assert conn.resp_body == "Hello, World!"
      assert {"content-type", "text/plain; charset=utf-8"} in conn.resp_headers
    end

    test "sends text with custom status" do
      conn =
        conn(:get, "/not-found")
        |> Controller.put_status(404)
        |> Controller.text("Not Found")

      assert conn.status == 404
    end
  end

  describe "html/2" do
    test "sends HTML response" do
      conn = conn(:get, "/")
      conn = Controller.html(conn, "<h1>Welcome</h1>")

      assert conn.status == 200
      assert conn.resp_body == "<h1>Welcome</h1>"
      assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    end

    test "sends HTML with custom status" do
      conn =
        conn(:get, "/error")
        |> Controller.put_status(500)
        |> Controller.html("<h1>Error</h1>")

      assert conn.status == 500
    end
  end

  describe "redirect/2" do
    test "redirects with 302 status" do
      conn = conn(:get, "/old-path")
      conn = Controller.redirect(conn, to: "/new-path")

      assert conn.status == 302
      assert {"location", "/new-path"} in conn.resp_headers
    end
  end

  describe "send_file/3" do
    test "sends file with auto-detected content type" do
      conn = conn(:get, "/download")
      conn = Controller.send_file(conn, "/test/file.html")

      assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
      assert {"content-disposition", "attachment; filename=\"file.html\""} in conn.resp_headers
    end

    test "sends file with custom filename" do
      conn = conn(:get, "/download")
      conn = Controller.send_file(conn, "/test/file.html", filename: "custom.html")

      assert {"content-disposition", "attachment; filename=\"custom.html\""} in conn.resp_headers
    end
  end

  describe "put_status/2" do
    test "updates the status code" do
      conn = %Plug.Conn{status: 200}
      result = Controller.put_status(conn, 404)
      assert result.status == 404
    end

    test "overrides previous status" do
      conn = %Plug.Conn{status: 200}
      conn = Controller.put_status(conn, 404)
      assert conn.status == 404
    end
  end

  describe "get_status/1" do
    test "returns the status code" do
      conn = %Plug.Conn{status: 201}
      assert Controller.get_status(conn) == 201
    end

    test "returns nil when not set" do
      conn = %Plug.Conn{status: nil}
      assert Controller.get_status(conn) == nil
    end
  end

  describe "get_body_params/1" do
    test "returns body params" do
      conn = %Plug.Conn{body_params: %{"name" => "test"}}
      assert Controller.get_body_params(conn) == %{"name" => "test"}
    end
  end

  describe "get_query_params/1" do
    test "returns query params" do
      conn = %Plug.Conn{query_params: %{"page" => "1"}}
      assert Controller.get_query_params(conn) == %{"page" => "1"}
    end
  end

  describe "req_header/2" do
    test "returns request header value" do
      conn = %Plug.Conn{req_headers: [{"content-type", "application/json"}]}
      assert Controller.req_header(conn, "Content-Type") == "application/json"
    end

    test "returns nil for missing header" do
      conn = %Plug.Conn{req_headers: []}
      assert Controller.req_header(conn, "X-Custom") == nil
    end
  end

  describe "get_session/2" do
    test "returns session value from __session__ in assigns" do
      conn = %Plug.Conn{assigns: %{__session__: %{user_id: 123}}}
      assert Controller.get_session(conn, :user_id) == 123
    end

    test "returns nil for missing session key" do
      conn = %Plug.Conn{assigns: %{}}
      assert Controller.get_session(conn, :user_id) == nil
    end
  end

  describe "put_session/3" do
    test "adds value to __session__ in assigns" do
      conn = %Plug.Conn{}
      result = Controller.put_session(conn, :user_id, 123)
      assert result.assigns[:__session__][:user_id] == 123
    end
  end

  describe "fetch_query_params/2" do
    test "fetches query params" do
      conn = conn(:get, "/?page=1")
      result = Controller.fetch_query_params(conn)
      assert result.query_params != nil
    end
  end

  describe "fetch_body_params/2" do
    test "fetches body params" do
      conn = conn(:get, "/")
      result = Controller.fetch_body_params(conn)
      assert result.body_params != nil
    end

    test "returns conn unchanged" do
      conn = conn(:get, "/")
      result = Controller.fetch_body_params(conn, [])
      assert result == conn
    end
  end

  describe "MIME type detection" do
    test "detects HTML files" do
      conn = conn(:get, "/")
      conn = Controller.send_file(conn, "/test/file.html")
      assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    end

    test "detects JSON files" do
      conn = conn(:get, "/")
      conn = Controller.send_file(conn, "/test/file.json")
      assert {"content-type", "application/json; charset=utf-8"} in conn.resp_headers
    end

    test "detects image files" do
      conn = conn(:get, "/")

      conn_png = Controller.send_file(conn, "/test/file.png")
      assert {"content-type", "image/png"} in conn_png.resp_headers

      conn_jpg = Controller.send_file(conn, "/test/file.jpg")
      assert {"content-type", "image/jpeg"} in conn_jpg.resp_headers
    end

    test "defaults to octet-stream for unknown extensions" do
      conn = conn(:get, "/")
      conn = Controller.send_file(conn, "/test/file.xyz")
      assert {"content-type", "application/octet-stream"} in conn.resp_headers
    end
  end
end

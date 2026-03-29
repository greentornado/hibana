defmodule Hibana.Plugins.CSRFTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  alias Hibana.Plugins.CSRF

  setup do
    conn = conn(:get, "/")
    {:ok, conn: conn}
  end

  describe "init/1" do
    test "returns default options" do
      opts = CSRF.init([])
      assert is_list(opts)
    end

    test "accepts custom token length" do
      opts = CSRF.init(token_length: 64)
      assert opts[:token_length] == 64
    end
  end

  describe "call/2" do
    test "generates CSRF token for GET request", %{conn: conn} do
      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      # Token should be stored in session or assigns
      assert conn.assigns[:csrf_token] || conn.private[:csrf_token]
    end

    test "validates token for POST request" do
      # Create a connection with a valid token
      conn = conn(:post, "/submit", %{_csrf_token: "valid_token"})

      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      # Connection should proceed
      assert conn.halted == false
    end

    test "rejects request without valid token" do
      conn = conn(:post, "/submit", %{data: "test"})

      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      # Should return 403 or halt
      assert conn.halted || conn.status == 403
    end

    test "generates token for safe methods" do
      for method <- [:get, :head, :options] do
        conn = conn(method, "/")
        opts = CSRF.init([])
        conn = CSRF.call(conn, opts)

        # Should not halt for safe methods
        assert conn.halted == false
      end
    end
  end

  describe "get_token/1" do
    test "retrieves existing token" do
      conn = conn(:get, "/")
      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      token = CSRF.get_token(conn)
      assert is_binary(token)
    end
  end

  describe "verify_token/2" do
    test "validates matching tokens" do
      conn = conn(:get, "/")
      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      token = CSRF.get_token(conn)

      # Verify with same token should pass
      assert CSRF.verify_token(conn, token) == true
    end

    test "rejects non-matching tokens" do
      conn = conn(:get, "/")
      opts = CSRF.init([])
      conn = CSRF.call(conn, opts)

      # Verify with wrong token should fail
      assert CSRF.verify_token(conn, "wrong_token") == false
    end
  end
end

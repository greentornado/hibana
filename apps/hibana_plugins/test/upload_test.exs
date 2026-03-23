defmodule Hibana.Plugins.UploadTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.Upload.init([])
      assert opts.max_file_size == 5_000_000
      assert opts.allowed_types == []
      assert opts.upload_dir == "priv/uploads"
    end

    test "allows custom options" do
      opts =
        Hibana.Plugins.Upload.init(
          max_file_size: 10_000_000,
          allowed_types: ["image/png"],
          upload_dir: "/tmp/uploads"
        )

      assert opts.max_file_size == 10_000_000
      assert opts.allowed_types == ["image/png"]
      assert opts.upload_dir == "/tmp/uploads"
    end
  end

  describe "call/2" do
    test "returns conn for non-upload path" do
      conn = Plug.Test.conn(:get, "/users")
      opts = Hibana.Plugins.Upload.init([])
      result = Hibana.Plugins.Upload.call(conn, opts)
      assert %Plug.Conn{} = result
    end
  end
end

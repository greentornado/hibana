defmodule Hibana.Plugins.CORSTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.CORS

  describe "init/1" do
    test "sets default options" do
      opts = CORS.init([])
      assert opts.origins == [{:literal, "*"}]
      assert opts.methods == ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
      assert opts.credentials == false
    end

    test "allows custom options" do
      opts = CORS.init(origins: ["https://example.com"], methods: ["GET", "POST"])
      assert opts.origins == [{:literal, "https://example.com"}]
      assert opts.methods == ["GET", "POST"]
    end

    test "compiles regex origins" do
      opts = CORS.init(origins: ["^https://.*\\.example\\.com$"])
      assert [{:regex, %Regex{}}] = opts.origins
    end
  end
end

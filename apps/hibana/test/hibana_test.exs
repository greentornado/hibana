defmodule HibanaTest do
  use ExUnit.Case, async: true

  describe "version/0" do
    test "returns the application version" do
      assert Hibana.version() == "0.1.0"
    end
  end
end

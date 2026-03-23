defmodule Hibana.ApplicationTest do
  use ExUnit.Case, async: true

  describe "start/2" do
    test "returns supervisor result" do
      result = Hibana.Application.start(:normal, [])
      assert is_tuple(result)
    end
  end
end

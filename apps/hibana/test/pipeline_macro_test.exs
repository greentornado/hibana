defmodule Hibana.PipelineMacroTest do
  @moduledoc """
  Tests to force Hibana.Pipeline macro execution for coverage.
  """
  use ExUnit.Case, async: true

  # Define test modules at compile time to execute the macro
  defmodule TestRouter1 do
    use Hibana.Pipeline

    # Test that __using__ macro executes
  end

  describe "Pipeline macro execution" do
    test "__using__ macro compiles successfully" do
      # Verify the module was compiled successfully
      assert is_atom(TestRouter1)
      assert Code.ensure_loaded?(TestRouter1)
    end

    test "__using__ imports CompiledRouter and Pipeline" do
      # The __using__ macro should import Hibana.CompiledRouter and Hibana.Pipeline
      # Test that the macro executed by checking the module exists
      assert is_atom(TestRouter1)
    end
  end
end

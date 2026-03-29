defmodule Hibana.JobMacroTest do
  @moduledoc """
  Tests to force Hibana.Job macro execution for coverage.
  """
  use ExUnit.Case, async: false

  # Define test modules at compile time
  defmodule TestJob1 do
    use Hibana.Job

    def perform(args) do
      send(args[:test_pid], {:job_done, args[:value]})
      :ok
    end
  end

  defmodule TestJob2 do
    use Hibana.Job, retry: 3
    # No perform implementation - uses default
  end

  describe "Job macro execution" do
    test "__using__ generates enqueue/1 function" do
      {:ok, _} = Hibana.Job.Worker.start_link(name: Hibana.Job.Worker)

      result = TestJob1.enqueue(%{test_pid: self(), value: 42})
      assert result == :ok

      assert_receive {:job_done, 42}, 2000
      GenServer.stop(Hibana.Job.Worker)
    end

    test "__using__ generates default perform/1 that raises" do
      assert_raise RuntimeError, "perform/1 not implemented", fn ->
        TestJob2.perform(%{})
      end
    end

    test "perform/1 can be overridden" do
      defmodule TestJob3 do
        use Hibana.Job

        def perform(_args) do
          {:performed}
        end
      end

      assert TestJob3.perform(%{}) == {:performed}
    end
  end
end

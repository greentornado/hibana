defmodule Hibana.WarmupTest do
  use ExUnit.Case, async: false

  defmodule TestWarmup do
    use Hibana.Warmup

    warmup "set test flag" do
      Process.put(:warmup_test_ran, true)
    end

    warmup "compute value" do
      Process.put(:warmup_value, 42)
    end
  end

  test "start_link runs warmup tasks and returns :ignore" do
    assert :ignore = TestWarmup.start_link([])
  end

  test "warmup tasks execute during start_link" do
    # Process dictionary is per-process, so tasks run in current process
    TestWarmup.start_link([])
    assert Process.get(:warmup_test_ran) == true
    assert Process.get(:warmup_value) == 42
  end

  test "child_spec returns correct spec" do
    spec = TestWarmup.child_spec([])
    assert spec.id == TestWarmup
    assert spec.type == :worker
    assert spec.restart == :temporary
    assert {TestWarmup, :start_link, [[]]} = spec.start
  end

  defmodule FailingWarmup do
    use Hibana.Warmup

    warmup "will fail" do
      raise "intentional error"
    end

    warmup "will succeed" do
      Process.put(:after_failure, true)
    end
  end

  test "failing warmup task does not crash, continues to next" do
    assert :ignore = FailingWarmup.start_link([])
    # The second task should still run despite the first failing
    assert Process.get(:after_failure) == true
  end
end

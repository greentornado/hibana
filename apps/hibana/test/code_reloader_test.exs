defmodule Hibana.CodeReloaderTest do
  use ExUnit.Case

  alias Hibana.CodeReloader

  describe "start_link/1" do
    test "starts with default options" do
      {:ok, pid} = CodeReloader.start_link(dirs: ["lib"])
      assert Process.alive?(pid)

      :ok = GenServer.stop(pid)
    end

    test "starts with custom debounce" do
      {:ok, pid} = CodeReloader.start_link(dirs: ["lib"], debounce: 500)
      assert Process.alive?(pid)

      :ok = GenServer.stop(pid)
    end
  end

  describe "reload/0" do
    test "triggers code reload" do
      # This should not raise
      :ok = CodeReloader.reload()
    end
  end

  describe "child_spec/1" do
    test "returns child specification" do
      spec = CodeReloader.child_spec(dirs: ["lib"])

      assert spec.id == Hibana.CodeReloader
      assert spec.type == :worker
    end
  end
end

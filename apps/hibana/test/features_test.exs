defmodule Hibana.FeaturesTest do
  use ExUnit.Case, async: false

  alias Hibana.Features

  setup do
    # Clean up features config before each test
    original = Application.get_env(:hibana, :features)
    original_blocked = Application.get_env(:hibana, :disabled_features)

    on_exit(fn ->
      if original,
        do: Application.put_env(:hibana, :features, original),
        else: Application.delete_env(:hibana, :features)

      if original_blocked,
        do: Application.put_env(:hibana, :disabled_features, original_blocked),
        else: Application.delete_env(:hibana, :disabled_features)
    end)

    Application.delete_env(:hibana, :disabled_features)
    :ok
  end

  describe "enabled?/1 with no config" do
    test "returns true when no config (all enabled by default)" do
      Application.delete_env(:hibana, :features)
      assert Features.enabled?(SomeModule) == true
    end
  end

  describe "enabled?/1 with list config" do
    test "returns true for module in list" do
      Application.put_env(:hibana, :features, [ModuleA, ModuleB])
      assert Features.enabled?(ModuleA) == true
      assert Features.enabled?(ModuleB) == true
    end

    test "returns false for module not in list" do
      Application.put_env(:hibana, :features, [ModuleA])
      assert Features.enabled?(ModuleC) == false
    end
  end

  describe "enabled?/1 with map config" do
    test "returns true for module set to true" do
      Application.put_env(:hibana, :features, %{ModuleA => true})
      assert Features.enabled?(ModuleA) == true
    end

    test "returns false for module set to false" do
      Application.put_env(:hibana, :features, %{ModuleA => false})
      assert Features.enabled?(ModuleA) == false
    end

    test "returns false for module not in map" do
      Application.put_env(:hibana, :features, %{ModuleA => true})
      assert Features.enabled?(ModuleB) == false
    end
  end

  describe "enable/1" do
    test "enables a module in list config" do
      Application.put_env(:hibana, :features, [ModuleA])
      Features.enable(ModuleB)
      assert Features.enabled?(ModuleB) == true
    end

    test "enables a module in map config" do
      Application.put_env(:hibana, :features, %{ModuleA => true, ModuleB => false})
      Features.enable(ModuleB)
      assert Features.enabled?(ModuleB) == true
    end

    test "no-op when no config" do
      Application.delete_env(:hibana, :features)
      assert Features.enable(ModuleA) == :ok
    end

    test "does not duplicate in list" do
      Application.put_env(:hibana, :features, [ModuleA])
      Features.enable(ModuleA)
      features = Application.get_env(:hibana, :features)
      assert length(features) == 1
    end
  end

  describe "disable/1" do
    test "disables a module in list config" do
      Application.put_env(:hibana, :features, [ModuleA, ModuleB])
      Features.disable(ModuleA)
      assert Features.enabled?(ModuleA) == false
      assert Features.enabled?(ModuleB) == true
    end

    test "disables a module in map config" do
      Application.put_env(:hibana, :features, %{ModuleA => true})
      Features.disable(ModuleA)
      assert Features.enabled?(ModuleA) == false
    end

    test "switches to map mode when no config" do
      Application.delete_env(:hibana, :features)
      Features.disable(ModuleA)
      assert Features.enabled?(ModuleA) == false
    end
  end

  describe "list_enabled/0" do
    test "returns :all when no config" do
      Application.delete_env(:hibana, :features)
      assert Features.list_enabled() == :all
    end

    test "returns list when list config" do
      Application.put_env(:hibana, :features, [ModuleA, ModuleB])
      assert Features.list_enabled() == [ModuleA, ModuleB]
    end

    test "returns enabled modules from map config" do
      Application.put_env(:hibana, :features, %{ModuleA => true, ModuleB => false})
      enabled = Features.list_enabled()
      assert ModuleA in enabled
      refute ModuleB in enabled
    end
  end

  describe "filter_children/1" do
    test "filters children based on enabled features" do
      Application.put_env(:hibana, :features, [ModuleA])
      children = [{ModuleA, []}, {ModuleB, []}]
      assert Features.filter_children(children) == [{ModuleA, []}]
    end

    test "handles atom-only children" do
      Application.put_env(:hibana, :features, [ModuleA])
      children = [ModuleA, ModuleB]
      assert Features.filter_children(children) == [ModuleA]
    end

    test "keeps all children when no config" do
      Application.delete_env(:hibana, :features)
      children = [{ModuleA, []}, {ModuleB, []}]
      assert Features.filter_children(children) == children
    end
  end
end

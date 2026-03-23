defmodule Hibana.ValidatorTest.UserParams do
  use Hibana.Validator

  field(:name, :string, required: true, min: 2)
  field(:email, :string, required: true, format: ~r/@/)
  field(:age, :integer, min: 0, max: 150)
  field(:role, :string, one_of: ["admin", "user"], default: "user")
end

defmodule Hibana.ValidatorTest do
  use ExUnit.Case, async: true

  alias Hibana.Validator
  alias Hibana.ValidatorTest.UserParams

  describe "do_validate/2 with string fields" do
    test "validates required string" do
      fields = [{:name, :string, [required: true]}]
      assert {:ok, %{name: "Alice"}} = Validator.do_validate(%{"name" => "Alice"}, fields)
    end

    test "returns error for missing required field" do
      fields = [{:name, :string, [required: true]}]
      assert {:error, [{:name, "is required"}]} = Validator.do_validate(%{}, fields)
    end

    test "optional field returns nil/default when missing" do
      fields = [{:name, :string, []}]
      assert {:ok, %{name: nil}} = Validator.do_validate(%{}, fields)
    end

    test "default value used when field missing" do
      fields = [{:role, :string, [default: "user"]}]
      assert {:ok, %{role: "user"}} = Validator.do_validate(%{}, fields)
    end

    test "min length validation" do
      fields = [{:name, :string, [min: 3]}]
      assert {:ok, _} = Validator.do_validate(%{"name" => "Alice"}, fields)

      assert {:error, [{:name, "must be at least 3 characters"}]} =
               Validator.do_validate(%{"name" => "Al"}, fields)
    end

    test "max length validation" do
      fields = [{:name, :string, [max: 5]}]
      assert {:ok, _} = Validator.do_validate(%{"name" => "Alice"}, fields)

      assert {:error, [{:name, "must be at most 5 characters"}]} =
               Validator.do_validate(%{"name" => "Alicia"}, fields)
    end

    test "format regex validation" do
      fields = [{:email, :string, [format: ~r/@/]}]
      assert {:ok, _} = Validator.do_validate(%{"email" => "a@b.com"}, fields)

      assert {:error, [{:email, "has invalid format"}]} =
               Validator.do_validate(%{"email" => "invalid"}, fields)
    end

    test "one_of validation" do
      fields = [{:role, :string, [one_of: ["admin", "user"]]}]
      assert {:ok, %{role: "admin"}} = Validator.do_validate(%{"role" => "admin"}, fields)
      assert {:error, [{:role, msg}]} = Validator.do_validate(%{"role" => "other"}, fields)
      assert msg =~ "must be one of"
    end
  end

  describe "do_validate/2 with integer fields" do
    test "validates integer" do
      fields = [{:age, :integer, []}]
      assert {:ok, %{age: 25}} = Validator.do_validate(%{"age" => 25}, fields)
    end

    test "casts string to integer" do
      fields = [{:age, :integer, []}]
      assert {:ok, %{age: 25}} = Validator.do_validate(%{"age" => "25"}, fields)
    end

    test "returns error for invalid integer string" do
      fields = [{:age, :integer, []}]

      assert {:error, [{:age, "must be an integer"}]} =
               Validator.do_validate(%{"age" => "abc"}, fields)
    end

    test "min value validation" do
      fields = [{:age, :integer, [min: 0]}]
      assert {:ok, _} = Validator.do_validate(%{"age" => 5}, fields)

      assert {:error, [{:age, "must be at least 0"}]} =
               Validator.do_validate(%{"age" => -1}, fields)
    end

    test "max value validation" do
      fields = [{:age, :integer, [max: 150]}]
      assert {:ok, _} = Validator.do_validate(%{"age" => 100}, fields)

      assert {:error, [{:age, "must be at most 150"}]} =
               Validator.do_validate(%{"age" => 200}, fields)
    end
  end

  describe "do_validate/2 with float fields" do
    test "validates float" do
      fields = [{:price, :float, []}]
      assert {:ok, %{price: 9.99}} = Validator.do_validate(%{"price" => 9.99}, fields)
    end

    test "casts integer to float" do
      fields = [{:price, :float, []}]
      assert {:ok, %{price: price}} = Validator.do_validate(%{"price" => 10}, fields)
      assert is_float(price)
    end

    test "casts string to float" do
      fields = [{:price, :float, []}]
      assert {:ok, %{price: 9.99}} = Validator.do_validate(%{"price" => "9.99"}, fields)
    end

    test "returns error for invalid float string" do
      fields = [{:price, :float, []}]

      assert {:error, [{:price, "must be a number"}]} =
               Validator.do_validate(%{"price" => "abc"}, fields)
    end
  end

  describe "do_validate/2 with boolean fields" do
    test "validates boolean true" do
      fields = [{:active, :boolean, []}]
      assert {:ok, %{active: true}} = Validator.do_validate(%{"active" => true}, fields)
    end

    test "validates boolean false" do
      fields = [{:active, :boolean, []}]
      assert {:ok, %{active: false}} = Validator.do_validate(%{"active" => false}, fields)
    end

    test "casts string 'true' to boolean" do
      fields = [{:active, :boolean, []}]
      assert {:ok, %{active: true}} = Validator.do_validate(%{"active" => "true"}, fields)
    end

    test "casts string 'false' to boolean" do
      fields = [{:active, :boolean, []}]
      assert {:ok, %{active: false}} = Validator.do_validate(%{"active" => "false"}, fields)
    end
  end

  describe "do_validate/2 with array fields" do
    test "validates array of strings" do
      fields = [{:tags, {:array, :string}, [default: []]}]

      assert {:ok, %{tags: ["a", "b"]}} =
               Validator.do_validate(%{"tags" => ["a", "b"]}, fields)
    end

    test "uses default for missing array" do
      fields = [{:tags, {:array, :string}, [default: []]}]
      assert {:ok, %{tags: []}} = Validator.do_validate(%{}, fields)
    end

    test "validates array of integers" do
      fields = [{:ids, {:array, :integer}, []}]

      assert {:ok, %{ids: [1, 2, 3]}} =
               Validator.do_validate(%{"ids" => [1, 2, 3]}, fields)
    end
  end

  describe "do_validate/2 with atom keys" do
    test "stringifies atom keys in params" do
      fields = [{:name, :string, [required: true]}]
      assert {:ok, %{name: "Alice"}} = Validator.do_validate(%{name: "Alice"}, fields)
    end
  end

  describe "do_validate/2 with multiple errors" do
    test "collects all errors" do
      fields = [
        {:name, :string, [required: true]},
        {:email, :string, [required: true]}
      ]

      assert {:error, errors} = Validator.do_validate(%{}, fields)
      assert length(errors) == 2
      assert {:name, "is required"} in errors
      assert {:email, "is required"} in errors
    end
  end

  describe "macro-based validator module" do
    test "validate/1 succeeds with valid params" do
      assert {:ok, result} =
               UserParams.validate(%{
                 "name" => "Alice",
                 "email" => "alice@example.com",
                 "age" => 30
               })

      assert result.name == "Alice"
      assert result.email == "alice@example.com"
      assert result.age == 30
      assert result.role == "user"
    end

    test "validate/1 fails with invalid params" do
      assert {:error, errors} = UserParams.validate(%{})
      assert {:name, "is required"} in errors
      assert {:email, "is required"} in errors
    end

    test "validate!/1 raises on invalid params" do
      assert_raise ArgumentError, fn ->
        UserParams.validate!(%{})
      end
    end

    test "fields/0 returns field definitions" do
      fields = UserParams.fields()
      assert is_list(fields)
      assert length(fields) == 4
    end
  end
end

defmodule EnterpriseSuite.User do
  @moduledoc """
  Sample User model for Admin dashboard.
  """
  defstruct [:id, :email, :name, :role, :created_at]

  def all do
    [
      %__MODULE__{
        id: 1,
        email: "admin@example.com",
        name: "Admin User",
        role: "admin",
        created_at: "2024-01-15"
      },
      %__MODULE__{
        id: 2,
        email: "john@example.com",
        name: "John Doe",
        role: "user",
        created_at: "2024-02-20"
      },
      %__MODULE__{
        id: 3,
        email: "jane@example.com",
        name: "Jane Smith",
        role: "user",
        created_at: "2024-03-10"
      }
    ]
  end

  def schema do
    %{
      fields: [
        %{name: :id, type: :integer, primary_key: true},
        %{name: :email, type: :string, required: true},
        %{name: :name, type: :string},
        %{name: :role, type: :enum, values: ["admin", "user", "guest"]},
        %{name: :created_at, type: :datetime}
      ]
    }
  end
end

defmodule EnterpriseSuite.Product do
  @moduledoc """
  Sample Product model for Admin dashboard.
  """
  defstruct [:id, :name, :price, :stock, :category]

  def all do
    [
      %__MODULE__{id: 1, name: "Laptop Pro", price: 1299.99, stock: 50, category: "Electronics"},
      %__MODULE__{
        id: 2,
        name: "Wireless Mouse",
        price: 29.99,
        stock: 200,
        category: "Accessories"
      },
      %__MODULE__{id: 3, name: "USB-C Hub", price: 79.99, stock: 100, category: "Accessories"}
    ]
  end
end

defmodule EnterpriseSuite.Order do
  @moduledoc """
  Sample Order model for Admin dashboard.
  """
  defstruct [:id, :user_id, :total, :status, :items]

  def all do
    [
      %__MODULE__{id: 101, user_id: 2, total: 1329.98, status: "completed", items: 2},
      %__MODULE__{id: 102, user_id: 3, total: 109.98, status: "pending", items: 3}
    ]
  end
end

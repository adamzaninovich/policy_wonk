defmodule PolicyWonk.LoadResourceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.LoadResource
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, :thing_a, "thing_a"}
    end
    def load_resource(_conn, :thing_b, _params) do
      {:ok, :thing_b, "thing_b"}
    end
    def load_resource(_conn, :invalid, _params) do
      "invalid"
    end
    def load_resource(_conn, :bad_wolf, _params) do
      "bad_wolf"
    end
    def load_resource(_conn, %{name: name}, _params) do
      {:ok, :named_resource, name}
    end
    def load_resource(_conn, :raises, _params) do
      inspect( :something, :bad_argument )
    end


    def load_error( conn, "invalid" ) do
      conn
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt
    end
  end

  defmodule ModController do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, :thing_a, "controller_thing_a"}
    end
  end

  defmodule ModRouter do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, :thing_a, "router_thing_a"}
    end
  end

  @conn_controller %{
    private: %{
      phoenix_controller: :controller,
      phoenix_router:     :router,
      phoenix_action:     :action
    }
  }

  @conn_router %{
    private: %{
      phoenix_router:     :router,
    }
  }

  @conn_empty %{}



  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init accepts a full opts map" do
    assert LoadResource.init(%{resources: [:something_to_load], module: "module", async: true}) ==
      %{
        resources: [:something_to_load],
        module: "module",
        async: true       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of resources" do
    assert LoadResource.init(%{resources: [:something_to_load, :another_to_load]}) ==
      %{
        resources: [:something_to_load, :another_to_load],
        module: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of resources and module" do
    assert LoadResource.init(%{resources: [:something_to_load], module: "module"}) ==
      %{
        resources: [:something_to_load],
        module: "module",
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of resources and async" do
    assert LoadResource.init(%{resources: [:something_to_load], async: true}) ==
      %{
        resources: [:something_to_load],
        module: nil,
        async: true       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a loader list" do
    assert LoadResource.init([:something_to_load, :another_to_load]) ==
      %{
        resources: [:something_to_load, :another_to_load],
        module: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init converts single loader into a loader list" do
    assert LoadResource.init(:something_to_load) ==
      %{
        resources: [:something_to_load],
        module: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a complex loader name" do
    assert LoadResource.init(%{name: "test_name"}) ==
      %{
        resources: [%{name: "test_name"}],
        module: nil,
        async: false       # From config
      }
  end


  #============================================================================
  # call

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #----------------------------------------------------------------------------
  test "call loads the resource into the conn's assigns (async: false)", %{conn: conn} do
    opts = %{
        resources: [:thing_a, :thing_b],
        module: ModA,
        async: false       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call loads the resource into the conn's assigns (async: true)", %{conn: conn} do
    opts = %{
        resources: [:thing_a, :thing_b],
        module: ModA,
        async: true       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call loads complex named resources  (async: true)", %{conn: conn} do
    opts = %{
        resources: [%{name: "test_name"}],
        module: ModA, async: true
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.named_resource == "test_name"
  end

  #----------------------------------------------------------------------------
  test "call loads complex named resources  (async: false)", %{conn: conn} do
    opts = %{
        resources: [%{name: "test_name"}],
        module: ModA, async: false
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.named_resource == "test_name"
  end

  #----------------------------------------------------------------------------
  test "call uses loader on (optional) controller", %{conn: conn} do
    opts = %{
        resources: [:thing_a],
        module: nil,
        async: false       # From config
      }
    conn = Map.put(conn, :private, %{phoenix_controller: ModController})
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "controller_thing_a"
  end

  #----------------------------------------------------------------------------
  test "call uses loader on (optional) router", %{conn: conn} do
    opts = %{
        resources: [:thing_a],
        module: nil,
        async: false       # From config
      }
    conn = Map.put(conn, :private, %{phoenix_router: ModRouter})
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "router_thing_a"
  end

  #----------------------------------------------------------------------------
  test "call uses loader set by config", %{conn: conn} do
    opts = %{
        resources: [:from_config],
        module: nil,
        async: false       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.from_config == "from_config"
  end


  #----------------------------------------------------------------------------
  test "call handles load errors", %{conn: conn} do
    opts = %{
        resources: [:invalid],
        module: ModA,
        async: true       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.status == 404
  end

  #----------------------------------------------------------------------------
  test "call surfaces error raised inside load_resource", %{conn: conn} do
    opts = %{
      resources: [:raises],
      module: ModA,
      async: false         # From config
    }
    assert_raise FunctionClauseError, fn ->
      LoadResource.call(conn, opts)
    end
  end

end

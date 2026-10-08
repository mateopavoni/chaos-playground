defmodule ChaosPlaygroundWeb.PlaygroundLiveTest do
  use ChaosPlaygroundWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ChaosPlayground.Engine.{NodeServer, Presets, Topology, TrafficSimulator}

  setup :register_and_log_in_user

  setup %{user: user} do
    Topology.apply!(user.id, hd(Presets.list()))
    TrafficSimulator.pause_traffic(user.id)
    %{user_id: user.id}
  end

  test "mounts and renders the default preset topology", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Chaos Playground"
    assert html =~ "Monolith vs Microservices"
    assert html =~ "monolith-lb"
  end

  test "start/pause traffic toggles button state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "button[disabled]", "Pausar")
    refute has_element?(view, "button[disabled]", "Iniciar")

    view |> element("button", "Iniciar") |> render_click()

    assert has_element?(view, "button[disabled]", "Iniciar")
    refute has_element?(view, "button[disabled]", "Pausar")
  end

  test "reviving a node that is already alive is a no-op, not a crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert render_hook(view, "revive_node", %{"id" => "monolith-lb"}) =~ "monolith-lb"
    assert Process.alive?(view.pid)
  end

  test "events with ids that are not on the canvas are ignored", %{conn: conn, user_id: user_id} do
    {:ok, view, _html} = live(conn, "/")

    render_hook(view, "kill_node", %{"id" => "ghost"})
    render_hook(view, "connect_nodes", %{"from" => "monolith-lb", "to" => "ghost"})
    render_hook(view, "connect_nodes", %{"from" => "ghost", "to" => "monolith-lb"})

    assert Process.alive?(view.pid)
    refute "ghost" in NodeServer.get_state(user_id, "monolith-lb").connections
  end

  test "only a load balancer of the current topology can be the traffic entry", %{
    conn: conn,
    user_id: user_id
  } do
    {:ok, view, _html} = live(conn, "/")

    render_hook(view, "set_entry_node", %{"entry_node" => "monolith-app"})
    assert TrafficSimulator.get_state(user_id).entry_node == "monolith-lb"

    render_hook(view, "set_entry_node", %{"entry_node" => "micro-lb"})
    assert TrafficSimulator.get_state(user_id).entry_node == "micro-lb"
  end

  test "killing a node marks it dead and offers revive", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view |> element("[data-node-id='monolith-lb']") |> render_click()
    html = view |> element("button", "Matar proceso") |> render_click()

    assert html =~ "dead"
    assert has_element?(view, "button", "Reiniciar nodo")
  end

  test "loading a different preset swaps the canvas", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view |> element("button", "Primary/Replica DB + Load Balancer") |> render_click()
    html = render(view)

    assert html =~ "db-replica"
    # nota: no usar `refute html =~ "monolith-lb"` a secas — el script del tour guiado
    # menciona ese id como parte fija del guión, sin relación con la topología cargada.
    refute html =~ ~s(data-node-id="monolith-lb")
  end

  test "connecting nodes into a cycle is rejected", %{conn: conn, user_id: user_id} do
    {:ok, view, _html} = live(conn, "/")

    # monolith-lb -> monolith-app ya existe en el preset default; conectar en el
    # sentido inverso cerraria un ciclo de 2 nodos (TrafficSimulator.route_to_next_hop
    # recursaria para siempre sobre ese ciclo).
    html = render_hook(view, "connect_nodes", %{"from" => "monolith-app", "to" => "monolith-lb"})

    assert html =~ "cerraría un ciclo"
    refute "monolith-lb" in NodeServer.get_state(user_id, "monolith-app").connections
  end

  test "?preset= query param loads that preset directly", %{conn: conn} do
    name = "Primary/Replica DB + Load Balancer"
    {:ok, _view, html} = live(conn, "/?preset=" <> URI.encode_www_form(name))

    assert html =~ "db-replica"
  end

  describe "anonymous visitor" do
    setup do
      %{conn: Phoenix.ConnTest.build_conn()}
    end

    test "can use the canvas without logging in", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Chaos Playground"
      refute html =~ "Iniciá sesión para acceder"

      html = view |> element("button", "Iniciar") |> render_click()
      assert has_element?(view, "button[disabled]", "Iniciar")
      assert html =~ "Chaos Playground"
    end

    test "trying to save a preset redirects to login instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      {:error, {:live_redirect, %{to: "/users/log-in"}}} =
        view |> form("form[phx-submit='save_topology']", %{"name" => "x"}) |> render_submit()
    end
  end
end

defmodule ChaosPlaygroundWeb.PlaygroundLiveTest do
  # engine global (Registry/DynamicSupervisor/TrafficSimulator son singletons de la app):
  # estos tests mutan ese estado compartido, así que corren secuenciales, no async.
  use ChaosPlaygroundWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias ChaosPlayground.Engine.{Presets, Topology, TrafficSimulator}

  setup do
    Topology.apply!(hd(Presets.list()))
    TrafficSimulator.pause_traffic()
    :ok
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
    refute html =~ "monolith-lb"
  end
end

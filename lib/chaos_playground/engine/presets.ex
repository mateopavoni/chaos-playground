defmodule ChaosPlayground.Engine.Presets do
  @moduledoc "Topologías de arquitectura pre-armadas, mismo shape que `ChaosPlayground.Engine.Topology`."

  @monolith_vs_microservices %{
    name: "Monolith vs Microservices",
    entry_node: "monolith-lb",
    nodes: [
      %{id: "monolith-lb", type: :load_balancer, x: 90, y: 380},
      %{id: "monolith-app", type: :api_server, x: 260, y: 380},
      %{id: "monolith-db", type: :database, x: 430, y: 380},
      %{id: "micro-lb", type: :load_balancer, x: 620, y: 180},
      %{id: "micro-svc-a", type: :api_server, x: 780, y: 60},
      %{id: "micro-svc-b", type: :api_server, x: 780, y: 180},
      %{id: "micro-svc-c", type: :api_server, x: 780, y: 300},
      %{id: "micro-db", type: :database, x: 940, y: 180}
    ],
    connections: [
      ["monolith-lb", "monolith-app"],
      ["monolith-app", "monolith-db"],
      ["micro-lb", "micro-svc-a"],
      ["micro-lb", "micro-svc-b"],
      ["micro-lb", "micro-svc-c"],
      ["micro-svc-a", "micro-db"],
      ["micro-svc-b", "micro-db"],
      ["micro-svc-c", "micro-db"]
    ]
  }

  @primary_replica %{
    name: "Primary/Replica DB + Load Balancer",
    entry_node: "lb",
    nodes: [
      %{id: "lb", type: :load_balancer, x: 90, y: 260},
      %{id: "api-1", type: :api_server, x: 280, y: 160},
      %{id: "api-2", type: :api_server, x: 280, y: 360},
      %{id: "cache", type: :cache, x: 480, y: 260},
      %{id: "db-primary", type: :database, x: 680, y: 260},
      %{id: "db-replica", type: :database, x: 880, y: 260}
    ],
    connections: [
      ["lb", "api-1"],
      ["lb", "api-2"],
      ["api-1", "cache"],
      ["api-2", "cache"],
      ["cache", "db-primary"],
      ["db-primary", "db-replica"]
    ]
  }

  @single_point_of_failure %{
    name: "Single Point of Failure",
    entry_node: "lb",
    nodes: [
      %{id: "lb", type: :load_balancer, x: 150, y: 200},
      %{id: "api", type: :api_server, x: 450, y: 200},
      %{id: "db", type: :database, x: 750, y: 200}
    ],
    connections: [
      ["lb", "api"],
      ["api", "db"]
    ]
  }

  @event_queue_workers %{
    name: "Cola de eventos con workers",
    entry_node: "producer",
    nodes: [
      %{id: "producer", type: :load_balancer, x: 100, y: 220},
      %{id: "queue", type: :queue, x: 320, y: 220},
      %{id: "worker-1", type: :api_server, x: 560, y: 80},
      %{id: "worker-2", type: :api_server, x: 560, y: 220},
      %{id: "worker-3", type: :api_server, x: 560, y: 360},
      %{id: "db", type: :database, x: 820, y: 220}
    ],
    connections: [
      ["producer", "queue"],
      ["queue", "worker-1"],
      ["queue", "worker-2"],
      ["queue", "worker-3"],
      ["worker-1", "db"],
      ["worker-2", "db"],
      ["worker-3", "db"]
    ]
  }

  @spec list() :: [map()]
  def list,
    do: [
      @monolith_vs_microservices,
      @primary_replica,
      @single_point_of_failure,
      @event_queue_workers
    ]
end

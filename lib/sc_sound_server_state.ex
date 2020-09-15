defmodule SCSoundServer.Config do
  @moduledoc """
  A struct representing the configuration of a SCSoundServer
  """

  use TypedStruct
  @typedoc "A SCSoundServer.State"

  typedstruct do
    field(:server_name, atom(), default: :sc3_server)
    field(:ip, charlist(), default: '127.0.0.1')
    field(:udp_port, non_neg_integer(), default: 57110)
    field(:start_node_id, non_neg_integer(), default: 5000)
    field(:end_node_id, non_neg_integer(), default: 1_000_000)
    field(:client_id, non_neg_integer(), default: 10)
  end
end

defmodule SCSoundServer.State do
  @moduledoc """
  A struct representing the State of SCSoundServer
  """

  use TypedStruct

  @typedoc "A SCSoundServer.State"
  typedstruct do
    field(:config, %SCSoundServer.Config{}, enforce: true)
    field(:ready, boolean(), default: false)
    field(:default_group, nil | SCNode.Config.t(), default: nil)
    field(:exit_status, integer())
    field(:port, pid())
    field(:socket, pid())
    field(:node_ids, list, enforce: true)
    field(:next_node_id, non_neg_integer(), enforce: true)
    field(:queries, dafault: %{})
  end
end

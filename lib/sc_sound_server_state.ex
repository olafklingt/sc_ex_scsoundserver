defmodule SCSoundServer.Config do
  @moduledoc """
  A struct representing the configuration of a SCSoundServer
  """

  use TypedStruct
  @typedoc "A SCSoundServer.State"

  typedstruct do
    field(:server_name, atom(), default: :sc3_server)
    field(:start_node_id, non_neg_integer(), default: 5000)
    field(:end_node_id, non_neg_integer(), default: 1_000_000)
    field(:client_id, non_neg_integer(), default: 0)
    field(:jack_out, charlist(), default: 'system:playback_1,system:playback_2')
    field(:jack_in, charlist(), default: 'system:capture_1,system:capture_2')
    field(:application, charlist(), default: 'supernova')
    field(:protocol, atom(), default: :tcp)
    field(:port, non_neg_integer(), default: 57110)
    field(:control_busses, non_neg_integer(), default: 16384)
    field(:audio_busses, non_neg_integer(), default: 1024)
    field(:block_size, non_neg_integer(), default: 64)
    field(:hardware_buffer_size, non_neg_integer(), default: 0)
    field(:use_system_clock, non_neg_integer(), default: 0)
    field(:samplerate, non_neg_integer(), default: 44100)
    field(:buffers, non_neg_integer(), default: 1024)
    field(:max_nodes, non_neg_integer(), default: 1024)
    field(:max_synthdefs, non_neg_integer(), default: 1024)
    field(:rt_memory, non_neg_integer(), default: 8192)
    field(:wires, non_neg_integer(), default: 64)
    field(:randomseeds, non_neg_integer(), default: 64)
    field(:load_synthdefs, non_neg_integer(), default: 1)
    field(:rendezvous, non_neg_integer(), default: 0)
    field(:max_logins, non_neg_integer(), default: 64)
    field(:password, boolean(), default: false)
    field(:nrt, boolean(), default: false)
    field(:memory_locking, boolean(), default: false)
    field(:version, boolean(), default: false)
    field(:hardware_device_name, boolean(), default: false)
    field(:verbose, non_neg_integer(), default: 0)
    field(:ugen_search_path, boolean(), default: false)
    field(:restricted_path, boolean(), default: false)
    field(:threads, non_neg_integer(), default: 4)
    field(:socket_address, charlist(), default: '127.0.0.1')
    field(:inchannels, non_neg_integer(), default: 8)
    field(:outchannels, non_neg_integer(), default: 8)
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
    field(:exit_status, integer())
    field(:port, pid())
    field(:socket, pid())
    field(:queries, dafault: %{})
    field(:one_shot_osc_queries, dafault: %{})
  end
end

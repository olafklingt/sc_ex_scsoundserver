defmodule SCSoundServer do
  @moduledoc """
  Interface to SCSoundServers.
  """

  @default_server_name :sc3_server

  @spec await_server_startup(atom, non_neg_integer) :: atom
  defp await_server_startup(server_name, sec) do
    times = sec * 10

    stream =
      Stream.unfold(times, fn x ->
        if SCSoundServer.ready?(server_name) != true && x != 0 do
          :timer.sleep(100)
          {:ok, x - 1}
        else
          nil
        end
      end)

    Stream.run(stream)
    SCSoundServer.ready?(server_name)
  end

  @default_init %SCSoundServer.Config{}

  def start_link(config \\ @default_init) do
    IO.puts("start_link(config: #{inspect(config.server_name)}")

    s =
      GenServer.start_link(
        SCSoundServer.GenServer,
        config,
        name: config.server_name
      )

    t = await_server_startup(config.server_name, 5)

    if t do
      SCSoundServer.notify_sync(true, config.client_id, config.server_name)
      s
    else
      q = SCSoundServer.quit(config.server_name)
      q
    end
  end

  def add_def(name, ugen) do
    def = SCSynthDef.new(name, ugen)
    bytes = SCSynthDef.encode_to_bytes(def)
    :ok = SCSoundServer.send_synthdef_sync(bytes)
    def
  end

  @spec get_next_node_id(atom) :: integer()
  def get_next_node_id(server_name \\ @default_server_name) do
    GenServer.call(server_name, :get_next_node_id)
  end

  @spec ready?(atom) :: boolean
  def ready?(server_name \\ @default_server_name) do
    GenServer.call(server_name, :is_ready)
  end

  @spec reset(atom) :: any()
  def reset(server_name \\ @default_server_name) do
    GenServer.cast(server_name, :reset)
  end

  @spec quit(atom) :: any()
  def quit(server_name \\ @default_server_name) do
    GenServer.cast(server_name, :quit)
  end

  @spec dumpTree(atom) :: any()
  def dumpTree(server_name \\ @default_server_name) do
    GenServer.cast(server_name, :dump_tree)
  end

  # @spec new_group_sync(non_neg_integer, non_neg_integer, non_neg_integer, atom) :: any()
  # def new_group_sync(
  #       node_id,
  #       add_action_id \\ 0,
  #       target_node_id \\ 0,
  #       server_name \\ @default_server_name
  #     ) do
  #   SCSoundServer.send_msg_sync(
  #     ["g_new", nid, add_action_id, target_node_id],
  #     :group_started,
  #     config.server_name
  #   )
  # end

  @spec get(non_neg_integer, String.t(), atom) :: any
  def get(synth_id, control_name, server_name \\ @default_server_name) do
    GenServer.call(server_name, {:s_get, synth_id, control_name})
  end

  @spec set(non_neg_integer, list, atom) :: any
  def set(synth_id, args_array, server_name \\ @default_server_name) do
    GenServer.cast(server_name, {:set, synth_id, args_array})
  end

  @spec start_synth_sync(non_neg_integer, non_neg_integer, atom) :: any()
  def start_synth_sync(
        def_name,
        args,
        add_action_id \\ 0,
        target_node_id \\ 0,
        server_name \\ @default_server_name
      ) do
    GenServer.call(
      server_name,
      {:start_synth_sync, {def_name, args, add_action_id, target_node_id}}
    )
  end

  @spec start_synth_async(charlist, list, non_neg_integer, non_neg_integer, non_neg_integer, atom) ::
          any()
  def start_synth_async(
        def_name,
        args,
        node_id,
        add_action_id \\ 0,
        target_node_id \\ 0,
        server_name \\ @default_server_name
      ) do
    GenServer.cast(
      server_name,
      {:start_synth_async, {def_name, args, node_id, add_action_id, target_node_id}}
    )
  end

  @spec new_group_sync(non_neg_integer, non_neg_integer, atom) :: any()
  def new_group_sync(
        add_action_id \\ 0,
        target_node_id \\ 0,
        server_name \\ @default_server_name
      ) do
    GenServer.call(
      server_name,
      {:new_group_sync, {add_action_id, target_node_id}}
    )
  end

  @spec new_group_async(non_neg_integer, non_neg_integer, non_neg_integer, atom) :: any()
  def new_group_async(
        node_id,
        add_action_id \\ 0,
        target_node_id \\ 0,
        server_name \\ @default_server_name
      ) do
    GenServer.call(
      server_name,
      {:new_group_async, {node_id, add_action_id, target_node_id}}
    )
  end

  @spec send_synthdef(binary, atom) :: any()
  def send_synthdef(defbinary, server_name \\ @default_server_name) do
    send_msg_async(["/d_recv", defbinary], server_name)
  end

  @spec notify_async(boolean, integer, atom) :: any()
  def notify_async(flag, client_id, server_name \\ @default_server_name) do
    SCSoundServer.send_msg_async(
      ["notify", (flag && 1) || 0, client_id],
      server_name: server_name
    )
  end

  @spec notify_sync(boolean, integer, atom) :: any()
  def notify_sync(flag, client_id, server_name \\ @default_server_name) do
    send_msg_sync(
      ["notify", (flag && 1) || 0, client_id],
      :notify_set,
      server_name
    )
  end

  @spec send_synthdef_sync(binary, atom) :: any()
  def send_synthdef_sync(defbinary, server_name \\ @default_server_name) do
    send_msg_sync(
      ["/d_recv", defbinary],
      :send_synthdef_done,
      server_name
    )
  end

  @spec encode(list) :: iodata
  def encode([path | args]) do
    {:ok, data} =
      OSC.encode(%OSC.Message{
        address: path,
        arguments: args
      })

    data
  end

  # todo get rid of this detour
  @spec send_msg_async(iodata, atom) :: any()
  def send_msg_async(msg, server_name \\ @default_server_name) do
    GenServer.cast(server_name, {:osc_message, encode(msg)})
  end

  # @spec send_msg_async(iodata, map(), atom) :: any()
  # def send_msg_async(msg, callback = %{id: _id, func: _func}, server_name)
  #     when is_atom(server_name) do
  #     GenServer.cast(server_name, {:osc_message, msg, callback})
  # end

  @spec send_msg_sync(iodata, atom | {atom, integer}, atom) :: any()
  def send_msg_sync(msg, id, server_name \\ @default_server_name) do
    GenServer.call(server_name, {:osc_message, encode(msg), id})
  end
end

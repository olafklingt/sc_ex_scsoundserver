defmodule SCSoundServer.GenServer do
  use GenServer
  import SCSoundServer, only: [encode: 1]

  defp get_next_node_id(state) do
    [n | tail] = state.node_ids

    if n > state.config.end_node_id do
      IO.puts(
        "Next node ID is out of range #{n}. It should be smaller than #{state.config.end_node_id} which is end_node_id as specified in SCSoundServer.start_link."
      )
    end

    %SCSoundServer.State{} = state
    {%{state | node_ids: tail}, n}
  end

  @spec await_server_startup(atom, non_neg_integer) :: atom
  defp await_server_startup(server_name, sec) do
    times = sec * 10

    stream =
      Stream.unfold(times, fn x ->
        if IO.inspect(SCSoundServer.ready?(server_name)) != true && x != 0 do
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
    # IO.puts("scssgs start_link: #{inspect(config)}")

    s =
      GenServer.start_link(
        __MODULE__,
        config,
        name: config.server_name
      )

    # IO.puts("scssgs s: #{inspect(s)}")
    t = await_server_startup(config.server_name, 5)

    if t do
      SCSoundServer.notify_sync(true, config.client_id, config.server_name)

      # IO.puts("end SoundServer.GenServer start_link")

      s
    else
      q = SCSoundServer.quit(config.server_name)
      # IO.puts("end SoundServer.GenServer start_link but quit")
      q
    end
  end

  @impl true
  def init(
        config = %SCSoundServer.Config{
          server_name: _server_name,
          # registry_name: registry_name,
          ip: _ip,
          udp_port: udp_port,
          start_node_id: start_node_id,
          end_node_id: end_node_id,
          client_id: _client_id
        }
      ) do
    path = Path.dirname(__ENV__.file)

    port =
      Port.open(
        {:spawn_executable, System.find_executable("#{path}/wrapper.sh")},
        [
          :binary,
          :exit_status,
          {:env,
           [
             {'SC_JACK_DEFAULT_OUTPUTS', 'system:playback_1,system:playback_2'},
             {'SC_JACK_DEFAULT_INPUTS', 'system:capture_1,system:capture_2'}
           ]},
          args: [
            "scsynth",
            "-u",
            to_string("#{udp_port}"),
            "-a",
            "1024",
            "-i",
            "2",
            "-o",
            "2",
            "-R",
            "0",
            "-l",
            "3",
            "-m",
            "32768"
          ]
        ]
      )

    {:ok, socket} = :gen_udp.open(0, [:binary, {:active, true}])

    # return =
    #   Registry.start_link(
    #     keys: :unique,
    #     name: registry_name
    #   )
    #
    # {:ok, _reg} = return

    {:ok,
     %SCSoundServer.State{
       config: config,
       ready: false,
       exit_status: nil,
       port: port,
       socket: socket,
       node_ids: Enum.to_list(start_node_id..end_node_id),
       next_node_id: start_node_id,
       queries: %{}
     }}
  end

  @spec add_to_msg_query(map, atom, any) :: map
  def add_to_msg_query(state, id, from) do
    queries = state.queries
    queries = Map.put(queries, id, from)
    Map.put(state, :queries, queries)
  end

  @impl true
  def handle_call(:is_ready, _from, state) do
    %SCSoundServer.State{} = state
    {:reply, state.ready, state}
  end

  # @impl true
  # def handle_call(:get_default_group, _from, state) do
  #
  #   if(state.default_group == nil) do
  #     {:reply, nid, state} = get_next_node_id(state)
  #
  #     t = %SCTarget{
  #       server_name: state.config.server_name,
  #       registry_name: state.config.registry_name,
  #       node_id: nid,
  #       add_action_id: 0,
  #       target_node_id: 0
  #     }
  #
  #     r = SCGroup.start_link(t, :async)
  #     {:ok, _dg} = r
  #
  #     default_group = %SCNode.Config{
  #       server_name: state.config.server_name,
  #       registry_name: state.config.registry_name,
  #       node_id: t.node_id
  #     }
  #
  #
  #     %SCSoundServer.State{} = state
  #
  #     IO.inspect({:reply, default_group, %{state | default_group: default_group}})
  #   else
  #     %SCSoundServer.State{} = state
  #
  #     {:reply, state.default_group, state}
  #   end
  # end

  @impl true
  def handle_call(:get_next_node_id, _from, state) do
    {state, nid} = get_next_node_id(state)
    {:reply, nid, state}
  end

  @impl true
  def handle_call(
        {:start_synth_sync, {def_name, args, add_action_id, target_node_id}},
        from,
        state
      ) do
    {state, nid} = get_next_node_id(state)
    data = encode(["s_new", def_name, nid, add_action_id, target_node_id] ++ args)

    state = add_to_msg_query(state, {:synth_started, nid}, from)
    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    {:noreply, state}
  end

  @impl true
  def handle_call({:new_group_sync, {add_action_id, target_node_id}}, from, state) do
    {state, nid} = get_next_node_id(state)
    data = encode(["g_new", nid, add_action_id, target_node_id])

    state = add_to_msg_query(state, :group_started, from)
    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    {:noreply, state}
  end

  # because I serialize OSC Messages before I send them,
  # handle_casts only get binaries
  # thats why i also implemented it this way for handle_call
  # because of this i need to add a explicit id parameter
  # the id is what is used by the explicitly implemented
  # handle_cast(...) to identify the query to be released ...
  @impl true
  def handle_call({:osc_message, data, id}, from, state) do
    state = add_to_msg_query(state, id, from)
    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    %SCSoundServer.State{} = state
    {:noreply, state}
  end

  @doc "handle async set on the server"
  @impl true
  def handle_cast({:set, synth_id, args_array}, state) do
    :ok =
      :gen_udp.send(
        state.socket,
        state.config.ip,
        state.config.udp_port,
        SCSoundServer.encode(["n_set", synth_id] ++ args_array)
      )

    {:noreply, state}
  end

  def handle_cast({:new_group_async, {node_id, add_action_id, target_node_id}}, from, state) do
    data = encode(["g_new", node_id, add_action_id, target_node_id])

    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    {:noreply, state}
  end

  def handle_cast(
        {:start_synth_async, {def_name, args, node_id, add_action_id, target_node_id}},
        state
      ) do
    data = encode(["s_new", def_name, node_id, add_action_id, target_node_id] ++ args)

    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:osc_message, data}, state) do
    :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
    %SCSoundServer.State{} = state
    {:noreply, state}
  end

  # @impl true
  # def handle_cast({:osc_message, data, _callback = %{id: id, func: func}}, state) do
  #   state = add_to_msg_query(state, id, func)
  #   :ok = :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, data)
  #   %SCSoundServer.State{} = state
  #   {:noreply, state}
  # end

  @impl true
  def handle_cast(:reset, state) do
    socket = state.socket
    ip = state.config.ip
    udp_port = state.config.udp_port

    :gen_udp.send(socket, ip, udp_port, encode(["g_freeAll", 0]))
    :gen_udp.send(socket, ip, udp_port, encode(["clearSched", []]))

    # :gen_udp.send(socket, ip, udp_port, encode(["g_new", [1, 0, 0]]))

    %SCSoundServer.State{} = state
    {:noreply, %{state | next_node_id: state.config.start_node_id}}
  end

  @impl true
  def handle_cast(:dump_tree, state) do
    socket = state.socket
    ip = state.config.ip
    udp_port = state.config.udp_port

    :gen_udp.send(
      state.socket,
      state.config.ip,
      state.config.udp_port,
      encode(["g_dumpTree", 0, 1])
    )

    %SCSoundServer.State{} = state
    {:noreply, state}
  end

  @impl true
  def handle_cast(:quit, state) do
    :gen_udp.send(state.socket, state.config.ip, state.config.udp_port, encode(["quit"]))
    :gen_udp.close(state.socket)

    # matcher = [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}]
    #
    # IO.puts("matcher:")
    # IO.inspect(matcher)
    #
    # nodes = Registry.select(state.config.registry_name, matcher)

    # for {id, pid} <- nodes do
    #   IO.puts("exit: #{inspect(id)} #{inspect(pid)}")
    #   a = Process.exit(pid, :ok)
    #   IO.puts("exit return: #{inspect(a)}")
    # end

    %SCSoundServer.State{} = state
    {:stop, :normal, nil}
  end

  @impl true
  def handle_cast({:server_response, :synth_started, arguments}, %{queries: queries} = state) do
    [node_id | _] = arguments
    {from, queries} = Map.pop(queries, {:synth_started, node_id})

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        IO.puts("no response registered for synth_started: #{inspect(arguments)}")

      true ->
        GenServer.reply(from, node_id)
    end

    %SCSoundServer.State{} = state
    {:noreply, %{state | queries: queries}}
  end

  @impl true
  def handle_cast({:server_response, :group_started, arguments}, state) do
    [node_id | _] = arguments
    {from, queries} = Map.pop(state.queries, :group_started)

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        IO.puts("no response registered for group_started: #{inspect(arguments)}")

      # instead of pid i could make use of node_id in the response
      # is_pid(from) ->
      #   GenServer.cast(from, {:server_response, :synth_started})

      true ->
        GenServer.reply(from, node_id)
    end

    %SCSoundServer.State{} = state
    {:noreply, %{state | queries: queries}}
  end

  @impl true
  def handle_cast({:server_response, id, response}, %{queries: queries} = state) do
    {from, queries} = Map.pop(queries, id)

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        IO.puts("no response registered:  #{inspect(id)}, #{inspect(response)}")

      # instead of pid i could make use of node_id in the response
      # is_pid(from) ->
      #   GenServer.cast(from, {:server_response, :synth_started})

      true ->
        GenServer.reply(from, :ok)
    end

    %SCSoundServer.State{} = state
    {:noreply, %{state | queries: queries}}
  end

  # This callback tells us when the process exits
  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    IO.puts("SCSoundServer exit status: #{status}")
    :gen_udp.close(state.socket)
    %SCSoundServer.State{} = state
    {:stop, :normal, nil}
  end

  @impl true
  def handle_info({_port, {:data, text_line}}, state) do
    latest_output = text_line |> String.trim()

    IO.puts(
      "\n==============SC-SoundServer=======\n#{latest_output}\n==================================="
    )

    if latest_output =~ "SuperCollider 3 server ready" do
      %SCSoundServer.State{} = state
      {:noreply, %{state | ready: true}}
    else
      %SCSoundServer.State{} = state
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:udp, _port, _ip, _uport, msg}, state) do
    state =
      try do
        {:ok, p} = OSC.decode(msg)
        Enum.reduce(p.contents, state, fn x, state -> handle_osc(x, state) end)
      rescue
        FunctionClauseError ->
          IO.puts(
            "Incoming OSC message is not parseable maybe because initial \"/\" is missing: #{
              to_string(msg)
            }"
          )

          state
      end

    %SCSoundServer.State{} = state
    {:noreply, state}
  end

  @spec handle_osc(%OSC.Message{}, %SCSoundServer.State{}) :: {atom, %SCSoundServer.State{}}
  def handle_osc(%OSC.Message{address: "/fail", arguments: ["/notify", string, _id]}, state) do
    GenServer.cast(self(), {:server_response, :notify_set, {:error, string}})
    %SCSoundServer.State{} = state
    state
  end

  def handle_osc(%OSC.Message{address: "/done", arguments: ["/notify", _flag, id]}, state) do
    state = %{state | config: %{state.config | client_id: id}}
    GenServer.cast(self(), {:server_response, :notify_set, :ok})
    %SCSoundServer.State{} = state
    state
  end

  def handle_osc(%OSC.Message{address: "/done", arguments: ["/d_recv"]}, state) do
    GenServer.cast(self(), {:server_response, :send_synthdef_done, :ok})
    %SCSoundServer.State{} = state
    state
  end

  def handle_osc(%OSC.Message{address: "/fail", arguments: arguments}, state) do
    IO.puts("error in udp: #{inspect(arguments)}")
    %SCSoundServer.State{} = state
    state
  end

  # log creation of new synth
  def handle_osc(
        %OSC.Message{
          address: "/n_go",
          arguments:
            arguments = [
              _node,
              _parent_node,
              _previous_node,
              _next_node,
              # if synth 0
              0
            ]
        },
        state
      ) do
    GenServer.cast(self(), {:server_response, :synth_started, arguments})

    %SCSoundServer.State{} = state
    state
  end

  # log creation of new group
  def handle_osc(
        %OSC.Message{
          address: "/n_go",
          arguments:
            arguments = [
              _node,
              _parent_node,
              _previous_node,
              _next_node,
              # if group id is 1
              1,
              _head_node,
              _tail_node
            ]
        },
        state
      ) do
    # IO.puts("n_go: #{inspect(arguments)}")
    GenServer.cast(self(), {:server_response, :group_started, arguments})

    %SCSoundServer.State{} = state
    state
  end

  def handle_osc(%OSC.Message{address: "/done", arguments: arguments}, state) do
    IO.puts("done: #{inspect(arguments)}")
    %SCSoundServer.State{} = state
    state
  end

  def handle_osc(%OSC.Message{address: "/n_end", arguments: arguments}, state) do
    [nid | _] = arguments
    nnids = [nid | state.node_ids]
    %{state | node_ids: nnids}
  end

  def handle_osc(message, state) do
    IO.puts("uncatched osc message:")
    IO.puts("#{inspect(message)}")
    %SCSoundServer.State{} = state
    state
  end

  @impl true
  def terminate(_reason, _state) do
    IO.puts("soundserver terminate wait 1 sec before restart")
    # IO.puts("soundserver terminate #{inspect(state)}")
    :timer.sleep(1000)
  end
end

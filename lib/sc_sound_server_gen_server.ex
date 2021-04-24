defmodule SCSoundServer.GenServer do
  use GenServer

  defp sc_send(state = %SCSoundServer.State{}, data) do
    :ok =
      case state.config.protocol do
        :udp ->
          :gen_udp.send(state.socket, 'localhost', state.config.port, data)

        :tcp ->
          :gen_tcp.send(state.socket, data)
      end
  end

  defp args_array(config) do
    List.flatten([
      [List.to_string(config.application)],
      [
        case config.protocol do
          :tcp -> "-t"
          :udp -> "-u"
          _ -> "-t"
        end,
        "#{config.port}"
      ],
      # "--control-busses",
      "-c",
      "#{config.control_busses}",
      # "--audio-busses",
      ["-a", "#{config.audio_busses}"],
      # "--block-size",
      ["-z", "#{config.block_size}"],
      # "--hardware-buffer-size",
      ["-Z", "#{config.hardware_buffer_size}"],
      # "--use-system-clock",
      if(List.to_string(config.application) =~ "supernova",
        do: ["-C", "#{config.use_system_clock}"],
        else: []
      ),
      # "--samplerate",
      ["-S", "#{config.samplerate}"],
      # "--buffers",
      ["-b", "#{config.buffers}"],
      # "--max-nodes",
      ["-n", "#{config.max_nodes}"],
      # "--max-synthdefs",
      ["-d", "#{config.max_synthdefs}"],
      # "--rt-memory",
      ["-m", "#{config.rt_memory}"],
      # "--wires",
      ["-w", "#{config.wires}"],
      # "--randomseeds",
      ["-r", "#{config.randomseeds}"],
      # "--load-synthdefs",
      ["-D", "#{config.load_synthdefs}"],
      # "--rendezvous",
      ["-R", "#{config.rendezvous}"],
      # "--max-logins",
      ["-l", "#{config.max_logins}"],
      # if(config.password, do: "--password", else: ""),
      if(config.password, do: ["-p", "#{config.password}"], else: []),
      # if(config.nrt, do: "--nrt", else: ""),
      if(config.nrt, do: ["-N", "#{config.nrt}"], else: []),
      if(config.memory_locking && List.to_string(config.application) =~ "supernova",
        do: ["--memory-locking"],
        else: []
      ),
      # if(config.hardware_device_name, do: "--hardware-device-name", else: ""),
      if(config.hardware_device_name, do: ["-H", "#{config.hardware_device_name}"], else: []),
      # "--verbose",
      ["-V", "#{config.verbose}"],
      # if(config.ugen_search_path, do: "--ugen-search-path", else: ""),
      if(config.ugen_search_path, do: ["-U", "#{config.ugen_search_path}"], else: []),
      # if(config.restricted_path, do: "--restricted-path", else: ""),
      if(config.restricted_path, do: ["-P", "#{config.restricted_path}"], else: []),
      if(config.threads && List.to_string(config.application) =~ "supernova",
        do: ["--threads"],
        else: []
      ),
      if(config.threads && List.to_string(config.application) =~ "supernova",
        do: ["#{config.threads}"],
        else: []
      ),
      # "--socket-address",
      ["-B", "#{config.socket_address}"],
      # "--inchannels",
      ["-i", "#{config.inchannels}"],
      # "--outchannels",
      ["-o", "#{config.outchannels}"]
    ])
  end

  defp open_app_port(path, config) do
    Port.open(
      {:spawn_executable, System.find_executable("#{path}/wrapper.sh")},
      [
        :binary,
        :exit_status,
        {:env,
         [
           {'SC_JACK_DEFAULT_OUTPUTS', config.jack_out},
           {'SC_JACK_DEFAULT_INPUTS', config.jack_in}
         ]},
        args: args_array(config)
      ]
    )
  end

  @impl true
  def init(
        config = %SCSoundServer.Config{
          protocol: protocol,
          port: netport
        }
      ) do
    path = Path.dirname(__ENV__.file)

    export = open_app_port(path, config)

    :timer.sleep(2000)

    {:ok, socket} =
      case protocol do
        :udp ->
          :gen_udp.open(0, [:binary, {:active, true}])

        :tcp ->
          :gen_tcp.connect('localhost', netport, [:binary, active: true, packet: 4])
      end

    state = %SCSoundServer.State{
      config: config,
      ready: false,
      exit_status: nil,
      port: export,
      socket: socket,
      queries: %{},
      one_shot_osc_queries: %{}
    }

    {:ok, state}
  end

  @spec add_to_msg_query(map, atom | {atom, any}, any) :: map
  def add_to_msg_query(state, id, from) do
    queries = state.queries
    queries = Map.put(queries, id, from)
    Map.put(state, :queries, queries)
  end

  @impl true
  def handle_call(:is_ready, _from, state = %SCSoundServer.State{}) do
    {:reply, state.ready, state}
  end

  @impl true
  def handle_call(
        {:start_synth_sync, {def_name, args, add_action_id, target_node_id}},
        from,
        state = %SCSoundServer.State{}
      ) do
    nid = SCSoundServer.get_next_node_id()

    {:ok, bin} =
      OSC.encode(
        SCSoundServer.Message.new_synth(def_name, nid, add_action_id, target_node_id, args)
      )

    state = add_to_msg_query(state, {:synth_started, nid}, from)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:new_group_sync, {add_action_id, target_node_id}},
        from,
        state = %SCSoundServer.State{}
      ) do
    nid = SCSoundServer.get_next_node_id()

    {:ok, bin} = OSC.encode(SCSoundServer.Message.new_group(nid, add_action_id, target_node_id))

    state = add_to_msg_query(state, :group_started, from)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:new_parallel_group_sync, {add_action_id, target_node_id}},
        from,
        state = %SCSoundServer.State{}
      ) do
    nid = SCSoundServer.get_next_node_id()

    {:ok, bin} =
      OSC.encode(SCSoundServer.Message.new_parallel_group(nid, add_action_id, target_node_id))

    state = add_to_msg_query(state, :group_started, from)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_call({:g_queryTree, node_id}, from, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.query_tree(node_id))
    state = add_to_msg_query(state, :g_queryTree_reply, from)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_call({:s_get, synth_id, control_name}, from, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.get(synth_id, control_name))

    state = add_to_msg_query(state, :n_set, from)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  # i don't use :osc_message anymore now I construct the messages in dedicated message functions
  # primarily because i want to be able to create bundles

  # currently i don't use this:
  # @impl true
  # def handle_call({:osc_message, bin, id}, from, state = %SCSoundServer.State{}) do
  #   state = add_to_msg_query(state, id, from)
  #   :ok = sc_send(state, bin)
  #
  #   {:noreply, state}
  # end

  @impl true
  def handle_call({:notify_sync, flag, cid}, from, state = %SCSoundServer.State{}) do
    state = add_to_msg_query(state, :notify_sync, from)

    {:ok, bin} = OSC.encode(SCSoundServer.Message.notify(flag, cid))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_call({:send_synthdef_sync, defbinary}, from, state = %SCSoundServer.State{}) do
    state = add_to_msg_query(state, :send_synthdef_sync, from)

    {:ok, bin} = OSC.encode(SCSoundServer.Message.send_def(defbinary))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_call({:load_synthdef_sync, path}, from, state = %SCSoundServer.State{}) do
    state = add_to_msg_query(state, :load_synthdef_sync, from)

    {:ok, bin} = OSC.encode(SCSoundServer.Message.load_def(path))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  # handle async calls to the server

  @impl true
  def handle_cast({:load_synthdef_async, path}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.load_def(path))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_synthdef_async, defbinary}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.send_def(defbinary))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_bundle_async, bundle}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(bundle)
    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:notify_async, flag, cid}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.notify(flag, cid))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  # i don't use :osc_message anymore now I construct the messages in dedicated message functions
  # primarily because i want to be able to create bundles

  # currently i don't use this:
  @impl true
  def handle_cast({:osc_message, bin}, state = %SCSoundServer.State{}) do
    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_one_shot_osc_queries, message}, state = %SCSoundServer.State{}) do
    {_fun, queries} = Map.pop(state.one_shot_osc_queries, message)
    state = %{state | one_shot_osc_queries: queries}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_one_shot_osc_queries, id, fun}, state = %SCSoundServer.State{}) do
    queries = state.one_shot_osc_queries
    queries = Map.put(queries, id, fun)
    state = %{state | one_shot_osc_queries: queries}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:replace_one_shot_osc_queries, id, fun}, state = %SCSoundServer.State{}) do
    queries = state.one_shot_osc_queries
    queries = Map.put(queries, id, fun)
    state = %{state | one_shot_osc_queries: queries}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set, node_id, args}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.set(node_id, args))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:free, node_id}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.free(node_id))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:run, node_id, flag}, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.run(node_id, if(flag, do: 1, else: 0)))

    :ok = sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:new_group_async, {node_id, add_action_id, target_node_id}},
        state = %SCSoundServer.State{}
      ) do
    {:ok, bin} =
      OSC.encode(SCSoundServer.Message.new_group(node_id, add_action_id, target_node_id))

    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:start_synth_async, {def_name, args, node_id, add_action_id, target_node_id}},
        state
      ) do
    {:ok, bin} =
      OSC.encode(
        SCSoundServer.Message.new_synth(
          def_name,
          node_id,
          add_action_id,
          target_node_id,
          args
        )
      )

    :ok = sc_send(state, bin)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:reset, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.free_all(0))
    sc_send(state, bin)
    {:ok, bin} = OSC.encode(SCSoundServer.Message.clear_sched())
    sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:dump_tree, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.dump_tree(0))

    sc_send(state, bin)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:quit, state = %SCSoundServer.State{}) do
    {:ok, bin} = OSC.encode(SCSoundServer.Message.quit())
    sc_send(state, bin)
    :gen_tcp.close(state.socket)

    {:stop, :normal, nil}
  end

  @impl true
  def handle_cast(
        {:server_response, :synth_started, arguments},
        state = %SCSoundServer.State{queries: queries}
      ) do
    [node_id | _] = arguments
    {from, queries} = Map.pop(queries, {:synth_started, node_id})

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        nil

      true ->
        GenServer.reply(from, node_id)
    end

    {:noreply, %{state | queries: queries}}
  end

  @impl true
  def handle_cast({:server_response, :group_started, arguments}, state = %SCSoundServer.State{}) do
    [node_id | _] = arguments
    {from, queries} = Map.pop(state.queries, :group_started)

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        nil

      true ->
        GenServer.reply(from, node_id)
    end

    {:noreply, %{state | queries: queries}}
  end

  @impl true
  def handle_cast(
        {:server_response, id, response},
        state = %SCSoundServer.State{queries: queries}
      ) do
    {from, queries} = Map.pop(queries, id)

    cond do
      is_function(from) ->
        from.()

      nil == from ->
        IO.puts("no response registered:  #{inspect(id)}, #{inspect(response)}")

      true ->
        GenServer.reply(from, :ok)
    end

    {:noreply, %{state | queries: queries}}
  end

  # This callback tells us when the process exits
  @impl true
  def handle_info({_port, {:exit_status, status}}, state = %SCSoundServer.State{}) do
    IO.puts("SCSoundServer exit status: #{status}")

    :gen_tcp.close(state.socket)

    {:stop, :normal, nil}
  end

  @impl true
  def handle_info({_port, {:data, text_line}}, state = %SCSoundServer.State{}) do
    latest_output = text_line |> String.trim()

    IO.puts(
      "\n==============SC-SoundServer=======\n#{latest_output}\n==================================="
    )

    startup_string =
      cond do
        List.to_string(state.config.application) =~ "supernova" -> "Supernova ready"
        List.to_string(state.config.application) =~ "scsynth" -> "SuperCollider 3 server ready"
      end

    if latest_output =~ startup_string do
      {:noreply, %{state | ready: true}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, _state = %SCSoundServer.State{}) do
    raise "why tcp close???"
  end

  def handle_info({:tcp, _socket, msg}, state = %SCSoundServer.State{}) do
    state =
      try do
        {:ok, p} = OSC.decode(msg)
        Enum.reduce(p.contents, state, fn x, state -> handle_osc(x, state) end)
      rescue
        FunctionClauseError ->
          IO.puts(
            "Incoming OSC message is not parseable maybe because initial \"/\" is missing: #{
              inspect(msg)
            }"
          )

          state
      end

    {:noreply, state}
  end

  def handle_info({:udp, _socket, _host, _port, msg}, state = %SCSoundServer.State{}) do
    state =
      try do
        {:ok, p} = OSC.decode(msg)
        Enum.reduce(p.contents, state, fn x, state -> handle_osc(x, state) end)
      rescue
        FunctionClauseError ->
          IO.puts(
            "Incoming OSC message is not parseable maybe because initial \"/\" is missing: #{
              inspect(msg)
            }"
          )

          state
      end

    {:noreply, state}
  end

  @spec handle_osc(%OSC.Message{}, %SCSoundServer.State{}) :: %SCSoundServer.State{}
  def handle_osc(
        %OSC.Message{address: "/fail", arguments: ["/notify", string, _id]},
        state = %SCSoundServer.State{}
      ) do
    GenServer.cast(self(), {:server_response, :notify_sync, {:error, string}})
    state
  end

  def handle_osc(
        %OSC.Message{address: "/done", arguments: ["/notify", _flag, id]},
        state = %SCSoundServer.State{}
      ) do
    state = %{state | config: %{state.config | client_id: id}}

    GenServer.cast(self(), {:server_response, :notify_sync, :ok})
    state
  end

  def handle_osc(
        %OSC.Message{address: "/done", arguments: ["/notify", id]},
        state = %SCSoundServer.State{}
      ) do
    state = %{state | config: %{state.config | client_id: id}}
    GenServer.cast(self(), {:server_response, :notify_sync, :ok})
    state
  end

  def handle_osc(
        %OSC.Message{address: "/done", arguments: ["/d_recv"]},
        state = %SCSoundServer.State{}
      ) do
    GenServer.cast(self(), {:server_response, :send_synthdef_sync, :ok})
    state
  end

  def handle_osc(
        %OSC.Message{address: "/done", arguments: ["/d_load"]},
        state = %SCSoundServer.State{}
      ) do
    GenServer.cast(self(), {:server_response, :load_synthdef_sync, :ok})
    state
  end

  def handle_osc(
        %OSC.Message{address: "/fail", arguments: arguments},
        state = %SCSoundServer.State{}
      ) do
    IO.puts("error in udp: #{inspect(arguments)}")
    state
  end

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

    state
  end

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
    GenServer.cast(self(), {:server_response, :group_started, arguments})

    state
  end

  def handle_osc(
        %OSC.Message{address: "/done", arguments: arguments},
        state = %SCSoundServer.State{}
      ) do
    IO.puts("done: #{inspect(arguments)}")

    state
  end

  def handle_osc(
        %OSC.Message{address: "/n_end", arguments: arguments},
        state = %SCSoundServer.State{}
      ) do
    [nid | _] = arguments
    SCSoundServer.NodeIdAllocator.push_node_id(nid)
    state
  end

  def handle_osc(
        %OSC.Message{address: "/n_set", arguments: [_sid, _parameter, value]},
        state = %SCSoundServer.State{}
      ) do
    {from, queries} = Map.pop(state.queries, :n_set)
    GenServer.reply(from, value)
    %{state | queries: queries}
  end

  def handle_osc(
        %OSC.Message{address: "/g_queryTree.reply", arguments: arguments},
        state = %SCSoundServer.State{}
      ) do
    {from, queries} = Map.pop(state.queries, :g_queryTree_reply)
    GenServer.reply(from, SCSoundServer.Info.Group.map_preply(arguments))
    %{state | queries: queries}
  end

  def handle_osc(
        message = %OSC.Message{address: _, arguments: _},
        state = %SCSoundServer.State{}
      ) do
    {from, queries} = Map.pop(state.one_shot_osc_queries, message)

    if is_nil(from) do
      IO.puts("uncatched osc message:")
      IO.puts("#{inspect(message)}")

      state
    else
      from.()
      %{state | one_shot_osc_queries: queries}
    end
  end

  @impl true
  def terminate(_reason, _state = %SCSoundServer.State{}) do
    IO.puts("soundserver terminate wait 1 sec until supercollider process is dead")
    :timer.sleep(1000)
  end
end

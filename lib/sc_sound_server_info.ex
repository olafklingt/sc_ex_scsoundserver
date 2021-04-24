defmodule SCSoundServer.Info.Group do
  use TypedStruct

  typedstruct do
    field(:id, integer, enforce: true)
    field(:children, list, enforce: true)
  end

  def map_preply([_nunused | list]) do
    {a, _} = make(list)
    a
  end

  def make([]) do
    {[], []}
  end

  def make([id, number | tail]) do
    if(number < 0) do
      SCSoundServer.Info.Synth.make(id, tail)
    else
      if(number == 0) do
        {%SCSoundServer.Info.Group{id: id, children: []}, tail}
      else
        {children, tail} =
          Enum.reduce(1..number, {[], tail}, fn _i, {out, tail} ->
            {g, tail} = SCSoundServer.Info.Group.make(tail)
            {out ++ [g], tail}
          end)

        {%SCSoundServer.Info.Group{id: id, children: children}, tail}
      end
    end
  end
end

defmodule SCSoundServer.Info.Synth do
  use TypedStruct

  typedstruct do
    field(:id, integer, enforce: true)
    field(:name, atom, enforce: true)
    field(:arguments, list, enforce: true)
  end

  def make(id, [name, number | args_tail]) do
    {arguments, tail} = Enum.split(args_tail, number * 2)
    arguments = args_to_keylist(arguments)

    {%SCSoundServer.Info.Synth{id: id, name: String.to_atom(name), arguments: arguments}, tail}
  end

  def def_list_to_argument_rate_list(deflist) do
    Enum.map(
      deflist,
      fn {defname, def} ->
        rates =
          Enum.filter(def.ugens, fn n ->
            n.name == "AudioControl" ||
              n.name == "Control" ||
              n.name == "TrigControl"
          end)
          |> Enum.sort(fn a, b -> a.special_index < b.special_index end)
          |> Enum.map(fn u ->
            {
              Enum.at(def.parameter_names, u.special_index).name,
              case u.rate do
                2 -> :audio
                1 -> :control
                0 -> :scalar
              end
            }
          end)

        outrate =
          Enum.filter(
            def.ugens,
            fn n ->
              String.contains?(n.name, "Out") && n.name != "LocalOut"
            end
          )
          |> Enum.map(fn u ->
            case u.rate do
              2 -> :audio
              1 -> :control
              0 -> :scalar
            end
          end)
          |> List.first()

        {defname, [rates: rates, outrate: outrate]}
      end
    )
  end

  def args_to_keylist(arguments) do
    Enum.chunk_every(arguments, 2)
    |> Enum.map(fn [k, v] -> {String.to_atom(k), v} end)
  end
end

defmodule SCSoundServer.Info do
  def get_parent_group(synth_id, g = %SCSoundServer.Info.Group{}, _parent_group) do
    Enum.flat_map(g.children, fn c -> get_parent_group(synth_id, c, g.id) end)
  end

  def get_parent_group(synth_id, s = %SCSoundServer.Info.Synth{}, parent_group) do
    if synth_id == s.id do
      [parent_group]
    else
      []
    end
  end

  @spec get_only_synth_info(SCSoundServer.Info.Group) :: list[SCSoundServer.Info.Synth]
  def get_only_synth_info(g = %SCSoundServer.Info.Group{}) do
    Enum.flat_map(g.children, &get_only_synth_info/1)
  end

  @spec get_only_synth_info(SCSoundServer.Info.Synth) :: List[SCSoundServer.Info.Synth]
  def get_only_synth_info(s = %SCSoundServer.Info.Synth{}) do
    [s]
  end

  defp is_audio_synth(s = %SCSoundServer.Info.Synth{}, def_arg_rates) do
    def_arg_rates[s.name][:outrate] == :audio
  end

  defp is_control_synth(s = %SCSoundServer.Info.Synth{}, def_arg_rates) do
    def_arg_rates[s.name][:outrate] == :control
  end

  def get_path_to_control_bus(bus_int, info_tree, def_arg_rates, path \\ []) do
    synth = find_last_synth_reading_from_control_bus(bus_int, info_tree)
    [{arg, _bus_id}] = Enum.filter(synth.arguments, fn {_k, v} -> v == "c#{trunc(bus_int)}" end)

    if synth.arguments[:_out] == 0.0 do
      path = [:/, :kr_arguments, arg] ++ path
      path
    else
      path =
        get_path_to_control_bus(
          synth.arguments[:_out],
          info_tree,
          def_arg_rates,
          [:kr_arguments, arg] ++ path
        )

      path
    end
  end

  def get_path_to_audio_bus(bus_int, info_tree, def_arg_rates, path \\ []) do
    synth = find_last_synth_reading_from_audio_bus(bus_int, info_tree)
    [{arg, _bus_id}] = Enum.filter(synth.arguments, fn {_k, v} -> v == "a#{trunc(bus_int)}" end)

    if synth.arguments[:_out] == 0.0 do
      path = [:/, :ar_arguments, arg] ++ path
      path
    else
      path =
        get_path_to_audio_bus(
          synth.arguments[:_out],
          info_tree,
          def_arg_rates,
          [:ar_arguments, arg] ++ path
        )

      path
    end
  end

  def find_last_synth_reading_from_audio_bus(
        bus_int,
        info_tree
      ) do
    List.first(find_synth_reading_from_audio_bus(bus_int, info_tree))
  end

  def find_last_synth_reading_from_control_bus(
        bus_int,
        info_tree
      ) do
    List.first(find_synth_reading_from_control_bus(bus_int, info_tree))
  end

  def find_synth_reading_from_audio_bus(
        bus_int,
        g = %SCSoundServer.Info.Group{}
      ) do
    bus_id = SCSoundServer.AudioBusAllocator.bus_int_to_id(bus_int)
    sl = SCSoundServer.Info.get_only_synth_info(g)

    sl
    |> Enum.reverse()
    |> Enum.filter(&is_synth_reading_from_bus(bus_id, &1))
  end

  def find_synth_reading_from_control_bus(
        bus_int,
        g = %SCSoundServer.Info.Group{}
      ) do
    bus_id = SCSoundServer.ControlBusAllocator.bus_int_to_id(bus_int)
    sl = SCSoundServer.Info.get_only_synth_info(g)

    sl
    |> Enum.reverse()
    |> Enum.filter(&is_synth_reading_from_bus(bus_id, &1))
  end

  def is_synth_reading_from_bus(
        bus_id,
        s = %SCSoundServer.Info.Synth{}
      ) do
    s.arguments
    |> Enum.filter(&is_not_out_parameter/1)
    |> Enum.filter(&is_parameter_reading_from_bus(&1, bus_id))
    |> length() > 0
  end

  defp is_not_out_parameter({k, _v}) do
    !String.starts_with?(Atom.to_string(k), "_")
  end

  defp is_parameter_reading_from_bus({_k, v}, bus_id) do
    v == bus_id
  end

  def find_last_synth_writing_on_audio_bus(
        bus_int,
        info_tree,
        def_arg_rates
      ) do
    List.first(find_synth_writing_on_audio_bus(bus_int, info_tree, def_arg_rates))
  end

  def find_synth_writing_on_audio_bus(
        bus_int,
        g = %SCSoundServer.Info.Group{},
        def_arg_rates
      ) do
    sl = SCSoundServer.Info.get_only_synth_info(g)

    sl
    |> Enum.reverse()
    |> Enum.filter(&is_audio_synth(&1, def_arg_rates))
    |> Enum.filter(&is_synth_writing_on_bus(bus_int, &1))
  end

  def is_synth_writing_on_bus(
        bus_int,
        s = %SCSoundServer.Info.Synth{}
      ) do
    s.arguments
    |> Enum.filter(&is_out_parameter/1)
    |> Enum.filter(&is_parameter_writing_to_bus(&1, bus_int))
    |> length() > 0
  end

  defp is_out_parameter({k, _v}) do
    String.starts_with?(Atom.to_string(k), "_out")
  end

  defp is_parameter_writing_to_bus({_k, v}, bus_int) do
    v == bus_int
  end

  def find_last_synth_writing_on_control_bus(
        bus_int,
        info_tree,
        def_arg_rates
      )
      when is_list(def_arg_rates) do
    List.first(find_synth_writing_on_control_bus(bus_int, info_tree, def_arg_rates))
  end

  def find_synth_writing_on_control_bus(
        bus_int,
        g = %SCSoundServer.Info.Group{},
        def_arg_rates
      )
      when is_list(def_arg_rates) do
    sl = SCSoundServer.Info.get_only_synth_info(g)

    sl
    |> Enum.reverse()
    |> Enum.filter(&is_control_synth(&1, def_arg_rates))
    |> Enum.filter(&is_synth_writing_on_bus(bus_int, &1))
  end

  def find_synth(test_fun, synth = %SCSoundServer.Info.Synth{}) do
    if test_fun.(synth) do
      synth
    else
      false
    end
  end

  def find_synth(_test_fun, []) do
    false
  end

  def find_synth(test_fun, [first | rest]) do
    r = find_synth(test_fun, first)

    if(r == false) do
      find_synth(test_fun, rest)
    else
      r
    end
  end

  def find_synth(test_fun, %SCSoundServer.Info.Group{children: c}) do
    find_synth(test_fun, c)
  end

  def find_synth_by_id(synth_id, info_tree) do
    find_synth(&(&1.id == synth_id), info_tree)
  end

  def find_synth_by_name(name, info_tree) do
    find_synth(&(&1.name == name), info_tree)
  end

  def find_synth_reading_bus(bus_id, info_tree) do
    find_synth(&Enum.member?(&1.arguments, bus_id), info_tree)
  end

  def find_used_busses_r(
        synth_info = %SCSoundServer.Info.Synth{arguments: a},
        def_arg_rates,
        used_busses
      ) do
    outrate = def_arg_rates[synth_info.name][:outrate]

    {_out, bus_int} =
      Enum.find(a, fn {k, _v} -> String.starts_with?(Atom.to_string(k), "_out") end)

    bus_int =
      if(Atom.to_string(synth_info.name) =~ "outmixer") do
        0.0
      else
        bus_int
      end

    if Enum.member?(used_busses[outrate], bus_int / 1) do
      ins_from_bus = Enum.filter(synth_info.arguments, fn {_k, v} -> is_binary(v) end)

      used_busses =
        Enum.reduce(ins_from_bus, used_busses, fn {_k, v}, used_busses ->
          <<rate, rest::binary>> = v
          # c == 99
          # a == 97
          if(rate == 99) do
            put_in(
              used_busses[:control],
              MapSet.put(used_busses[:control], String.to_integer(rest) / 1)
            )
          else
            put_in(
              used_busses[:audio],
              MapSet.put(used_busses[:audio], String.to_integer(rest) / 1)
            )
          end
        end)

      used_busses
    else
      used_busses
    end
  end

  def find_used_busses_r(
        %SCSoundServer.Info.Group{children: c},
        def_arg_rates,
        used_busses
      ) do
    Enum.reverse(c)
    |> Enum.reduce(used_busses, fn s, used_busses ->
      find_used_busses_r(s, def_arg_rates, used_busses)
    end)
  end

  def find_used_busses(
        info_tree,
        def_arg_rates
      ) do
    used_busses = [audio: MapSet.new([0.0]), control: MapSet.new([])]

    find_used_busses_r(
      info_tree,
      def_arg_rates,
      used_busses
    )
  end
end

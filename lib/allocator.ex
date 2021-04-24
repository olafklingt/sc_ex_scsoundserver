# todo
# the documentation says that Process.send_after is more efficient but works only with GenServer
# I think i should write a general Allocator Genserver. And 3 interfaces for it.

defmodule SCSoundServer.AudioBusAllocator do
  use Agent

  def start_link(size, offset) do
    Agent.start_link(
      fn ->
        Enum.map(offset..(size - 1), fn x -> {x, "a#{x}"} end)
      end,
      name: __MODULE__
    )
  end

  def bus_id_to_int(id) do
    <<"a", rest::binary>> = id
    String.to_integer(rest)
  end

  def bus_int_to_id(bus_int) do
    "a#{trunc(bus_int)}"
  end

  def pop_bus_id() do
    {_, id} = pop_bus()
    id
  end

  def pop_bus_int() do
    {int, _} = pop_bus()
    int
  end

  def pop_bus() do
    Agent.get_and_update(__MODULE__, fn state ->
      [n | tail] = state
      {n, tail}
    end)
  end

  def push_bus(bus_int) when is_integer(bus_int) do
    push_bus({bus_int, "a#{bus_int}"})
  end

  def push_bus(bus_id) when is_binary(bus_id) do
    push_bus({bus_id_to_int(bus_id), bus_id})
  end

  def push_bus({bus_int, bus_id}) do
    Agent.update(__MODULE__, fn state ->
      # IO.inspect({:ar_busses_num, length(state)})
      [{bus_int, bus_id} | state]
    end)
  end

  def push_bus_after(bus_int, transition_time) when is_integer(bus_int) do
    # IO.inspect({:push_bus_after_init_ar, bus_int, transition_time})
    :timer.apply_after(trunc(transition_time * 1000), __MODULE__, :push_bus, [bus_int])
  end
end

defmodule SCSoundServer.ControlBusAllocator do
  use Agent

  def start_link(size, offset) do
    Agent.start_link(
      fn ->
        Enum.map(offset..(size - 1), fn x -> {x, "c#{x}"} end)
      end,
      name: __MODULE__
    )
  end

  def bus_id_to_int(id) do
    <<"c", rest::binary>> = id
    String.to_integer(rest)
  end

  def bus_int_to_id(bus_int) do
    "c#{trunc(bus_int)}"
  end

  def pop_bus_id() do
    {_, id} = pop_bus()
    id
  end

  def pop_bus_int() do
    {int, _} = pop_bus()
    int
  end

  def pop_bus() do
    Agent.get_and_update(__MODULE__, fn state ->
      [n | tail] = state
      {n, tail}
    end)
  end

  def push_bus(bus_int) when is_integer(bus_int) do
    push_bus({bus_int, "c#{bus_int}"})
  end

  def push_bus(bus_id) when is_binary(bus_id) do
    push_bus({bus_id_to_int(bus_id), bus_id})
  end

  def push_bus({bus_int, bus_id}) do
    Agent.update(__MODULE__, fn state ->
      # IO.inspect({:kr_busses_num, length(state)})
      [{bus_int, bus_id} | state]
    end)
  end

  def push_bus_after(bus_int, transition_time) when is_integer(bus_int) do
    # IO.inspect({:push_bus_after_init_kr, bus_int, transition_time})
    :timer.apply_after(trunc(transition_time * 1000), __MODULE__, :push_bus, [bus_int])
  end
end

defmodule SCSoundServer.NodeIdAllocator do
  use Agent

  def start_link(size, offset) do
    Agent.start_link(
      fn ->
        Enum.to_list(offset..(size + offset))
      end,
      name: __MODULE__
    )
  end

  def pop_node_id() do
    Agent.get_and_update(__MODULE__, fn state ->
      [n | tail] = state
      {n, tail}
    end)
  end

  def push_node_id(node_id) do
    Agent.update(__MODULE__, fn state ->
      state ++ [node_id]
    end)
  end
end

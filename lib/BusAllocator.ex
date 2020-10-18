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

  def pop_bus_id() do
    {_, id} = pop_bus()
    id
  end

  def pop_bus_int() do
    {int, _} = pop_bus()
    int
  end

  def pop_bus() do
    # IO.inspect({:aba, length(state)})

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
      [{bus_int, bus_id} | state]
    end)
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
    <<"a", rest::binary>> = id
    String.to_integer(rest)
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
      # IO.inspect({:cba, length(state)})
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
      [{bus_int, bus_id} | state]
    end)
  end
end

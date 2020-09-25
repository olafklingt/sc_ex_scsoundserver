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

  def make(list) do
    [id | tail] = list

    [number | tail] = tail

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
    field(:name, String.t(), enforce: true)
    field(:arguments, list, enforce: true)
  end

  def make(id, list) do
    [name | tail] = list
    [number | tail] = tail
    {arguments, tail} = Enum.split(tail, number * 2)
    {%SCSoundServer.Info.Synth{id: id, name: name, arguments: arguments}, tail}
  end
end

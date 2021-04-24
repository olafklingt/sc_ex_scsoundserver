defmodule SCSoundServer.Message do
  defp de_keyword_args(args) do
    List.flatten(
      Enum.map(args, fn x ->
        if is_tuple(x) do
          Tuple.to_list(x)
        else
          x
        end
      end)
    )
  end

  defp de_atom_args(args) do
    Enum.map(args, fn x ->
      if is_atom(x) do
        Atom.to_string(x)
      else
        x
      end
    end)
  end

  def new_synth(def_name, node_id, add_action_id, target_node_id, args) do
    %OSC.Message{
      address: "/s_new",
      arguments:
        ([def_name, node_id, add_action_id, target_node_id] ++ args)
        |> de_keyword_args()
        |> de_atom_args()
    }
  end

  def new_group(node_id, add_action_id, target_node_id) do
    %OSC.Message{
      address: "/g_new",
      arguments: [node_id, add_action_id, target_node_id]
    }
  end

  def new_parallel_group(node_id, add_action_id, target_node_id) do
    %OSC.Message{
      address: "/p_new",
      arguments: [node_id, add_action_id, target_node_id]
    }
  end

  def query_tree(node_id, details \\ 1) do
    %OSC.Message{
      address: "/g_queryTree",
      arguments: [node_id, details]
    }
  end

  def dump_tree(node_id, details \\ 1) do
    %OSC.Message{
      address: "/g_dumpTree",
      arguments: [node_id, details]
    }
  end

  def get(synth_id, control_name) do
    %OSC.Message{
      address: "/s_get",
      arguments: [synth_id, control_name] |> de_atom_args()
    }
  end

  def notify(flag, cid) do
    %OSC.Message{
      address: "/notify",
      arguments: [flag, cid]
    }
  end

  def send_def(defbinary) do
    %OSC.Message{
      address: "/d_recv",
      arguments: de_keyword_args([defbinary])
    }
  end

  def load_def(path) do
    %OSC.Message{
      address: "/d_load",
      arguments: [path]
    }
  end

  def set(node_id, args) do
    %OSC.Message{
      address: "/n_set",
      arguments: [node_id] ++ (args |> de_keyword_args() |> de_atom_args())
    }
  end

  def run(node_id, flag) do
    %OSC.Message{
      address: "/n_run",
      arguments: [node_id, flag]
    }
  end

  def free(node_id) do
    %OSC.Message{
      address: "/n_free",
      arguments: [node_id]
    }
  end

  def free_all(node_id) do
    %OSC.Message{
      address: "/g_freeAll",
      arguments: [node_id]
    }
  end

  def clear_sched() do
    %OSC.Message{
      address: "/clearSched",
      arguments: []
    }
  end

  def quit() do
    %OSC.Message{
      address: "/quit",
      arguments: []
    }
  end
end

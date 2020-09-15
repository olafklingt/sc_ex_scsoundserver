# ScExScSoundServer


ScExScSoundServer is a partial and opinionated implementation of an interface to supercollider in elixir.

- Its partial because the supercollider DSP server SCSynth is more flexible than needed.

- ~~Its partial because it is too much work to implement synthdef compilation.~~ (see sc_ex_synthdef library)

- Its partial because I simply don't make use of some aspects of supercollider.

- It is partial because it is simply a too big project. It is unlikely to be more than a *proof of concept* soon.

It is opinionated because I dislike in SCLang that all interactions with the sound server are asynchronous. I provide the option to start and stop a synth in a synchronous manner. This is realized by encapsulating each group or synth as a GenServer.

I hope its performant.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sc_ex_scsoundserver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sc_ex_scsoundserver, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/sc_ex_scsoundserver](https://hexdocs.pm/sc_ex_scsoundserver).

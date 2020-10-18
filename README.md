# ExSCSoundServer

(Work in Progress)

ScExScSoundServer is a partial and opinionated implementation of an interface to SuperCollider in Elixir.

- Its partial because the supercollider DSP server "scsynth" is more flexible than needed.

- Its partial because I simply don't make use of some aspects of supercollider.

- Its partial because SuperCollider provides different ways to do the same thing of which I choose one.

- It is partial because it is simply a big project. It is unlikely to be more than a *proof of concept* soon.

It is opinionated because I dislike in SCLang that all interactions with the sound server are asynchronous. I provide the option to start and stop a synth in a synchronous manner utilizing the servers response messages.

# Related Repositories

[ExSCSynthDef](https://github.com/olafklingt/sc_ex_synthdef)
A experimental SynthDef compiler in Elixir, that treats UGens as functions (work in progress).

[ExSCLib](https://github.com/olafklingt/sc_ex_lib)
Helpful function and concepts from SuperCollider for Elixir (work in progress).

[ExSCLang](https://github.com/olafklingt/sc_ex_sclang)
Elixir port to a SuperCollider Language instance (proof of concept).

[aXotypixusc](https://github.com/olafklingt/axotypixusc)
A eXample Of a TinY PIano in elIXir USing SuperCollider (example).

## Installation

```elixir
def deps do
  [
    {:sc_ex_scsoundserver, git: "https://github.com/olafklingt/sc_ex_scsoundserver"}
  ]
end
```

# ExSCSoundServer

This project provides a proof-of-concept implementation of an [Elixir](https://elixir-lang.org/) scripting interface to [SuperCollider](https://supercollider.github.io/)'s *scsynth* and *supernova* DSP server.

🌴The idea was motivated by my personal use of SuperCollider and my preference for using Elixir as a scripting language. Contributors are encouraged to fork this repository and extend the functionality towards a more comprehensive feature set.

The API was inspired by SuperCollider's own *sclang* API and shares many similarities. Two important differences are:
1. Only a subset of the flexibility of *sclang* is implemented here. This is because I focused on features that I personally use.
2. While *sclang* relies exclusively on **asynchronous** calls to *scsynth*, ExScSoundServer provides an additional option for making **synchronous** calls. Synchronous calls allow you to use the return values from *scsynth* directly (see examples below).


## Installation

```elixir
def deps do
  [
    {:sc_ex_scsoundserver, git: "https://github.com/olafklingt/sc_ex_scsoundserver"}
  ]
end
```

## API Reference

TODO

## TODO

- [x] Implement synchronous and asynchronous calls to scsynth
- [ ] make function names in the API more consistent
- [ ] server options (in the SuperCollider sense)
- [ ] application with configuration (in the Elixir sense)
- [ ] Rename the repository to reflect more clearly that it isn't a sound server and not a synthesizer and not a stellar explosion.

## Related Repositories

The following projects also combine Elixir with SuperCollider. They are independent proof-of-concept projects and examples.

[ExSCSynthDef](https://github.com/olafklingt/sc_ex_synthdef)
An experimental SynthDef compiler in Elixir that treats UGens as functions

[ExSCLang](https://github.com/olafklingt/sc_ex_sclang)
Elixir port to a SuperCollider language instance

## How to use and example

A example midi piano using my libraries is [Axotypixusc](https://github.com/olafklingt/axotypixusc) "A eXample Of a TinY PIano in elIXir USing SuperCollider".


## Contribute

TODO

## License

GNU AFFERO GENERAL PUBLIC LICENSE

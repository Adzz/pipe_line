# PipeLine

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pipe_line` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pipe_line, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pipe_line](https://hexdocs.pm/pipe_line).

##### Notes

* There are implications for memory if you have a large amount of data and you have
multiple steps that do stuff to it, each of which add their result under a new key in the
map. Doing this creates effectively immutable state, and you could backtrack easily etc
but has implications. It's up to the user to decide whether to make the state immutable
or not. Both are available.

#### Requirements

aka design goals

1. Good stack traces - I want to know which step failed - ideally know the function by name
2. Flexibility and extensibility in how a pipeline runs, without having to specify new step types or action return types.
3. A smooth interface between userland code and the PipeLine - functions we have already should work without having to leak the pipeline all over the code.
4. Easy (extensible) telemetry for each step
5. Probably needs an async story...? Though I'd rather leave that up to the user by for example having one step that spins its own tasks off and handles supervision etc itself. Having steps run async adds complexity and probably won't serve all use cases.
6. Merge pipelines


What does it mean to map a pipeline? it would mean iterating through it and doing
something to each step in it. So for us it would be iterating through each step and
doing a thing to that step.... Like run the action on it... But could also be "log some
tracing, then run action, then log again". Each of these mapping fns provide something
different.

Really the whole point is that because we just have a fairly transparent type, you can
just map over the struct and do bits to it yourself.

How does this change the UI/UX then. Well we could have actions just be placed on the
step as is, then have different mapping functions that handle iterating over the steps.


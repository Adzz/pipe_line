# PipeLine.new()
# |> PipeLine.add_steps([
#   # How do we DI the functions...
#   # What should the undo fns return?
#   # How do we get tracing in easy? We can debug log.
#   PipeLine.Step.new(&MyModule.my_fun(&1.thing), on_error: &MyModule.undo/1),
#   PipeLine.Step.new(&IO.inspect(&1.state)),
#   PipeLine.Step.meta_step(&MyModule.my_fun/1, on_error: &MyModule.undo_meta/1),
#   PipeLine.Step.new(&IO.inspect(&1.state))
# ])

# PipeLine.new(%{})
# |> PipeLine.add_step(fn state -> state + 1 end)
# |> PipeLine.add_meta_step(fn pipeline -> pipeline.state + 1 end)

# # vs

# PipeLine.new(%{})
# |> PipeLine.add_step(PipeLine.Step.new_state_step(fn state -> state + 1 end))
# |> PipeLine.add_step(PipeLine.Step.new_meta_step(fn pipeline -> pipeline.state + 1 end))

# # vs

# PipeLine.new(%{})
# |> PipeLine.add_steps([
#   # If we can mock the functions in the steps we can get nice assertions about the steps
#   # in the pipeline. We can assert that the specific function gets called.
#   # Then have unit tests for what the functions actually do. You essentially
#   # just want to know you are sending the right things to the right functions.
#   PipeLine.Step.new(PipeLine.Step.add_to_state(:result, MyModule.my_fun(&1.thing))),
#   PipeLine.Step.new_meta_step(&MyModule.my_meta_step/1)
# ])
# |> PipeLine.trace_each_step()
# # Which is just:
# |> PipeLine.each(PipeLine.trace_each_step() / 1)

# # Where
# # PipeLine.trace_each_step/1
# # is
# # fn pipeline ->
# # IO.inspect(pipeline.state, label: "Before Step:")
# # PipeLine.active_step(pipeline).action.(pipeline) |> IO.inspect(label: "After step:")
# # end

# # so each / map  / reduce would have to get the pipeline but then it gets weird - what
# # does the user do with it, they need too know about the whole meta thing and need to
# # know how to access the right step to execute....

# # How does it look if the pipeline doesn't have state, but the state is in the acc.

# PipeLine.new()
# |> PipeLine.add_steps([
#   PipeLine.Step.new(PipeLine.Step.add_to_state(:result, MyModule.my_fun(&1.thing))),
#   PipeLine.Step.new_meta_step(&MyModule.my_meta_step/1)
# ])
# |> PipeLine.reduce(fn step, acc ->
#   # The result becomes the new acc .The issue is we dont know what step we have meaning
#   # we don't know what to pass to the action. It should just get all the state.
#   PipeLine.Step.run_action(acc.arg_1, acc.arg_2)
# end)

# # This is a bit weird to map over the pipeline but not get given the steps...
# |> PipeLine.map(fn {pipeline, current_step} ->
#   pipeline.state |> IO.inspect(limit: :infinity, label: "Before")
#   result = current_step.action.(pipeline)
#   result |> IO.inspect(limit: :infinity, label: "After")
# end)
# # If we get the step only when mapping then meta steps get harder. But we could
# # instead have PipeLine.meta_map or whatever

# # In reality map just changes the thing it doesn't execute it. That's still seperate. It
# # might just give you a quick way to be add logging though for example.
# |> PipeLine.with_logging()
# |> PipeLine.map(&PipeLine.trace/1)
# |> PipeLine.reduce_while(fn step, acc ->
#   {:cont, step.action(pipeline.state)}
# end)

# # Implement enumerable for PipeLine ?
# |> PipeLine.map(pipeline)

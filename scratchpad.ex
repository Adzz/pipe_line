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






 # *_while is fundamental to iterating, because when iterating there are various ways we
  # can do that.

  # Just go back to execute_while. Allow people to define their own executors
  # It's not hard. They have the tools with fns like "next_step" and "previous_step"
  # maybe you could have an executor like "Capture all exceptions"
  # or in_parralell..... async ... executor that spins a task off for each.
  # or "log each step" or "with_tracing". Though some of these feel like they
  # could be composed. In fact that is the point how do we ensure you can compose them?
  # I think you'd need to abstract traversal in that case...

  # abstracting the traversal is different from letting people define their own.
  # We want them to be able to do all of them, which they will.

  # But for now, being able to have higher executor makes sense I think, so you can
  # compose things like "add logging" something like
  # but thts just a step, so what is the arg the whole pipeline? Or the whole step?
  # |> PipeLine.execute_with(fn state ->
  # end)

  # I feel like what I'm trying to do is generalise the on_error thing. That needs 3 things
  #   1. defining on_* things (fns to run) per step (this is what to to on_*)
  #   2. defining how we now when the thing has happened (error, halt, etc)
  #   3. how the pipeline treats the steps when on_*'ing '

  # feel like we could add callbacks to the pipeline, and let on_compensate be one of them
  # on_error: compensate

  # some things apply to the whole pipeline (like "log between each step" and some are per step)
  # although all of them can probs be defined in terms on steps - so you end up just composing
  # steps like...
  # PipeLine.Step.new(log_step(trace_step(step)))
  # Applying to a pipeline just allows less typing I guess.

  # This is essentially trying to generalise the "undo" idiom. But why would you want to do that.
  # it's nothing without a problem it's solving.
  PipeLine.new(1)
  |> PipeLine.add_junction(:on_error, :error, fn state, error -> nil end)
  |> PipeLine.add_callback(:on_halt, :halt, fn state -> nil end)
  |> PipeLine.add_callback(:on_retry, :retry, fn state -> nil end)
  |> PipeLine.add_steps([
    # We could make the add_steps a macro that checks the functions are exported.
    # though we can't check optional callbacks
    MyStepModule,
    {MyStepModule, :fun, []}
    {step, on_error: fn _state, error -> IO.inspect(error) end, on_halt: new_pipe / 1},
    {step, on_error: fn _state, error -> IO.inspect(error) end, on_retry: retry / 1}
  ])
  |> PipeLine.execute_while()

  def execute_while(pipeline, execution_fn) do
    step = pipeline |> PipeLine.curent_step()

    case execution_fn.(pipeline) do
      {action, term} ->
        # we could have modules that export the right functions too - you get like objects
        # for free. The callback model is a bit vile though. Might be hard to see at a glance
        # what's happening, but it is at least clear where to go to see what needs to happen.
        # This would what? Call the on_retry executor for all steps

        # Maybe the railway analogy and this is switching tracks. The tricky part is how do
        # we keep the execution order simple. How do we make tracing what's happening easy, when
        # reading AND when executing??
        case PipeLine.callback_for(action, term) do
          nil ->
            next_step = %{PipeLine.next_step(pipeline) | state: state}
            execution_fn.(next_step)

          callback ->
            callback.(pipeline, term)
        end
    end
  end

  def execute_while(pipeline, execution_fn, compensate_fn \\ &compensate_all/2) do
    case execution_fn.(pipeline) do
      {:error, error} ->
        compensate_fn.(pipeline, error)

      {:suspend, state} ->
        continue = fn state ->
          next_step = %{PipeLine.next_step(pipeline) | state: state}
          execute_while(next_step, execution_fn, compensate_fn)
        end

        {:suspended, state, continue}

      {:halt, term} ->
        term

      {:done, term} ->
        term
    end
  end


@doc """
Sets the state to whatever value is provided. This function allows us to change the internal
representation of a pipe line without breaking all your code.

The status can be used when executing the pipeline to determine what exactly to do next,
like :continue to the next step or :halt_and_compensate etc.
"""
def set_status(%__MODULE__{} = pipeline, status) do
  # This could be good for understanding the pipeline only you dont need state on it
  # really as it can all be stateless. But it might make it easier to be like
  # "which step is running right now"
  %{pipeline | status: status}
end




# The mental model you can have is like columns:

|     step         |     on_error      |    something_else
|----------------------------------------------------
|      A           |         W         |
|      B           |         X         |
|      C           |         Y         |
|      D           |         Z         |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |

# Usual operation is just down the "step" column.

    |     step         |     on_error      |    something_else
    |----------------------------------------------------
--> |      A           |         W         |
    |      B           |         X         |
    |      C           |         Y         |
    |      D           |         Z         |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |
    |                  |                   |

# But if we get a specific return value we may wish to hop left (or right)
# to start a new pipeline (traintrack ?) - hop across to the new column:

|     step         |     on_error      |    something_else
|----------------------------------------------------
|      A           |   -->   W         |
|      B           |         X         |
|      C           |         Y         |
|      D           |         Z         |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |

# But more than that, the way we execute that column may vary by column. In the case
# of the errors, we may wish to run them in reverse order - this simulates an "undo"
# mechanism:

|     step         |     on_error      |    something_else
|----------------------------------------------------
|      A           |         W         |
|      B           |         X      ^  |
|      C           |         Y      |  |
|      D           |         Z   <--|  |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |
|                  |                   |

# The challenge becomes - what's the best way to make all of this obvious to the
# programmer? to trace execution and keep a mental model about what the fluff is happening


# There is a case to say that it's more declarative to have this approach. it kind
# of brings everything on the same level of abstraction to the surface so you can
# clearly see what's happening.
# But there is a limit to screen width and what is pleasing to look at - to much
# info harms readability.

# Also, what could the third column be? What does this buy us? anything at all?
# Shallow call graphs? But wide?

# So it's like can we improve this to make the above clear, would it ever be good?
thing
|> PipeLine.add_junction(:on_error, :error, fn state, error -> nil end)
|> PipeLine.add_callback(:on_halt, :halt, fn state -> nil end)
|> PipeLine.add_callback(:on_retry, :retry, fn state -> nil end)
|> PipeLine.add_steps([
  # We could make the add_steps a macro that checks the functions are exported.
  # though we can't check optional callbacks
  MyStepModule,
  {&MyStepModule.step, on_error: &MyStepModule.undo, on_halt: &new_pipe/1},
  {step, on_error: fn _state, error -> IO.inspect(error) end, on_retry: &retry/1}
])
|> PipeLine.execute_while()


  def execute_while(pipeline, execution_fn) do
    step = pipeline |> PipeLine.curent_step()

    case execution_fn.(pipeline) do
      {action, term} ->
        # we could have modules that export the right functions too - you get like objects
        # for free. The callback model is a bit vile though. Might be hard to see at a glance
        # what's happening, but it is at least clear where to go to see what needs to happen.
        # This would what? Call the on_retry executor for all steps

        # Maybe the railway analogy and this is switching tracks. The tricky part is how do
        # we keep the execution order simple. How do we make tracing what's happening easy, when
        # reading AND when executing??
        case PipeLine.callback_for(action, term) do
          nil ->
            next_step = %{PipeLine.next_step(pipeline) | state: state}
            execution_fn.(next_step)

          callback ->
            callback.(pipeline, term)
        end
    end
  end




# You could program a loop in the sense of try fail at a step undo to jump back two steps
# then start again from there.

# i think this is just a state machine isn't it?






      pipeline =
        PipeLine.new(1)
        |> PipeLine.add_steps([
          add_one,
          # Should this be called on_error? Well it depends. At the most general, it's not
          # about errors it's about "if something happens run this instead". In that case
          # the "something" depends on the executing function, eg for run_while the fn might
          # do nothing on an error. Or we could write one that catches specific exceptions
          # and does something then.... So really to be the most good about it we want
          # a way to be like "run this fn on the return value of the step to determine what
          # to do next". The issue is that gets a bit horrible, do we have to provide that
          # fn for each step? Do we have to provide it via config for the pipeline?
          # As is the execution functions define when to do the on_error, but that means it's
          # set for the whole pipeline. Would it be better to be able to configure it for
          # each step?
          # Also the semantics of "roll back" are up for grabs - do we run all compensating
          # fns? Well for Sagas yes. But we could imagine "only run this compensating fn" or
          # railway thing where we just switch lanes -> run this pipeline of fns instead now.
          # that comes with its own kettle of worms though. Meaning - complexity for the end
          # user, and we risk losing the nice declarative nature of "these are the steps"
          # because steps could be hiding a change of lanes. So we need to either find
          # a way to make that clear. Or like avoid it. I think you can avoid it by making
          # more steps though. The problem is for each branch in logic you now have to like
          # keep more balls in the air. Either you branch and each step below it needs to
          # have a ball in the air for each code path, or you allow only two options which
          # are "bail out or continue". Or the steps do more, but at the cost of less re-use
          # and more obtuse.

          # something something profunctor optics.

          # We need consistency, so either everything is a tuple or everything is an on_error.
          # There is something about the "error" that I don't like - as it feels like it
          # may corner us later. BUT just having a tuple is less obvious on-sight exactly
          # what is happening...... SO yea. tradeoffs.
          # what gives us flexibility later? on_error probably. Then we can have other on_*
          # things I suppose. Go full JS dom on yo ass. on_blur, on_fous, on_cred_invalid

          # That does get to the heart of "How do I know when to stop and compensate?".
          # We want low level ability, with high level API for most cases I guess.

          # It sort of feels like the decision to compensate is set for the whole pipeline
          # but what to compensate is set per step. That means

          # Ah wait. The valid? key. That means each step can return something that marks
          # the pipeline as invalid. We are still in this world of errors not though.
          # MAYBE valid? needs to be continue?: true.

          # continue? or compensate?
          # would you ever one without the other. Yes if you just want simple pipe_lines and
          # don't want to bail out or nothing. Though arguably that's both, just the compensation
          # is nothing, but for the user of the API it's a bit like wat is compensate I don't need it.
          # And having two bits of state now allows states that aren't allowed like "continue? true compensate? true"
          # BUT having that state allows a lot of userland flexibility on when to switch into
          # the different states.
          # Or does it. The state only really makes sense if we then control the execution
          # of the pipeline. If the user does, they'd have to do the work of setting the
          # state, but then writing their own executor functions.

          # I guess it goes back to they can use any state they want as long as they write the
          # executor for it. But we provide some built-in ones to speed stuff up.

          # state like:
          #   - pipe_line_status: :continue
          #   - pipe_line_status: :halt_and_compensate
          #   - pipe_line_status: :halt
          #   - pipe_line_status: :suspend

          # ..., we probably dont need errors as the user can just use the state I imagine.
          # meaning they can put an errors key in it if they so desire.
          # That means less state etc but does mean more user defined stuff. That's okay.
          # The flip side is that plenty of flex to do what you like.

          # If errors is in the state that means that compensate funs need to also
          # need to get dat state.
          {add_two, on_error: undo}
        ])



# Maybe a function needs to either Orchestrate or Do.

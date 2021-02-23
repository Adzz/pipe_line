defmodule PipeLine do
  # REALLY EACH STEP SHOULD HAVE AN ERROR NOT THE ROOT.
  # root can still have valid?. Actually cool to think about "it's valid if X% of steps have no errors"
  # or whatever.
  @enforce_keys [:state, :steps, :on_error]
  defstruct [:state, :steps, :on_error, errors: [], valid?: true]

  @type t :: %__MODULE__{}
  @moduledoc """
  """

  @doc """
  Creates a new PipeLine struct with the given state, 0 steps and an optional on_error.
  on_error defaults to the identity function if it is not provided.

  A PipeLine has some state, some steps and configuration that applies to the whole
  PipeLine, but which may be overridden per step.

  ### Options

    on_error: Is used as the default on_error for each step in a pipeline. This will run if the
              step fails. Defaults to the identity function: & &1. on_error receives the
              error in the error tuple.

  ### Examples

  """
  @spec new(any, list()) :: %__MODULE__{}
  def new(state, opts) do
    on_error = Keyword.get(opts, :on_error, & &1)
    %__MODULE__{state: state, steps: {[], []}, on_error: on_error}
  end

  @doc """
  Adds a step to the pipeline. A PipeLine.Step takes and returns a PipeLine, usually with
  updated state.

  two options when adding a step, you pass a step, or you pass the attrs for a step and
  step is somewhat opaque:

  step = PipeLine.Step.new(fn %{state: state} -> state + 1 end, on_error: & &1)
  PipeLine.new()
  |> PipeLine.add_step(step)

  VS

  PipeLine.new()
  |> PipeLine.add_step(fn pipe -> end, on_error: & &1)

  a state_step is a step that takes and returns the pipeline state.
  What's tricky is the opts... ie on error, do they provide an on error that is
  meta or not ? If they should be the same as the action how do we keep them in step...


  In fact on_error arguably have 2 params. the error from executing the action, and the
  pipeline that the step was in...


  Do we provide options for only run the latest on_error (the on_error of the step that
  failed) or run all on_errors on each step - tricky if we provide a default. Also tricky
  if provide multiple fns how do we ensure they all run... Copy Sage here I guess??

  # Although there is no real need to have a rollback for each step. You can technically
  implement each step to have a rollback which is all of the previous rollbacks combined
  and then manually figure out your own retry strategies etc.
  """
  def add_state_step(%__MODULE__{steps: {steps, seen}} = pipeline, action, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, pipeline.on_error)

    action = fn %PipeLine{state: state} = pipeline ->
      %{pipeline | state: action.(state)}
    end

    steps = {steps ++ [PipeLine.Step.new(action, on_error)], seen}
    %{pipeline | steps: steps}
  end

  def add_step(%__MODULE__{steps: {steps, seen}} = pipeline, %PipeLine.Step{} = step) do
    %{pipeline | steps: {steps ++ [step], seen}}
  end

  @doc """
  A meta step is a step in the pipeline that takes and returns a pipeline. This is the
  default contract for a step in a pipeline.
  """
  def add_meta_step(%__MODULE__{steps: {steps, seen}} = pipeline, action, opts \\ []) do
    on_error = Keyword.get(opts, :on_error, pipeline.on_error)
    steps = {steps ++ [PipeLine.Step.new(action, on_error)], seen}
    %{pipeline | steps: steps}
  end

  PipeLine.new(%{})
  |> PipeLine.add_step(fn state -> state + 1 end)
  |> PipeLine.add_meta_step(fn pipeline -> pipeline.state + 1 end)

  # vs

  PipeLine.new(%{})
  |> PipeLine.add_step(PipeLine.Step.new_state_step(fn state -> state + 1 end))
  |> PipeLine.add_step(PipeLine.Step.new_meta_step(fn pipeline -> pipeline.state + 1 end))

  # vs

  PipeLine.new(%{})
  |> PipeLine.add_steps([
    PipeLine.Step.new(PipeLine.Step.add_to_state(:result, MyModule.my_fun(&1.thing))),
    PipeLine.Step.new_meta_step(&MyModule.my_meta_step/1)
  ])
  # This is a bit weird to map over the pipeline but not get given the steps...
  |> PipeLine.map(fn {pipeline, current_step} ->
    pipeline.state |> IO.inspect(limit: :infinity, label: "Before")
    result = current_step.action.(pipeline)
    result |> IO.inspect(limit: :infinity, label: "After")
  end)
  # If we get the step only when mapping then meta steps get harder. But we could
  # instead have PipeLine.meta_map or whatever
  |> PipeLine.map(&PipeLine.trace/1)
  |> PipeLine.reduce_while(fn step, acc ->
    {:cont, step.action(pipeline.state)}
  end)

  # Implement enumerable for PipeLine ?
  |> PipeLine.map(pipeline)

  # I guess really what we want / need to implement is the reduce_while out of which
  # springs all the other stuff... Like Map. What is the acc though? By default it's the
  # state we are accing over.

  # Oh wait map could just manipulate the state and only expose that...?
  # if you want meta capabilities though you would need to be able to take and return
  # pipelines.... unless it's always state and stuff but the acc is the pipelien

  # In fact surely they key to all this (what makes PipeLine.map different) is the backtracking
  # when we have compensations to do.

  def map(pipeline, fun) do
    funn = fn {pipeline, step} -> {:cont, step.action.(pipeline)} end
    reduce_while(pipeline, pipeline, fun)
  end

  def reduce_while(%__MODULE__{steps: {[], _seen}}, acc, fun) do
    {:done, acc}
  end

  def reduce_while(%__MODULE__{steps: {[step | rest], seen}} = pipeline, acc, fun) do
    next_step = %{pipeline | steps: {rest, [step | seen]}}

    case fun.({pipeline, acc}) do
      {:cont, result} ->
        run_while(next_step, result, fun)

      {:suspend, term} ->
        {:suspended, term, &run_while(next_step, &1, fun)}

      error = {:error, term} ->
        step.on_error(error, pipeline)
        compensate(pipeline, error)

      {:halt, term} ->
        {:halted, term}

      _ ->
        raise "Invalid reducing fn"
    end
  end

  defp compensate(%__MODULE__{steps: {_seen, []}} = pipeline, error) do
    error
  end

  defp compensate(%__MODULE__{steps: {seen, [step | rest]}} = pipeline, error) do
    next_step = %{pipeline | steps: {[step | seen], rest}}
    step.on_error(error, pipeline)
    compensate(next_step)
  end

  @doc """
  Returns the step that the pipeline is currently on. This can be useful for when you are
  mapping through a pipeline.
  """
  def current_step(%__MODULE__{steps: {[], _}}), do: nil
  def current_step(%__MODULE__{steps: {[%PipeLine.Step{} = h | _], _}}), do: h

  @doc """
  Executes the pipeline by calling each step's action in turn. A step's action must return:

    * `{:cont, %PipeLine{}}` to continue to the next step
    * `{:halt, term}` to stop the pipeline and return term.
    * `{:suspend, term}` to pause execution of the pipeline in a way that is resumable.

  If a pipeline is suspended a tuple of {pipeline, continuation} will be returned.
  You can resume by passing the continuation the pipeline like so: `continuation.(pipeline)`

  ### Examples

       add_one = %{action: fn %{state: state} -> {:cont, state + 1} end}
      ...> pipe_line = %PipeLine{state: 1, steps: [add_one], on_error: & &1}
      ...> PipeLine.run_while(pipe_line)
      %PipeLine{state: 2, steps: [add_one], on_error: & &1}

       add_one = %{action: fn %{state: state} -> {:suspend, state + 1} end}
      ...> times_two = %{action: fn %{state: state} -> {:cont, state * 2} end}
      ...> pipe_line = %PipeLine{state: 1, steps: [add_one, times_two], on_error: & &1}
      ...> {pipeline, continuation} = PipeLine.run_while(pipe_line)
      ...> continuation.(pipeline)
      %PipeLine{state: 4, steps: [add_one, times_two], on_error: & &1}
  """
  # We need to manually recur so that a step could in theory return a new pipeline with
  # steps added / removed etc.
  def run_while(%__MODULE__{steps: {[], _seen}} = result), do: result

  def run_while(%__MODULE__{steps: {[step | _rest], _seen}} = pipeline) do
    # to have a step be able to modify the steps to come is a bit trickier because
    # you need to know which step(s) you have already completed for the case that
    # the step doesn't alter the pipeline steps. You could do this:
    # PipeLine.Step.run_action(step, %{pipeline | steps: rest})
    # But then there are implications because the step is now not getting the full pipeline
    # arguably that's fine as this data is really internal...
    # But what if you want to repeat step 1 on step 2

    # We can have steps acc next to it, but how do we merge the old and new steps?
    # The problem being the new step

    # You can either be given all the steps but then not be able to

    # If you want to add a step midway through a step then you would use the exposed API
    # to do that meaning we can easily add the step to the end. We could add set_steps
    # functionality which would allow modification of all steps.

    # Our steps list becomes a tuple of seen / not seen though. A zipper.
    case PipeLine.Step.run_action(step, pipeline) do
      # Not sure about these.
      {:ok, %PipeLine{} = result} -> run_while(result)
      {:error, term} -> {:error, term}
      # I don't like that these require our steps returning different things. We want
      # steps that modify state re-useable, without having to change their return types

      # we want the executor to really be the thing that matters. If we are going to hide
      # behind a "add_modify_state_step" then we'll have to capture return values from
      # there to allow bailing out when modifying state.... Basically the same case
      {:cont, %PipeLine{} = result} -> run_while(result)
      # This could just return the continuation like: fn -> run_while(pipeline) end ?
      {:suspend, {:ok, %PipeLine{} = pipeline}} -> {pipeline, &run_while/1}
      {:suspend, {:error, term}} -> {:error, term}
      {:halt, term} -> term
    end
  end

  # You could just enforce that the steps stop if steps is empty, then have a fn to do that
  # but then you are
  # def run_while(req = %__MODULE__{steps: steps}) do
  #   steps
  #   |> Enum.reduce_while(req, fn step = %PipeLine.Step{}, acc ->
  #     # There is the error / not AND the cont / suspend / halt
  #     # the error determines if we run the on_error for the step.
  #     # We could add error to the mix. and not nest them.

  #     # We probably want the kind of execution decoupled from the step though. So you either
  #     # standardize on all steps having to return {:ok} | {:error} | :halt | :suspended...
  #     # Or you have a different execute fns where an error does different things...
  #     # but that's probably not as flexible. As each one as pretty all or nothing...
  #     # Instead

  #     # How do compensating functions roll into it. Right now we can just pie that off
  #     # to the error you get returned... this will be similar to with, you handle the
  #     # rollback yourself based on the error.

  #     # Keeping them together would be easy too though, and just leave all retries etc up
  #     # to them.

  #     case PipeLine.Step.action().(acc) do
  #       # These are like API niceties? Or are they different run contexts.
  #       # When we fail we actually need to run all of the steps in reverse... or have the
  #       # option to.
  #       {:ok, %PipeLine{} = result} -> {:cont, result}
  #       {:error, term} -> {:halt, {:error, term}}
  #       {:cont, {:ok, %PipeLine{} = result}} -> {:cont, result}
  #       {:cont, {:error, term}} -> {:cont, {:error, term}}
  #       # This could just return the continuation like: fn -> run_while(pipeline) end ?
  #       {:suspend, {:ok, %PipeLine{} = pipeline}} -> {:halt, {pipeline, &run_while/1}}
  #       {:suspend, {:error, term}} -> {:halt, {:error, term}}
  #       {:halt, term} -> {:halt, term}
  #     end
  #   end)
  # end
end

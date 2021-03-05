defmodule PipeLine do
  # REALLY EACH STEP SHOULD HAVE AN ERROR NOT THE ROOT.
  # root can still have valid?. Actually cool to think about "it's valid if X% of steps have no errors"
  # or whatever.
  @enforce_keys [:state, :steps]
  defstruct [:state, :steps, errors: [], valid?: true]

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
  @spec new(any) :: %__MODULE__{}
  def new(state) do
    %__MODULE__{state: state, steps: {[], []}}
  end

  # @doc """
  # Adds a step to the pipeline. A PipeLine.Step takes and returns a PipeLine, usually with
  # updated state.

  # two options when adding a step, you pass a step, or you pass the attrs for a step and
  # step is somewhat opaque:

  # step = PipeLine.Step.new(fn %{state: state} -> state + 1 end, on_error: & &1)
  # PipeLine.new()
  # |> PipeLine.add_step(step)

  # VS

  # PipeLine.new()
  # |> PipeLine.add_step(fn pipe -> end, on_error: & &1)

  # a state_step is a step that takes and returns the pipeline state.
  # What's tricky is the opts... ie on error, do they provide an on error that is
  # meta or not ? If they should be the same as the action how do we keep them in step...

  # In fact on_error arguably have 2 params. the error from executing the action, and the
  # pipeline that the step was in...

  # Do we provide options for only run the latest on_error (the on_error of the step that
  # failed) or run all on_errors on each step - tricky if we provide a default. Also tricky
  # if provide multiple fns how do we ensure they all run... Copy Sage here I guess??

  # # Although there is no real need to have a rollback for each step. You can technically
  # implement each step to have a rollback which is all of the previous rollbacks combined
  # and then manually figure out your own retry strategies etc.
  # """
  # # def add_state_step(%__MODULE__{steps: {steps, seen}} = pipeline, action, opts \\ []) do
  # #   on_error = Keyword.get(opts, :on_error, pipeline.on_error)

  # #   action = fn %PipeLine{state: state} = pipeline ->
  # #     %{pipeline | state: action.(state)}
  # #   end

  # #   steps = {steps ++ [PipeLine.Step.new(action, on_error)], seen}
  # #   %{pipeline | steps: steps}
  # # end

  # # def add_step(%__MODULE__{steps: {steps, seen}} = pipeline, %PipeLine.Step{} = step) do
  # #   %{pipeline | steps: {steps ++ [step], seen}}
  # # end

  # # @doc """
  # # A meta step is a step in the pipeline that takes and returns a pipeline. This is the
  # # default contract for a step in a pipeline.
  # # """
  # # def add_meta_step(%__MODULE__{steps: {steps, seen}} = pipeline, action, opts \\ []) do
  # #   on_error = Keyword.get(opts, :on_error, pipeline.on_error)
  # #   steps = {steps ++ [PipeLine.Step.new(action, on_error)], seen}
  # #   %{pipeline | steps: steps}
  # # end

  @doc """
  Appends the list of steps to the PipeLine's steps. Each step must be a PipeLine.Step
  though no checking is done on the steps, if you don't provide steps you will have a bad
  time when you run it.
  """
  def add_steps(%__MODULE__{steps: {existing, seen}} = pipeline, steps) do
    %{pipeline | steps: {existing ++ steps, seen}}
  end

  @doc """
  Returns the step that the pipeline is currently on. This can be useful for when you are
  mapping through a pipeline.
  """
  def current_step(%__MODULE__{steps: {[], _}}), do: nil
  def current_step(%__MODULE__{steps: {[%PipeLine.Step{} = h | _], _}}), do: h

  @doc """
  Executes the pipeline by calling each step's action in turn. A step's action must return
  one of the following:

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
  def run_while(%__MODULE__{} = pipeline) do
    case do_run_while_do_run_run(pipeline) do
      {:suspended, pipeline, continuation} -> {pipeline, continuation}
      {:halted, term} -> term
      {:done, pipeline} -> pipeline
    end
  end

  # This is like how we recur through the steps and call the actions. It encapsulates the
  # idea of compensating when there is an error. We don't capture exceptions because that
  # should be handles in the on_error itself if it is important.
  # Is this a recursion scheme? Who knows.
  defp do_run_while_do_run_run(%__MODULE__{steps: {[], _seen}} = result) do
    {:done, result}
  end

  defp do_run_while_do_run_run(%__MODULE__{steps: {[step | _rest], _seen}} = pipeline) do
    case PipeLine.Step.run_action(step, pipeline) do
      # {:error, term} -> compensate(pipeline, term)
      # We increment the step after we run it.
      {:cont, %PipeLine{} = result} -> do_run_while_do_run_run(next_step(result))
      {:suspend, %PipeLine{} = result} -> {:suspended, next_step(result), &run_while/1}
      {:halt, term} -> {:halted, term}
      _ -> raise "Error"
    end
  end

  defp next_step(%__MODULE__{steps: {[step | rest], seen}} = pipeline) do
    %{pipeline | steps: {rest, [step | seen]}}
  end

  defp previous_step(%__MODULE__{steps: {seen, [step | rest]}} = pipeline) do
    %{pipeline | steps: {[step | seen], rest}}
  end

  defp compensate(%__MODULE__{steps: {_seen, []}} = pipeline, error) do
    error
  end

  defp compensate(%__MODULE__{steps: {seen, [step | rest]}} = pipeline, error) do
    # The on_error should return a pipeline so on_error can alter the pipeline too.
    compensate(previous_step(PipeLine.Step.compensate(step, error, pipeline)), error)
  end
end

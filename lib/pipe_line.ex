defmodule PipeLine do
  @enforce_keys [:state, :steps]
  defstruct [:state, :steps, track: :continue]

  @type t :: %__MODULE__{}
  @moduledoc """
  A pipelines.
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

  @doc """
  Appends the list of steps to the PipeLine's steps. Each step must be a PipeLine.Step
  though no checking is done on the steps, if you don't provide steps you will have a bad
  time when you run it.
  """
  def add_steps(%__MODULE__{steps: {existing, seen}} = pipeline, steps) do
    steps =
      Enum.map(steps, fn
        %PipeLine.Step{} = step -> step
        {action, undo} -> PipeLine.Step.new(action, on_error: undo)
        action -> PipeLine.Step.new(action)
      end)

    %{pipeline | steps: {existing ++ steps, seen}}
  end

  @doc """
  Appends a step to the end of the pipeline.
  """
  def add_step(%__MODULE__{steps: {existing, seen}} = pipeline, %PipeLine.Step{} = step) do
    %{pipeline | steps: {existing ++ [step], seen}}
  end

  def add_step(%__MODULE__{steps: {existing, seen}} = pipeline, step, opts) do
    undo = opts[:on_error]

    if undo do
      step = PipeLine.Step.new(step, on_error: undo)
      %{pipeline | steps: {existing ++ [step], seen}}
    else
      %{pipeline | steps: {existing ++ [PipeLine.Step.new(step)], seen}}
    end
  end

  def add_step(%__MODULE__{steps: {existing, seen}} = pipeline, step) do
    %{pipeline | steps: {existing ++ [PipeLine.Step.new(step)], seen}}
  end

  @doc """
  Returns the step that the pipeline is currently on. This can be useful for when you are
  mapping through a pipeline.
  """
  def current_step(%__MODULE__{steps: {[], _}} = p), do: {end_of_pipeline(), p}
  def current_step(%__MODULE__{steps: {[%PipeLine.Step{} = h | _], _}}), do: h

  @doc """
  Executes the pipeline by calling each step's action in turn. A step's action must return
  one of the following:

    * `{:cont, %PipeLine{}}` to continue to the next step
    * `{:halt, term}` to stop the pipeline and return term.
    * `{:suspend, term}` to pause execution of the pipeline in a way that is resumable.

  If a pipeline is suspended a tuple of {pipeline, continuation} will be returned.
  You can resume by passing the continuation the pipeline like so: `continuation.(pipeline)`

  This execution function requires that each step returns a specific thing. It might therefore
  be appropriate to wrap existing steps first if you wish to re-use steps from other pipelines.

  For example:

  ```
      continue_step = fn step ->
        fn state ->
          case step.(state) do
            {:ok, stuff} -> {:cont, stuff}
            {:error, stuff} -> {:halt,  stuff}
          end
        end
      end

      add_one_step = fn  number -> {:ok, number + 1} end
      PipeLine.new(1)
      |> PipeLine.add_step(continue_step.(add_one_step))
  ```

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
  def execute_while(pipeline) do
    at_end = PipeLine.end_of_pipeline()

    step =
      pipeline
      |> PipeLine.current_step()
      |> case do
        {^at_end, _pipeline} ->
          pipeline.state

        current ->
          case PipeLine.Step.action(current).(pipeline.state) do
            {:compensate_all, term} ->
              # we could have a status flag on the pipeline saying what track it is on.
              # switch_tracks. Journey.
              # This just lets us know what's executing I guess.
              PipeLine.change_track(pipeline, :compensating)
              |> compensate_all(term)

            {:continue, state} ->
              case PipeLine.next_step(pipeline) do
                {^at_end, _pipeline} -> state
                next -> execute_while(%{next | state: state})
              end

            {:suspend, state} ->
              case PipeLine.next_step(pipeline) do
                {^at_end, _pipeline} -> {:done, state}
                next -> {:suspended, %{next | state: state}, &execute_while/1}
              end

            {:halt, term} ->
              {:halted, term}

            {:error, error} ->
              {:error, error}

            _ ->
              raise "Invalid Step Error"
          end
      end
  end

  def change_track(pipeline, track) do
    %{pipeline | track: track}
  end

  @doc """
  Contains the atom that will be used to let you know that there are no more steps in the
  pipeline when you step forward or backwards through it. This can be used to pattern
  match and determine if there are more steps in the pipeline or not.

  ### Examples
      ...
  """
  def end_of_pipeline(), do: :end_of_the_line

  @doc """
  Low level fn that steps through the pipeline one step.
  """
  def next_step(%__MODULE__{steps: {[], _seen}} = pipeline) do
    {end_of_pipeline(), pipeline}
  end

  def next_step(%__MODULE__{steps: {[step | rest], seen}} = pipeline) do
    %{pipeline | steps: {rest, [step | seen]}}
  end

  @doc """
  Low level fn that steps backwards through the pipeline one step.
  """
  def previous_step(%__MODULE__{steps: {_seen, []}} = pipeline) do
    {end_of_pipeline(), pipeline}
  end

  def previous_step(%__MODULE__{steps: {seen, [step | rest]}} = pipeline) do
    %{pipeline | steps: {[step | seen], rest}}
  end

  @doc """
  This will run all compensation functions for all steps in a pipeline, starting from the
  current step and working backwards to the start of the pipeline.
  """
  def compensate_all(pipeline, error) do
    at_end = PipeLine.end_of_pipeline()

    new_state =
      pipeline
      |> PipeLine.current_step()
      |> PipeLine.Step.compensate(error, pipeline)

    case PipeLine.previous_step(pipeline) do
      {^at_end, pipeline} -> {:error, error}
      prev -> compensate_all(%{prev | state: new_state}, error)
    end
  end
end

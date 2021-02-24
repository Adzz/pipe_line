defmodule PipeLine.Step do
  @enforce_keys [:action, :on_error]
  defstruct @enforce_keys

  @moduledoc """
  A PipeLine.Step is the action you want to take at a given point in a PipeLine. It can
  optionally include an on_error callback which will be called if the step's action fails.
  """

  @doc """
  An accessor for the action that a step has. This prevents you reaching into the internal
  representation of a PipeLine.Step which could change in the future.
  """
  def action(%__MODULE__{action: action}) do
    action
  end

  @doc """
  An accessor for the on_error callback that a step has. This prevents you reaching into
  the internal representation of a PipeLine.Step which could change in the future.

  ### Examples

    PipeLine.Step.on_error(%PipeLine.Step{on_error: & &1})
    #=> & &1
  """
  def on_error(%__MODULE__{on_error: on_error}) do
    on_error
  end

  @doc """
  Returns a new Pipeline.Step with the given action and options. See options below for the
  full list.

  The action will be given the pipeline's state and whatever the action returns will be
  the new pipeline state.

  ### Options

    * `on_error: fn error, pipeline -> ... end` - Will be run if the Step's action fails
    by returning an error tuple. The `on_error` function will be given the error from the
    failing step and the whole pipeline. A pipeline will step through all of the on_error
    callbacks given in a pipeline starting with the step that failed and working backward
    to the first step.

  ### Examples


  """
  def new(action, opts \\ []) do
    # We can default to ID or make it nil. Not sure which is quicker.
    on_error = Keyword.get(opts, :on_error, fn _error, _pipe_line -> :no_op end)

    action = fn %PipeLine{state: state} = pipeline ->
      %{pipeline | state: action.(state)}
    end

    new_meta_step(action, on_error)
  end

  @doc """
  Returns a new Pipeline.Step with the given action and options. See options below for the
  full list.

  Meta steps are steps whose action take and return a pipeline, meaning the action will be
  given the entire pipeline on each call. It's up to you to decide what to do with it. This
  allows meta capabilities, like having a step that adds a step. The on_error callback works
  the same as for `new`

  ### Options

    * `on_error: fn error, pipeline -> ... end` - Will be run if the Step's action fails
    by returning an error tuple. The `on_error` function will be given the error from the
    failing step and the whole pipeline. A pipeline will step through all of the on_error
    callbacks given in a pipeline starting with the step that failed and working backward
    to the first step.

  ### Examples


  """
  def new_meta_step(action, on_error) when is_function(on_error, 2) and is_function(action, 1) do
    %__MODULE__{action: action, on_error: on_error}
  end

  @doc """
  Takes a step and a pipeline and runs the action on the step. A PipeLine.Step always takes
  and returns a PipeLine. That means to run a step's action you must always pass in a pipeline
  to it.

  Steps should not be run on their own, this function is provided so that you can define your
  own executions for a PipeLine. For example, you could implement an execute/1 function
  that takes the pipeline and fails as soon as it sees an error like so:

  ```elixir
  def execute(%PipeLine{steps: steps} = pipeline) do
    Enum.reduce_while(steps, pipeline, fn step, acc ->
      case PipeLine.Step.run_action(step, acc) do
        {:ok, %PipeLine{} = result} -> {:cont, result}
        {:error, term} -> {:halt, {:error, term}}
      end
    end)
  end
  ```

  Using this function instead of reaching into the struct like so `PipeLine.Step.action.(pipeline)`
  allows me to change the internal representation of a PipeLine.Step without risking
  breaking your programs.
  """
  def run_action(%__MODULE__{action: action}, %PipeLine{} = pipeline) do
    action.(pipeline)
  end
end

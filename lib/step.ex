defmodule PipeLine.Step do
  @enforce_keys [:action, :on_error]
  defstruct @enforce_keys

  @moduledoc """
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
  Returns a new Pipeline.Step with the given action and on_error. The action should take
  and return a PipeLine. The on_error will be given the result of the PipeLine.Step that
  failed, and the PipeLine that step was in. That gives you enough information to react
  accordingly to the error.
  """
  def new(action, opts) do
    # We can default to ID or make it nil. Not sure which is quicker.
    on_error = Keyword.get(opts, :on_error, & &1)

    action = fn %PipeLine{state: state} = pipeline ->
      %{pipeline | state: action.(state)}
    end

    new_meta_step(action, on_error)
  end

  @doc """
  Meta steps are steps whose action take and return a pipeline. Their on_error callback
  still gets passed the result of the step's action in the case of failure.

  - rescue any error if you get one on a step failure, run the compensating fn(s) and
  re-raise the offending error (with the original stack trace hopefully).
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

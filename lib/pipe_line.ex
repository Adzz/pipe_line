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
              step fails. Defaults to the identity function: & &1

  """
  # On error can be overriden per step or configured for the whole pipeline.
  @spec new(any, opts) :: %__MODULE__{}
  def new(state, opts) do
    on_error = Keyword.get(opts, :on_error, & &1)
    %Domain.Request{state: state, steps: [], on_error: on_error}
  end
end

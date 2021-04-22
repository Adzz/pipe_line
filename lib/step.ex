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
  This lets us easily compare if two PipeLine.Steps are the same. This will only work if
  the action and the on_error callback on any action are MFA tuples...

  Otherwise we have to mock the funs.
  """
  def equal(step_1, step_2) do
  end

  @doc """
  Runs the on_error for the given step. The on_error callback gets passed the error that
  triggered the callback and the pipeline that the step is in. That allows us to have
  a compensate function which modifies the pipeline of remaining steps.

  In reality this should be used in a function that runs the pipeline.

  ### Examples

      step = Pipeline.Step.new(& &1, on_error: fn error, pipeline ->
        Action.undo()
        pipeline
      end)

      pipeline =
        PipeLine.new()
        |> PipeLine.add_steps([step])

      PipeLine.Step.compensate(step, {:error, :not_found}, pipeline)
  """
  def compensate(%__MODULE__{} = step, error, pipeline) do
    on_error(step).(error, pipeline)
  end

  @doc """
  Returns a new Pipeline.Step with the given action and options. See options below for the
  full list.

  The action will be given the pipeline's state and whatever the action returns will be
  the new pipeline state. An action can be a {module, function, args} tuple or a one arity
  function. They each have tradeoffs, see the section below for a discussion.

  ### Options

    * `on_error: fn error, pipeline -> ... end` - Will be run if the Step's action fails
    The `on_error` function will be given the error from the failing step and the whole
    pipeline and should return a pipeline.

    A pipeline will step through all of the on_error callbacks on each step in a pipeline
    starting with the step that failed and working backward to the first step.

  ### Examples

  ```elixir
  PipeLine.new(1)
  |> PipeLine.add_steps([
    PipeLine.Step(&Add/1),
    PipeLine.Step(fn x -> x + 2 end),
  ])

  pipe_line =
    PipeLine.new(1)
    |> PipeLine.add_steps([
      PipeLine.Step.new({Kernel, :+, [2]})
    ])
  ```

  ### Using MFA tuple as an action

  #### Pros

  Using a tuple of module, function, arguments means it's really easy to create a PipeLine
  and assert on it in tests without running the pipeline. For example you can do this:

  ```elixir
  defmodule Add do
    def two(n), do: n + 2
  end

  pipe_line =
    PipeLine.new(1)
    |> PipeLine.add_steps([
      # we can get rid of PipeLine.Step.new/1 and just iterate through the
      # steps calling it as we go. If we dont the syntax for on_error gets messy though
      # Because it's all a list of lists or a list of tuples basically looks like fucking AST
      PipeLine.Step.new({Add, :two, []})
    ])

  [
    [{Kernel, :+, [2]}, on_error: &MyModule.handle_error/1],
    [{Kernel, :+, [2]}],
    [{Kernel, :+, [2]}, on_error: &MyModule.handle_error/1],
  ]

  assert pipe_line.steps == [ {Add, :two, []} ]
  ```

  This approach also let's you have an action function that accepts more than one argument
  with minimal faff; as the pipeline's state will be passed as the first argument to your
  action:

  ```elixir
  pipe_line =
    PipeLine.new(1)
    |> PipeLine.add_steps([
      PipeLine.Step.new({Kernel, :+, [2]})
    ])

  assert pipe_line.steps == [ {Kernel, :+, [2]} ]
  ```

  #### Cons

  It requires that your function be in a module - ie you can't just use an anonymous fn.
  In reality this might be fine. The syntax is a bit weird to look at.

  ### Using a function as an action

  #### Pros

  You can use anonymous functions. The syntax is a bit nicer:

  ```elixir
  PipeLine.new(1)
  |> PipeLine.add_steps([
    PipeLine.Step(&Add/1),
    PipeLine.Step(fn x -> x + 2 end),
  ])
  ```

  #### Cons

  The major con is it now gets tricky to assert equality between two PipeLines. Which means
  it can be harder to test without actually running the pipeline.

  ```elixir
  defmodule Add do
    def two(n), do: n + 2
  end

  pipe_line =
    PipeLine.new(1)
    |> PipeLine.add_steps([
      PipeLine.Step(&Add/1),
      PipeLine.Step(fn x -> x + 2 end),
    ])

  # What would you put here?
  assert pipe_line.steps == ???
  ```

  You can still test it, but you would have to use mocking if you wanted to not actually
  run the step. If you are happy mocking or not mocking at all then this is a good approach.
  """
  def new(action) do
    new(action, [])
  end

  def new({mod, fun, args}, opts) do
    on_error = on_error_from_opts(opts)

    # Ahh this is still a fun... They would all have to be data structures which is
    # basically AST. The action doesn't have to be a fun it can be the variables we
    # will pass to it eventually. The runner sorts the rest out.

    new_meta_step({mod, fun, [args]}, on_error)
  end



  def new(action, opts) do
    # We can default to ID or make it nil and handle that. Not sure which is quicker.
    on_error = on_error_from_opts(opts)

    action = fn %PipeLine{state: state} = pipeline ->
      %{pipeline | state: action.(state)}
    end
    new_meta_step(action, on_error)
  end

  defp on_error_from_opts(opts) do
 case Keyword.get(opts, :on_error) do
        nil ->
          # The default should be a MFA so we can still assert equality in a test.
          # We should also implement equality for two pipelines and two steps.
          fn _error, pipe_line = %PipeLine{} -> pipeline end

        {m, f, a} when is_list(a) and is_atom(m) and is_atom(f) ->
          {m, f, a}

        fun when is_function(fun, 2) ->
          fun

        otherwise ->
          raise "Invalid on_error action. on_error should be a two airity" <>
                  "fun or a {mod, fun, args} tuple. Given: #{inspect(otherwise)} "
      end
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








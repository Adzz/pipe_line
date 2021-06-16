defmodule PipeLineTest do
  use ExUnit.Case
  doctest PipeLine

  describe "new/1" do
    test "Creates an empty struct with the given state" do
      assert PipeLine.new(%{}) == %PipeLine{state: %{}, steps: {[], []}}
      assert PipeLine.new(1) == %PipeLine{state: 1, steps: {[], []}}
      assert PipeLine.new("1") == %PipeLine{state: "1", steps: {[], []}}
      assert PipeLine.new([]) == %PipeLine{state: [], steps: {[], []}}
      assert PipeLine.new(:a) == %PipeLine{state: :a, steps: {[], []}}
    end
  end

  describe "add_steps/2" do
    test "Appends the given steps to the pipeline" do
      add_one = fn number -> number + 1 end
      add_two = fn n -> n + 2 end
      undo = fn _error, _state -> "some side effect" end

      pipeline =
        PipeLine.new(1)
        |> PipeLine.add_steps([
          add_one,
          {add_two, on_error: undo}
        ])

      assert pipeline.state == 1
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == [on_error: undo]

      pipeline =
        PipeLine.new(%{})
        |> PipeLine.add_steps([
          PipeLine.Step.new(add_one),
          PipeLine.Step.new(add_two, on_error: undo)
        ])

      assert pipeline.state == %{}
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == undo
    end
  end

  describe "add_step/2" do
    test "we can add a step" do
      add_one = fn number -> number + 1 end
      add_two = fn n -> n + 2 end
      undo = fn _error, _state -> "some side effect" end

      pipeline =
        PipeLine.new(%{})
        |> PipeLine.add_step(PipeLine.Step.new(add_one))
        |> PipeLine.add_step(PipeLine.Step.new(add_two, on_error: undo))

      assert pipeline.state == %{}
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == undo
    end

    test "we can pass a function and have steps made for us" do
      add_one = fn number -> number + 1 end
      add_two = fn n -> n + 2 end
      undo = fn _error, _state -> "some side effect" end

      pipeline =
        PipeLine.new(1)
        |> PipeLine.add_step(add_one)
        |> PipeLine.add_step(add_two, on_error: undo)

      assert pipeline.state == 1
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == undo
    end
  end

  describe "execute_while" do
    test "the executor will continue if the state is continue" do
      add_one = fn number -> {:ok, number + 1} end
      add_two = fn n -> {:ok, n + 2} end
      undo = fn _error, _state -> "some side effect" end

      pipeline_result =
        PipeLine.new(1)
        |> PipeLine.add_step(add_one)
        |> PipeLine.add_step(add_two, on_error: undo)
        |> PipeLine.execute_while()

      assert pipeline_result == 3
    end

    test "runs the pipeline" do
      continue_step = fn step ->
        fn state ->
          case step.(state) |> IO.inspect(limit: :infinity, label: "sssssssss") do
            {:ok, stuff} -> {:continue, stuff}
            {:error, stuff} -> {:halt, stuff}
          end
        end
      end

      add_one = fn number -> {:ok, number + 1} end
      add_two = fn n -> {:ok, n + 2} end
      undo = fn _error, _state -> "some side effect" end

      pipeline_result =
        PipeLine.new(1)
        |> PipeLine.add_step(continue_step.(add_one))
        # What's nice about the KW list is that it is extensible, so we could have any status
        # and then any callback associated with that status.
        # on_compensate, on_excepion... etc etc.....
        |> PipeLine.add_step(continue_step.(add_two), on_error: undo)
        # Is this like map. Or reduce? Probs map in some weird way
        # how do we handle the compensates then? They feel like just another pipeline.
        # or perhaps a step that modifies the pipeline.
        |> PipeLine.execute_while()

      assert pipeline_result == 4
    end

    test "when we halt" do
      # logg_step = fn step ->
      #   IO.inspect("b4")
      #   step.()
      # end

      continue_step = fn step ->
        fn state ->
          case step.(state) do
            {:ok, stuff} -> {:continue, stuff}
            {:error, stuff} -> {:halt, stuff}
          end
        end
      end

      add_one = fn number -> {:error, number + 1} end
      add_two = fn n -> {:error, n + 2} end
      undo = fn _error, _state -> "some side effect" end

      pipeline_result =
        PipeLine.new(1)
        |> PipeLine.add_step(continue_step.(add_one))
        |> PipeLine.add_step(continue_step.(add_two), on_error: undo)
        |> PipeLine.execute_while()

      assert pipeline_result == {:halted, 2}
    end
  end
end

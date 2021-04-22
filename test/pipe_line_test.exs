defmodule PipeLineTest do
  use ExUnit.Case
  doctest PipeLine

  describe "new/1" do
    test "Creates an empty struct with the given state" do
      assert PipeLine.new(%{}) == %PipeLine{errors: [], state: %{}, steps: {[], []}, valid?: true}
      assert PipeLine.new(1) == %PipeLine{errors: [], state: 1, steps: {[], []}, valid?: true}
      assert PipeLine.new("1") == %PipeLine{errors: [], state: "1", steps: {[], []}, valid?: true}
      assert PipeLine.new([]) == %PipeLine{errors: [], state: [], steps: {[], []}, valid?: true}
      assert PipeLine.new(:a) == %PipeLine{errors: [], state: :a, steps: {[], []}, valid?: true}
    end
  end

  describe "add_steps/2" do
    test "Appends the given steps to the pipeline" do
      add_one = fn number -> number + 1 end
      add_two = fn n -> n + 2 end
      undo = fn _error, _state -> "some side effect" end

      pipeline = PipeLine.new(1) |> PipeLine.add_steps([add_one, {add_two, undo}])

      assert pipeline.state == 1
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == undo

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
        PipeLine.new(1)
        |> PipeLine.add_step(add_one)
        |> PipeLine.add_step({add_two, undo})

      assert pipeline.state == 1
      {[%PipeLine.Step{} = one_step, %PipeLine.Step{} = two_step], _} = pipeline.steps

      assert one_step.action == add_one
      assert two_step.action == add_two
      assert two_step.on_error == undo

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
  end

  describe "run_while" do
    test "runs the pipeline" do
    end
  end
end

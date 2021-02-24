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

      pipe_line =
        PipeLine.new(%{})
        |> PipeLine.add_steps([PipeLine.Step.new(add_one)])

      assert pipe_line == 1
    end
  end
end

# create_pipeline([
#   # These can all be modules that have behaviour and therefore can be mocks.
#   {add_one, subtract_one},
#   add_two
# ])

# def create_pipeline(steps) do
#   Enum.reduce(steps, PipeLine.new(%{}), fn
#     {step, on_error}, pipe -> PipeLine.add_step(pipe, step)
#     step, pipe ->
#   end)
# end

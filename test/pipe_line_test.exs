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

      # Right so what makes this tricky is that it's now hard to assert on the data structure.
      # because functions don't have identity, meaning we can only assert it is XX function by
      # calling it. Which isn't ideal if we want to like mock tests. SO... what are the alternatives?

      # 1. MFA - enforce mod fun args. Now we can say which fn it is.
      # BUT - cant pass anon fns. Mocking is trickier (as it will be different mfa but because we dont call might be fine)

      # 2. We accept modules that implement a behaviour to become a step. Then you can assert on the Mod
      #    and test and unit test is separately...
      # BUT can't anon fns.
      # Enforces one step per module - do we basically have objects now.
      # overhead of creating dem modules...

      # 3. Create function structs that we can assert on. This is weird though and not normal and
      #    requires caution to avoid the struct drifting from the thing it actually does. obs no

      # we don't want callbacks really, we want promises ? Or like monads are they ? curried fns ?
      # we want to compose their function with ours (which is run it.)

      # These have implications for the userland code. I think 1. is the least bad.

      # assert pipe_line == %PipeLine{errors: [], state: %{}, steps: {[%PipeLine.Step{action: #Function<2.24868623/1 in PipeLine.Step.new/2>, on_error: #Function<1.24868623/2 in PipeLine.Step.new/2>}], []}, valid?: true}
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

defmodule PipeLineTest do
  use ExUnit.Case
  doctest PipeLine

  describe "run_while/1" do
    test "We can run all the steps" do
      PipeLine.new()
      |> PipeLine.add_step(fn %{state: state} -> {:cont, state + 1})

      add_one = %PipeLine.Step{action: fn %{state: state} -> {:cont, state + 1} end}
      pipe_line = %PipeLine{state: 1, steps: [add_one], on_error: & &1}

      assert PipeLine.run_while(pipe_line) == %PipeLine{
               state: 2,
               steps: [add_one],
               on_error: & &1
             }
    end
  end
end

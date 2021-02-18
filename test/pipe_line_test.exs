defmodule PipeLineTest do
  use ExUnit.Case
  doctest PipeLine

  test "greets the world" do
    assert PipeLine.hello() == :world
  end
end

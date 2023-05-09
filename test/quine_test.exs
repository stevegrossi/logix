defmodule QuineTest do
  use ExUnit.Case
  alias Quine.Parser

  doctest Quine

  test "parses sentences" do
    assert {:ok, result, _, _, _, _} = Parser.parse("A")
    assert result == ["A"]
  end

  test "parses negations" do
    assert {:ok, result, _, _, _, _} = Parser.parse("~A")
    assert result == [{:not, "A"}]
  end

  test "parses disjunctions" do
    assert {:ok, result, _, _, _, _} = Parser.parse("AvB")
    assert result == [{:or, ["A", "B"]}]
  end

  test "parses conjunctions" do
    assert {:ok, result, _, _, _, _} = Parser.parse("A^B")
    assert result == [{:and, ["A", "B"]}]
  end

  test "parses implications" do
    assert {:ok, result, _, _, _, _} = Parser.parse("A->B")
    assert result == [{:if, ["A", "B"]}]
  end

  test "parses biconditionals" do
    assert {:ok, result, _, _, _, _} = Parser.parse("A<->B")
    assert result == [{:iff, ["A", "B"]}]
  end

  test "parses groups" do
    assert {:ok, result, _, _, _, _} = Parser.parse("~(A^B)")
    assert result == [{:not, {:and, ["A", "B"]}}]
  end
end

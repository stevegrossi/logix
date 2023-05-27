defmodule Quine.ParserTest do
  use ExUnit.Case
  alias Quine.Parser

  describe "parse/1" do
    test "parses sentences" do
      assert Parser.parse("A") == {:ok, "A"}
    end

    test "parses negations" do
      assert Parser.parse("~A") == {:ok, {:not, ["A"]}}
    end

    test "parses disjunctions" do
      assert Parser.parse("AvB") == {:ok, {:or, ["A", "B"]}}
    end

    test "parses conjunctions" do
      assert Parser.parse("A^B") == {:ok, {:and, ["A", "B"]}}
    end

    test "parses implications" do
      assert Parser.parse("A->B") == {:ok, {:if, ["A", "B"]}}
    end

    test "parses biconditionals" do
      assert Parser.parse("A<->B") == {:ok, {:iff, ["A", "B"]}}
    end

    test "parses groups" do
      assert Parser.parse("(((((A)))))") == {:ok, "A"}
      assert Parser.parse("~(A^B)") == {:ok, {:not, [{:and, ["A", "B"]}]}}
      assert Parser.parse("(A^B)v(C^D)") == {:ok, {:or, [{:and, ["A", "B"]}, {:and, ["C", "D"]}]}}
      assert Parser.parse("(A^B)->~C") == {:ok, {:if, [{:and, ["A", "B"]}, {:not, ["C"]}]}}

      assert Parser.parse("(~A<->(A^B))->~C") ==
               {:ok, {:if, [iff: [not: ["A"], and: ["A", "B"]], not: ["C"]]}}
    end

    test "returns an error tuple for unparseable input" do
      assert Parser.parse("A<->") == {:error, :parse_error}
    end
  end

  describe "print!/1" do
    test "prints parsed expressions" do
      assert Parser.print!("A") == "A"
      assert Parser.print!({:not, ["A"]}) == "~A"
      assert Parser.print!({:not, [{:or, ["A", "B"]}]}) == "~(AvB)"
      assert Parser.print!({:if, ["A", "B"]}) == "A->B"
      assert Parser.print!({:if, [{:and, ["A", "B"]}, {:not, ["C"]}]}) == "(A^B)->~C"
    end
  end
end

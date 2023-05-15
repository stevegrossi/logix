defmodule QuineTest do
  use ExUnit.Case

  doctest Quine

  @tautologies [
    "Av~A",
    "A->A",
    "A<->A",
    "(A->B)<->(Bv~A)",
    "(PvQ)v(~P^~Q)"
  ]

  @contradictions [
    "A^~A",
    "A<->~A",
    "(PvQ)^(~P^~Q)"
  ]

  @contingencies [
    "AvB",
    "A^B",
    "A->B",
    "A<->B"
  ]

  describe "evaluate/2" do
    test "returns the truth-value of an expression given truth values of its sentences" do
      assert Quine.evaluate("A", %{"A" => true}) == true
      assert Quine.evaluate("A", %{"A" => false}) == false

      assert Quine.evaluate("~A", %{"A" => true}) == false
      assert Quine.evaluate("~A", %{"A" => false}) == true

      assert Quine.evaluate("AvB", %{"A" => true, "B" => true}) == true
      assert Quine.evaluate("AvB", %{"A" => true, "B" => false}) == true
      assert Quine.evaluate("AvB", %{"A" => false, "B" => true}) == true
      assert Quine.evaluate("AvB", %{"A" => false, "B" => false}) == false

      assert Quine.evaluate("A^B", %{"A" => true, "B" => true}) == true
      assert Quine.evaluate("A^B", %{"A" => true, "B" => false}) == false
      assert Quine.evaluate("A^B", %{"A" => false, "B" => true}) == false
      assert Quine.evaluate("A^B", %{"A" => false, "B" => false}) == false

      assert Quine.evaluate("A->B", %{"A" => true, "B" => true}) == true
      assert Quine.evaluate("A->B", %{"A" => true, "B" => false}) == false
      assert Quine.evaluate("A->B", %{"A" => false, "B" => true}) == true
      assert Quine.evaluate("A->B", %{"A" => false, "B" => false}) == true

      assert Quine.evaluate("A<->B", %{"A" => true, "B" => true}) == true
      assert Quine.evaluate("A<->B", %{"A" => true, "B" => false}) == false
      assert Quine.evaluate("A<->B", %{"A" => false, "B" => true}) == false
      assert Quine.evaluate("A<->B", %{"A" => false, "B" => false}) == true

      assert Quine.evaluate("~(~(~(A)))", %{"A" => true}) == false

      assert Quine.evaluate("~(A<->(Bv(C^D)))", %{
               "A" => true,
               "B" => true,
               "C" => true,
               "D" => true
             }) == false
    end
  end

  describe "tautology?/1" do
    test "returns true if an expression is always true" do
      Enum.each(@tautologies, &assert(Quine.tautology?(&1)))
    end

    test "returns false for expressions that are only sometimes true" do
      Enum.each(@contingencies, &refute(Quine.tautology?(&1)))
    end

    test "returns false for contradictions" do
      Enum.each(@contradictions, &refute(Quine.tautology?(&1)))
    end
  end

  describe "contradiction?/1" do
    test "returns true for expressions that are never true" do
      Enum.each(@contradictions, &assert(Quine.contradiction?(&1)))
    end

    test "returns false for satisfiable expresions" do
      Enum.each(@contingencies, &refute(Quine.contradiction?(&1)))
    end

    test "returns false for tautologies" do
      Enum.each(@tautologies, &refute(Quine.contradiction?(&1)))
    end
  end

  describe "satisfiable?/1" do
    test "returns true for expressions that are always true" do
      Enum.each(@tautologies, &assert(Quine.satisfiable?(&1)))
    end

    test "returns true for expressions that are sometimes true" do
      Enum.each(@contingencies, &assert(Quine.satisfiable?(&1)))
    end

    test "returns false for expressions that are never true" do
      Enum.each(@contradictions, &refute(Quine.satisfiable?(&1)))
    end
  end

  describe "contingent?/1" do
    test "returns true for expressions that are only sometimes true" do
      Enum.each(@contingencies, &assert(Quine.contingent?(&1)))
    end

    test "returns false for expressions that are always true" do
      Enum.each(@tautologies, &refute(Quine.contingent?(&1)))
    end

    test "returns false for expressions that are never true" do
      Enum.each(@contradictions, &refute(Quine.contingent?(&1)))
    end
  end
end

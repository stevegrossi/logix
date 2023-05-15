defmodule QuineTest do
  use ExUnit.Case

  doctest Quine

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
      assert Quine.tautology?("Av~A")
      assert Quine.tautology?("A->A")
      assert Quine.tautology?("A<->A")
      assert Quine.tautology?("(A->B)<->(Bv~A)")
      assert Quine.tautology?("(PvQ)v(~P^~Q)")
    end

    test "returns false expressions that are only sometimes true" do
      refute Quine.tautology?("A->B")
    end

    test "returns false for contradictions" do
      refute Quine.tautology?("A<->~A")
      refute Quine.tautology?("(PvQ)^(~P^~Q)")
    end
  end

  describe "contradiction?/1" do
    test "returns whether or not an expression is never true" do
      assert Quine.contradiction?("A^~A")
      assert Quine.contradiction?("A<->~A")
      assert Quine.contradiction?("(PvQ)^(~P^~Q)")
    end

    test "returns false for satisfiable expresions" do
      refute Quine.contradiction?("A->B")
    end

    test "returns false for tautologies" do
      refute Quine.contradiction?("(PvQ)v(~P^~Q)")
    end
  end

  describe "satisfiable?/1" do
    test "returns whether or not an expression is true under any circumstances" do
      assert Quine.satisfiable?("A->B")
    end

    test "returns true for tautologies" do
      assert Quine.satisfiable?("A->A")
    end

    test "returns false for contradictions" do
      refute Quine.satisfiable?("A^~A")
    end
  end

  describe "contingent?/1" do
    test "returns whether or not an expression is true under some but not all circumstances" do
      assert Quine.contingent?("A->B")
    end

    test "returns false for tautologies" do
      refute Quine.contingent?("A->A")
    end

    test "returns false for contradictions" do
      refute Quine.contingent?("A^~A")
    end
  end
end

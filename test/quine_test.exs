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

    test "errors for missing truth values" do
      assert_raise ArgumentError, "missing truth value for sentence 'B'", fn ->
        Quine.evaluate("A<->B", %{"A" => true})
      end
    end

    test "errors for non-boolean truth values" do
      assert_raise ArgumentError, "received non-boolean truth value for sentence 'A'", fn ->
        Quine.evaluate("A<->B", %{"A" => 1, "B" => 2})
      end
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

  describe "equivalent?/2" do
    test "returns true if the given expressions have the same truth values" do
      assert Quine.equivalent?("A->B", "~B->~A")
      assert Quine.equivalent?("P->Q", "Qv~P")
      assert Quine.equivalent?("~(~A)", "A")
      assert Quine.equivalent?("AvB", "BvA")
      assert Quine.equivalent?("A^B", "B^A")

      # DeMorgan’s Laws
      assert Quine.equivalent?("~(PvQ)", "~P^~Q")
      assert Quine.equivalent?("~(P^Q)", "~Pv~Q")
    end

    test "returns false if the given expressions do not have the same truth values" do
      refute Quine.equivalent?("A->B", "AvB")
    end
  end

  describe "prove/2" do
    test "proves simple conjunctions" do
      assert Quine.prove(["A", "B"], "A^B") == %{
               1 => {"A", :premise},
               2 => {"B", :premise},
               3 => {"A^B", {:conjunction_introduction, [1, 2]}}
             }
    end

    test "proves simple disjunctions" do
      assert Quine.prove(["A"], "AvB") == %{
               1 => {"A", :premise},
               2 => {"AvB", {:disjunction_introduction, [1]}}
             }
    end

    test "proves by implication elimination" do
      assert Quine.prove(["A", "A->B"], "B") == %{
               1 => {"A", :premise},
               2 => {"A->B", :premise},
               3 => {"B", {:implication_elimination, [1, 2]}}
             }
    end

    test "proves by biconditional elimination" do
      assert Quine.prove(["A", "A<->B"], "B") == %{
               1 => {"A", :premise},
               2 => {"A<->B", :premise},
               3 => {"B", {:biconditional_elimination, [1, 2]}}
             }

      assert Quine.prove(["A", "B<->A"], "B") == %{
               1 => {"A", :premise},
               2 => {"B<->A", :premise},
               3 => {"B", {:biconditional_elimination, [1, 2]}}
             }
    end

    test "proves by conjunction elimination" do
      assert Quine.prove(["A^B"], "A") == %{
               1 => {"A^B", :premise},
               2 => {"A", {:conjunction_elimination, [1]}}
             }

      assert Quine.prove(["A^B"], "B") == %{
               1 => {"A^B", :premise},
               2 => {"B", {:conjunction_elimination, [1]}}
             }
    end

    test "proves by disjunction elimination" do
      assert Quine.prove(["AvB", "A->C", "B->C", "D->C"], "C") == %{
               1 => {"AvB", :premise},
               2 => {"A->C", :premise},
               3 => {"B->C", :premise},
               4 => {"D->C", :premise},
               5 => {"C", {:disjunction_elimination, [1, 2, 3]}}
             }
    end
  end
end

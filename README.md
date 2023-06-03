# Logix

Tools for parsing and working with propositional logic.

## Examples

### Evaluating propositions with given truth values

```elixir
Logix.evaluate("A^B", %{"A" => true, "B" => true})
#=> true

Logix.evaluate("A^B", %{"A" => true, "B" => false})
#=> false
```

### Detecting tautologies and contraditions

```elixir
Logix.tautology?("(A->B)<->(Bv~A)")
#=> true

Logix.tautology?("A->B")
#=> false

Logix.contradtion?("A^~A")
#=> true

Logix.contradtion?("A->B")
#=> false
```

### Detecting Logical Equivalence

```elixir
Logix.equivalent?("A->B", "~B->~A")
#=> true

Logix.equivalent?("A->B", "AvB")
#=> false
```

### Generating Proofs from Assumptions

```elixir
Logix.prove(["A", "BvC", "B->D", "C->D"], "A^D")
#=> {:ok,
#=>   %{
#=>     1 => {"A", :premise},
#=>     2 => {"BvC", :premise},
#=>     3 => {"B->D", :premise},
#=>     4 => {"C->D", :premise},
#=>     5 => {"D", {:disjunction_elimination, [2, 3, 4]}},
#=>     6 => {"A^D", {:conjunction_introduction, [1, 5]}}
#=>   }}

Logix.prove(["A"], "B")
#=> {:error, :proof_failed}
```

## Addenda

### The Rules of Logical Inference

#### Implication Introduction

If you assume "X" and then prove "Y", you can now use "X -> Y" outside of the assumption's scope.

#### Implication Elimination

If you have "X" and you have "X -> Y", then you're entitled to "Y".

#### Disjunction Introduction

If you have "X", then you're entitled to "X v Y".

#### Disjunction Elimination

If you have "X v Y", "X -> Z", and "Y -> Z", then you're entitled to Z.

#### Conjunction Introduction

If you have "X" and you have "Y", you're entitled to "X ^ Y"

#### Conjunction Elimination

If you have "X ^ Y", then you're entitled to both "X" and "Y".

#### Biconditional Introduction

If you have "X -> Y" and also "Y -> X", then you're entitled to "X <-> Y".

#### Biconditional Elimination

If you have "X <-> Y" and you have "X", then you're entitled to "Y", and if you have "Y" then you're entitled to "X".

#### Negation Introduction

This rule requires you to prove something within the scope of an assumption. If you assume "X" and you can prove both "Y" and "~Y", then you're entitled to "~X" outside the scope of that assumption.

#### Negation Elimination

Likewise, if you assume "~X" and you can prove both "Y" and "~Y", then you're entitled to "X" outside the scope of that assumption.

### Strategies for Proving Kinds of Statements

- **any**: Negation Elimination, Implication Elimination, Disjunction Elimination, Conjunction Elimination, Biconditional Elimination
- **negation**: Negation Introduction, any
- **disjunction**: Disjunction Introduction, any
- **conjunction**: Conjunction Introduction, any
- **implication**: Implication Introduction, any
- **biconditional**: Biconditional Introduction, any

### TODO
- [ ] Implement the proof-by-assumption strategies: implication introduction, negation introduction, and negation elimination
- [ ] Could things be simpler if sentences were tagged? e.g. `{:sentence, "A"}` instead of bare strings
- [ ] Derive logical truths (i.e. `A->A`, `B v ~B`) from 0 assumptions
- [ ] Graduate to predicate logic

### Inspiration

- [Mathematical Logic Through Python](https://www.logicthrupython.org/)
- https://people.cs.pitt.edu/~milos/courses/cs441/lectures/Class2.pdf
- [An online theorem prover](http://teachinglogic.liglab.fr/DN/index.php?formula=p+%26+%28q+%2B+r%29+%3C%3D%3E+%28p+%26+q%29+%2B+%28p+%26+r%29&action=Prove+Formula), the closest (and only) example I've been able to find of software that does what Logix sets out to do
- [A logical theorem-prover for first-order (predicate) logic](https://github.com/stepchowfun/theorem-prover) written in Python (first-order logic is an extension of propositional logic)

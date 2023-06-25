defmodule Logix.Proof do
  @moduledoc """
  This module is responsible for generating logical proofs as represented by its struct.
  Proof structs operate on parsed expressions which they expect to be intialized with. To convert
  a Proof to more human-readable unparsed expressions, see format/1.
  """

  @enforce_keys ~w[premises conclusion steps next_step attempted]a
  defstruct @enforce_keys

  alias Logix.Parser

  @failure {:error, :proof_failed}
  @type t :: %__MODULE__{
          premises: [statement()],
          conclusion: statement(),
          steps: steps(),
          next_step: pos_integer(),
          attempted: []
        }
  @type steps :: %{step_number() => step()}
  @type step :: {step_number(), {statement(), justification()}}
  @type step_number :: pos_integer()
  @type operator :: :not | :or | :and | :if | :iff
  @type statement :: String.t() | {operator(), [statement()]}
  @type justification :: :premise | {rule(), [step_number()]}
  @type rule ::
          :biconditional_elimination
          | :biconditional_introduction
          | :conjunction_elimination
          | :conjunction_introduction
          | :disjunction_elimination
          | :disjunction_introduction
          | :implication_elimination
          | :implication_introduction
          | :negation_elimination
          | :negation_introduction
  @type failure :: {:error, :proof_failed}
  @type result :: steps() | failure()

  @spec new([statement()], statement()) :: t()
  def new(premises, conclusion) do
    initialize_steps(%__MODULE__{
      premises: premises,
      conclusion: conclusion,
      steps: %{},
      next_step: 1,
      attempted: []
    })
  end

  @spec prove(t()) :: {:ok, t()} | failure()
  def prove(proof), do: prove(proof, proof.conclusion)

  @spec prove(t(), term()) :: {:ok, t()} | failure()
  defp prove(proof, conclusion) do
    cond do
      conclusion in proof.attempted ->
        # Don’t try to prove the same conlusion twice. This avoids infinite loops.
        @failure

      not is_nil(justification_for(proof, conclusion)) ->
        # No need to prove something that’s already been derived.
        {:ok, proof}

      true ->
        proof = Map.update!(proof, :attempted, &[conclusion | &1])

        if justification_for(proof, conclusion) do
          {:ok, proof}
        else
          try_implication_elimination(proof, conclusion) ||
            try_conjunction_elimination(proof, conclusion) ||
            try_disjunction_elimination(proof, conclusion) ||
            try_biconditional_elimination(proof, conclusion) ||
            try_conjunction_introduction(proof, conclusion) ||
            try_disjunction_introduction(proof, conclusion) ||
            try_biconditional_introduction(proof, conclusion) ||
            try_implication_introduction(proof, conclusion) ||
            try_negation_introduction(proof, conclusion) ||
            try_negation_elimination(proof, conclusion) ||
            @failure
        end
    end
  end

  @spec prove_many(t(), [statement()]) :: {:ok, t()} | failure()
  defp prove_many(proof, conclusions) do
    Enum.reduce(conclusions, {:ok, proof}, fn
      conclusion, {:ok, proof} -> prove(proof, conclusion)
      _conclusion, @failure -> @failure
    end)
  end

  @spec format(t()) :: steps()
  def format(proof) do
    Map.new(proof.steps, fn {step, {statement, justification}} ->
      {step, {Parser.print!(statement), justification}}
    end)
  end

  @spec initialize_steps(t()) :: t()
  defp initialize_steps(proof) do
    steps =
      proof.premises
      |> Enum.with_index(1)
      |> Map.new(fn {premise, index} -> {index, {premise, :premise}} end)

    Map.merge(proof, %{steps: steps, next_step: map_size(steps) + 1})
  end

  @spec try_conjunction_introduction(t(), statement()) :: {:ok, t()} | nil
  defp try_conjunction_introduction(proof, {:and, [left, right]} = conclusion) do
    with {:ok, proof} <- prove(proof, left),
         {:ok, proof} <- prove(proof, right) do
      {step_proving_left, _} = justification_for(proof, left)
      {step_proving_right, _} = justification_for(proof, right)

      conclude(proof, conclusion, :conjunction_introduction, [
        step_proving_left,
        step_proving_right
      ])
    else
      _ -> nil
    end
  end

  defp try_conjunction_introduction(_, _), do: nil

  @spec try_disjunction_introduction(t(), statement()) :: {:ok, t()} | nil
  defp try_disjunction_introduction(proof, {:or, [left, right]} = conclusion) do
    case prove(proof, left) do
      {:ok, proof} ->
        {step_proving_left, _} = justification_for(proof, left)
        conclude(proof, conclusion, :disjunction_introduction, [step_proving_left])

      @failure ->
        case prove(proof, right) do
          {:ok, proof} ->
            {step_proving_right, _} = justification_for(proof, right)

            conclude(proof, conclusion, :disjunction_introduction, [step_proving_right])

          @failure ->
            nil
        end
    end
  end

  defp try_disjunction_introduction(_, _), do: nil

  @spec try_biconditional_introduction(t(), statement()) :: {:ok, t()} | nil
  defp try_biconditional_introduction(proof, {:iff, [left, right]} = conclusion) do
    with {:ok, proof} <- prove(proof, {:if, [left, right]}),
         {:ok, proof} <- prove(proof, {:if, [right, left]}) do
      {left_implying_right, _} = justification_for(proof, {:if, [left, right]})
      {right_implying_left, _} = justification_for(proof, {:if, [right, left]})

      conclude(proof, conclusion, :biconditional_introduction, [
        left_implying_right,
        right_implying_left
      ])
    else
      _ -> nil
    end
  end

  defp try_biconditional_introduction(_, _), do: nil

  @spec try_conjunction_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_conjunction_elimination(proof, conclusion) do
    with {_, {statement_with_conjunction, _reason}} <-
           find_step_including_conjunct(proof, conclusion),
         {:and, _} = conjunction <-
           find_anywhere(statement_with_conjunction, &conjunction_of(&1, conclusion)),
         {:ok, proof} <- prove(proof, conjunction) do
      {step, _} = justification_for(proof, conjunction)
      conclude(proof, conclusion, :conjunction_elimination, [step])
    else
      _ -> nil
    end
  end

  @spec find_step_including_conjunct(t(), statement()) :: step() | nil
  defp find_step_including_conjunct(proof, conclusion) do
    Enum.find(proof.steps, fn {_step, {statement, _reason}} ->
      find_anywhere(statement, &conjunction_of(&1, conclusion))
    end)
  end

  @spec try_disjunction_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_disjunction_elimination(proof, conclusion) do
    with [_ | [_ | _]] = implication_steps <- find_implications_concluding(proof, conclusion),
         antecedents <- list_antecedents_for(implication_steps, conclusion),
         {_step_with_disjunction, {statement_with_disjunction, _just}} <-
           find_disjunction_including(proof, antecedents),
         {:or, disjuncts} = disjunction <-
           find_anywhere(statement_with_disjunction, &disjunction_of(&1, antecedents)),
         {:ok, proof} <- prove(proof, disjunction),
         implications <- Enum.map(disjuncts, &{:if, [&1, conclusion]}),
         {:ok, proof} <- prove_many(proof, implications),
         relevant_implication_steps <- Enum.map(implications, &justification_for(proof, &1)),
         relevant_implication_step_numbers <-
           Enum.map(relevant_implication_steps, &step_number(&1)),
         {disjunction_step, _} <- justification_for(proof, disjunction) do
      conclude(
        proof,
        conclusion,
        :disjunction_elimination,
        relevant_implication_step_numbers ++ [disjunction_step]
      )
    else
      _ -> nil
    end
  end

  @spec step_number(step()) :: step_number()
  defp step_number({step_num, _} = _step), do: step_num

  @spec list_antecedents_for([step()], statement()) :: list()
  defp list_antecedents_for(steps_with_implications, consequent) do
    Enum.map(steps_with_implications, fn {_step, {statement, _just}} ->
      statement
      |> find_anywhere(&implication_of(&1, consequent))
      |> other_operand(consequent)
    end)
  end

  @spec find_disjunction_including(t(), [statement()]) :: step() | nil
  defp find_disjunction_including(proof, statements) do
    Enum.find(proof.steps, fn {_step, {statement, _reason}} ->
      find_anywhere(statement, &disjunction_of(&1, statements))
    end)
  end

  @spec try_implication_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_implication_elimination(proof, conclusion) do
    with {_step, {statement_containing_implication, _just}} <-
           find_step_including_implication_of(proof, conclusion),
         {:if, _} = implication_implying_conclusion <-
           find_anywhere(statement_containing_implication, &implication_of(&1, conclusion)),
         antecedent <- other_operand(implication_implying_conclusion, conclusion),
         {:ok, proof} <- prove(proof, antecedent),
         {:ok, proof} <- prove(proof, implication_implying_conclusion),
         {step_implying_conclusion, _} <-
           justification_for(proof, implication_implying_conclusion),
         {step_justifying_antecedent, _} <- justification_for(proof, antecedent) do
      conclude(proof, conclusion, :implication_elimination, [
        step_implying_conclusion,
        step_justifying_antecedent
      ])
    else
      _ -> nil
    end
  end

  @spec find_step_including_implication_of(t(), statement()) :: step() | nil
  defp find_step_including_implication_of(proof, conclusion) do
    Enum.find(proof.steps, fn {_step, {statement, _reason}} ->
      find_anywhere(statement, &implication_of(&1, conclusion))
    end)
  end

  defp find_anywhere(statement, _match_fn) when is_binary(statement), do: nil

  defp find_anywhere({_operator, operands} = statement, match_fn) do
    match_fn.(statement) || Enum.find_value(operands, &find_anywhere(&1, match_fn))
  end

  @spec try_biconditional_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_biconditional_elimination(proof, conclusion) do
    with {_step, {statement_with_biconditional, _just}} <-
           find_step_including_biconditional_of(proof, conclusion),
         {:iff, _} = biconditional_implying_conclusion <-
           find_anywhere(statement_with_biconditional, &biconditional_of(&1, conclusion)),
         other_side <- other_operand(biconditional_implying_conclusion, conclusion),
         {:ok, proof} <- prove(proof, other_side),
         {:ok, proof} <- prove(proof, biconditional_implying_conclusion),
         {step_implying_conclusion, _} <-
           justification_for(proof, biconditional_implying_conclusion),
         {step_justifying_other_side, _} <- justification_for(proof, other_side) do
      conclude(proof, conclusion, :biconditional_elimination, [
        step_justifying_other_side,
        step_implying_conclusion
      ])
    else
      _ -> nil
    end
  end

  @spec try_implication_introduction(t(), statement()) :: {:ok, t()} | nil
  defp try_implication_introduction(proof, {:if, [antecedent, consequent]} = conclusion) do
    with {:ok, proof} <- assume(proof, antecedent),
         {:ok, proof} <- prove(proof, consequent),
         {assumption_line, _} = justification_for(proof, antecedent),
         {consequent_line, _} <- justification_for(proof, consequent) do
      conclude(proof, conclusion, :implication_introduction, [
        assumption_line,
        consequent_line
      ])
    else
      _ -> nil
    end
  end

  defp try_implication_introduction(_proof, _), do: nil

  @spec try_negation_introduction(t(), statement()) :: {:ok, t()} | nil
  defp try_negation_introduction(proof, {:not, [statement]} = conclusion) do
    with {:ok, proof} <- assume(proof, statement),
         sentence when is_binary(sentence) <- find_first_sentence(proof),
         {:ok, proof} <- prove(proof, {:and, [sentence, {:not, [sentence]}]}),
         {assumption_line, _} <- justification_for(proof, statement),
         {contradiction_line, _} <-
           justification_for(proof, {:and, [sentence, {:not, [sentence]}]}) do
      conclude(proof, conclusion, :negation_introduction, [
        assumption_line,
        contradiction_line
      ])
    else
      _ -> nil
    end
  end

  defp try_negation_introduction(_proof, _), do: nil

  @spec try_negation_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_negation_elimination(proof, conclusion) do
    with {:ok, proof} <- assume(proof, {:not, [conclusion]}),
         sentence when is_binary(sentence) <- find_first_sentence(proof),
         {:ok, proof} <- prove(proof, {:and, [sentence, {:not, [sentence]}]}),
         {assumption_line, _} <- justification_for(proof, {:not, [conclusion]}),
         {contradiction_line, _} <-
           justification_for(proof, {:and, [sentence, {:not, [sentence]}]}) do
      conclude(proof, conclusion, :negation_elimination, [
        assumption_line,
        contradiction_line
      ])
    else
      _ -> nil
    end
  end

  defp find_first_sentence(proof) do
    Enum.find_value(proof.steps, fn {_step, {statement, _reason}} ->
      if is_binary(statement), do: statement
    end)
  end

  @spec other_operand(statement(), statement()) :: statement()
  defp other_operand({_operator, [other, given]}, given), do: other
  defp other_operand({_operator, [given, other]}, given), do: other
  defp other_operand(_, _), do: nil

  @spec find_step_including_biconditional_of(t(), statement()) :: step() | nil
  defp find_step_including_biconditional_of(proof, conclusion) do
    Enum.find(proof.steps, fn {_step, {statement, _reason}} ->
      find_anywhere(statement, &biconditional_of(&1, conclusion))
    end)
  end

  @spec justification_for(t(), statement()) :: step() | nil
  defp justification_for(proof, conclusion) do
    Enum.find(proof.steps, fn {_step, {result, _just}} ->
      result == conclusion
    end)
  end

  defp find_implications_concluding(proof, conclusion) do
    Enum.filter(proof.steps, fn {_step, {statement, _reason}} ->
      not is_nil(find_anywhere(statement, &implication_of(&1, conclusion)))
    end)
  end

  @spec conclude(t(), statement(), rule(), [step_number()]) :: {:ok, t()}
  defp conclude(proof, conclusion, rule, justifications) do
    {:ok,
     proof
     |> Map.put(:next_step, proof.next_step + 1)
     |> Map.update!(:steps, fn steps ->
       Map.put(steps, proof.next_step, {conclusion, {rule, Enum.sort(justifications)}})
     end)}
  end

  @spec assume(t(), statement()) :: {:ok, t()}
  defp assume(proof, assumption) do
    {:ok,
     proof
     |> Map.put(:next_step, proof.next_step + 1)
     |> Map.update!(:steps, fn steps ->
       Map.put(steps, proof.next_step, {assumption, :assumption})
     end)}
  end

  ## MATCHERS

  @spec disjunction_of(statement(), [statement()]) :: statement() | nil
  defp disjunction_of({:or, [left, right]} = disjunction, statements) when is_list(statements) do
    if left in statements and right in statements, do: disjunction
  end

  defp disjunction_of(_, _), do: nil

  @spec conjunction_of(statement(), statement()) :: statement() | nil
  defp conjunction_of({:and, [conclusion, _]} = conjunction, conclusion), do: conjunction
  defp conjunction_of({:and, [_, conclusion]} = conjunction, conclusion), do: conjunction
  defp conjunction_of(_, _), do: nil

  @spec implication_of(statement(), statement()) :: statement() | nil
  defp implication_of({:if, [_antecedent, conclusion]} = implication, conclusion), do: implication
  defp implication_of(_, _), do: nil

  @spec biconditional_of(statement(), statement()) :: statement() | nil
  defp biconditional_of({:iff, [conclusion, _]} = biconditional, conclusion), do: biconditional
  defp biconditional_of({:iff, [_, conclusion]} = biconditional, conclusion), do: biconditional
  defp biconditional_of(_, _), do: nil
end

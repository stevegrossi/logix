defmodule Logix.Proof do
  @moduledoc """
  This module is responsible for generating logical proofs as represented by its struct.
  Proof structs operate on parsed expressions which they expect to be intialized with. To convert
  a Proof to more human-readable unparsed expressions, see format/1.
  """

  @enforce_keys ~w[premises conclusion steps next_step]a
  defstruct @enforce_keys

  alias Logix.Parser

  @failure {:error, :proof_failed}
  @type t :: %__MODULE__{
          premises: [statement()],
          conclusion: statement(),
          steps: steps(),
          next_step: pos_integer()
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
  @type failure :: {:error, :proof_failed}
  @type result :: steps() | failure()

  @spec new([statement()], statement()) :: t()
  def new(premises, conclusion) do
    initialize_steps(%__MODULE__{
      premises: premises,
      conclusion: conclusion,
      steps: %{},
      next_step: 1
    })
  end

  @spec prove(t()) :: {:ok, t()} | failure()
  def prove(proof), do: prove(proof, proof.conclusion)

  @spec prove(t(), term()) :: {:ok, t()} | failure()
  defp prove(proof, conclusion) do
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
        @failure
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
      {line_proving_left, _} = justification_for(proof, left)
      {line_proving_right, _} = justification_for(proof, right)

      conclude(proof, conclusion, :conjunction_introduction, [
        line_proving_left,
        line_proving_right
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
        {line_proving_left, _} = justification_for(proof, left)
        conclude(proof, conclusion, :disjunction_introduction, [line_proving_left])

      @failure ->
        case prove(proof, right) do
          {:ok, proof} ->
            {line_proving_right, _} = justification_for(proof, right)

            conclude(proof, conclusion, :disjunction_introduction, [line_proving_right])

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
           find_line_including_conjunct(proof, conclusion),
         {:and, _} = conjunction <-
           find_anywhere(statement_with_conjunction, &conjunction_of(&1, conclusion)),
         {:ok, proof} <- prove(proof, conjunction) do
      {line, _} = justification_for(proof, conjunction)
      conclude(proof, conclusion, :conjunction_elimination, [line])
    else
      _ -> nil
    end
  end

  @spec find_line_including_conjunct(t(), statement()) :: step() | nil
  defp find_line_including_conjunct(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      find_anywhere(statement, &conjunction_of(&1, conclusion))
    end)
  end

  @spec try_disjunction_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_disjunction_elimination(proof, conclusion) do
    with [_ | [_ | _]] = implication_lines <- find_implications_concluding(proof, conclusion),
         antecedents <- list_antecedents_for(implication_lines, conclusion),
         {_line_with_disjunction, {statement_with_disjunction, _just}} <-
           find_disjunction_including(proof, antecedents),
         {:or, disjuncts} = disjunction <-
           find_anywhere(statement_with_disjunction, &disjunction_of(&1, antecedents)),
         {:ok, proof} <- prove(proof, disjunction),
         implications <- Enum.map(disjuncts, &{:if, [&1, conclusion]}),
         {:ok, proof} <- prove_many(proof, implications),
         relevant_implication_lines <- Enum.map(implications, &justification_for(proof, &1)),
         relevant_implication_step_numbers <-
           Enum.map(relevant_implication_lines, &step_number(&1)),
         {disjunction_line, _} <- justification_for(proof, disjunction) do
      conclude(
        proof,
        conclusion,
        :disjunction_elimination,
        relevant_implication_step_numbers ++ [disjunction_line]
      )
    else
      _ -> nil
    end
  end

  @spec step_number(step()) :: step_number()
  defp step_number({line_num, _} = _line), do: line_num

  @spec list_antecedents_for([step()], statement()) :: list()
  defp list_antecedents_for(lines_with_implications, consequent) do
    Enum.map(lines_with_implications, fn {_step, {statement, _just}} ->
      statement
      |> find_anywhere(&implication_of(&1, consequent))
      |> other_operand(consequent)
    end)
  end

  @spec find_disjunction_including(t(), [statement()]) :: step() | nil
  defp find_disjunction_including(proof, statements) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      find_anywhere(statement, &disjunction_of(&1, statements))
    end)
  end

  @spec try_implication_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_implication_elimination(proof, conclusion) do
    with {_line, {statement_containing_implication, _just}} <-
           find_line_including_implication_of(proof, conclusion),
         {:if, _} = implication_implying_conclusion <-
           find_anywhere(statement_containing_implication, &implication_of(&1, conclusion)),
         antecedent <- other_operand(implication_implying_conclusion, conclusion),
         {:ok, proof} <- prove(proof, antecedent),
         {:ok, proof} <- prove(proof, implication_implying_conclusion),
         {line_implying_conclusion, _} <-
           justification_for(proof, implication_implying_conclusion),
         {line_justifying_antecedent, _} <- justification_for(proof, antecedent) do
      conclude(proof, conclusion, :implication_elimination, [
        line_implying_conclusion,
        line_justifying_antecedent
      ])
    else
      _ -> nil
    end
  end

  @spec find_line_including_implication_of(t(), statement()) :: step() | nil
  defp find_line_including_implication_of(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      find_anywhere(statement, &implication_of(&1, conclusion))
    end)
  end

  defp find_anywhere(statement, _match_fn) when is_binary(statement), do: nil

  defp find_anywhere({_operator, operands} = statement, match_fn) do
    match_fn.(statement) || Enum.find_value(operands, &find_anywhere(&1, match_fn))
  end

  @spec try_biconditional_elimination(t(), statement()) :: {:ok, t()} | nil
  defp try_biconditional_elimination(proof, conclusion) do
    with {_line, {statement_with_biconditional, _just}} <-
           find_line_including_biconditional_of(proof, conclusion),
         {:iff, _} = biconditional_implying_conclusion <-
           find_anywhere(statement_with_biconditional, &biconditional_of(&1, conclusion)),
         other_side <- other_operand(biconditional_implying_conclusion, conclusion),
         {:ok, proof} <- prove(proof, other_side),
         {:ok, proof} <- prove(proof, biconditional_implying_conclusion),
         {line_implying_conclusion, _} <-
           justification_for(proof, biconditional_implying_conclusion),
         {line_justifying_other_side, _} <- justification_for(proof, other_side) do
      conclude(proof, conclusion, :biconditional_elimination, [
        line_justifying_other_side,
        line_implying_conclusion
      ])
    else
      _ -> nil
    end
  end

  @spec other_operand(statement(), statement()) :: statement()
  defp other_operand({_operator, [other, given]}, given), do: other
  defp other_operand({_operator, [given, other]}, given), do: other
  defp other_operand(_, _), do: nil

  @spec find_line_including_biconditional_of(t(), statement()) :: step() | nil
  defp find_line_including_biconditional_of(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      find_anywhere(statement, &biconditional_of(&1, conclusion))
    end)
  end

  @spec justification_for(t(), statement()) :: step() | nil
  defp justification_for(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {result, _just}} ->
      result == conclusion
    end)
  end

  defp find_implications_concluding(proof, conclusion) do
    Enum.filter(proof.steps, fn {_line, {statement, _reason}} ->
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

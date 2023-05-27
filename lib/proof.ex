defmodule Quine.Proof do
  @moduledoc """
  This module is responsible for generating logical proofs as represented by its struct.
  Proof structs operate on parsed expressions which they expect to be intialized with. To convert
  a Proof to more human-readable unparsed expressions, see format/1.
  """

  @enforce_keys ~w[premises conclusion steps next_step]a
  defstruct @enforce_keys

  alias Quine.Parser

  @failure {:error, :proof_failed}
  @type t :: %__MODULE__{}
  @type failure :: {:error, :proof_failed}

  @spec new(list(), term()) :: t()
  def new(premises, conclusion) do
    initialize_steps(%__MODULE__{
      premises: premises,
      conclusion: conclusion,
      steps: [],
      next_step: 0
    })
  end

  @spec prove(t()) :: {:ok, t()} | failure()
  def prove(proof), do: prove(proof, proof.conclusion)

  @spec prove(t(), term()) :: {:ok, t()} | failure()
  defp prove(proof, conclusion) do
    if evidence_for(proof, conclusion) do
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

  @spec format(t()) :: map()
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

  @spec try_conjunction_introduction(t(), any()) :: {:ok, t()} | nil
  defp try_conjunction_introduction(proof, {:and, [left, right]} = conclusion) do
    with {:ok, proof} <- prove(proof, left),
         {:ok, proof} <- prove(proof, right) do
      {line_proving_left, _} = evidence_for(proof, left)
      {line_proving_right, _} = evidence_for(proof, right)

      {:ok,
       conclude(proof, conclusion, :conjunction_introduction, [
         line_proving_left,
         line_proving_right
       ])}
    end
  end

  defp try_conjunction_introduction(_, _), do: nil

  @spec try_disjunction_introduction(t(), any()) :: {:ok, t()} | nil
  defp try_disjunction_introduction(proof, {:or, [left, right]} = conclusion) do
    case prove(proof, left) do
      {:ok, proof} ->
        {line_proving_left, _} = evidence_for(proof, left)
        {:ok, conclude(proof, conclusion, :disjunction_introduction, [line_proving_left])}

      @failure ->
        case prove(proof, right) do
          {:ok, proof} ->
            {line_proving_right, _} = evidence_for(proof, right)

            {:ok, conclude(proof, conclusion, :disjunction_introduction, [line_proving_right])}

          @failure ->
            nil
        end
    end
  end

  defp try_disjunction_introduction(_, _), do: nil

  @spec try_biconditional_introduction(t(), any()) :: {:ok, t()} | nil
  defp try_biconditional_introduction(proof, {:iff, [left, right]} = conclusion) do
    with {:ok, proof} <- prove(proof, {:if, [left, right]}),
         {:ok, proof} <- prove(proof, {:if, [right, left]}) do
      {left_implying_right, _} = evidence_for(proof, {:if, [left, right]})
      {right_implying_left, _} = evidence_for(proof, {:if, [right, left]})

      {:ok,
       conclude(proof, conclusion, :biconditional_introduction, [
         left_implying_right,
         right_implying_left
       ])}
    end
  end

  defp try_biconditional_introduction(_, _), do: nil

  @spec try_conjunction_elimination(t(), any()) :: {:ok, t()} | nil
  defp try_conjunction_elimination(proof, conclusion) do
    case find_line_including_conjunct(proof, conclusion) do
      {_, {statement_with_conjunction, _reason}} ->
        conjunction = find_conjunction_anywhere(statement_with_conjunction, conclusion)

        case prove(proof, conjunction) do
          {:ok, proof} ->
            {line, _} = evidence_for(proof, conjunction)
            {:ok, conclude(proof, conclusion, :conjunction_elimination, [line])}

          @failure ->
            nil
        end

      nil ->
        nil
    end
  end

  # defp find_anywhere(expression, expression), do: expression
  # defp find_anywhere(expression, _) when is_binary(expression), do: nil

  # defp find_anywhere({_op, factors}, expression) do
  #   # Negations don't have a list as their second tuple element (yet)
  #   Enum.find(factors, &find_anywhere(&1, expression))
  # end

  @spec find_conjunction_anywhere(binary | {any, any}, any) :: any
  defp find_conjunction_anywhere(statement, _conclusion) when is_binary(statement), do: nil

  defp find_conjunction_anywhere({:and, conjuncts} = statement, conclusion) do
    # TODO: shouldn't fail before checking other conjunctions?
    if conclusion in conjuncts, do: statement
  end

  defp find_conjunction_anywhere({_operator, conjuncts}, conclusion) do
    Enum.find(conjuncts, &find_conjunction_anywhere(&1, conclusion))
  end

  defp find_line_including_conjunct(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      find_conjunction_anywhere(statement, conclusion)
    end)
  end

  @spec try_disjunction_elimination(t(), any()) :: {:ok, t()} | nil
  defp try_disjunction_elimination(proof, conclusion) do
    with [_ | [_ | _]] = implication_lines <- find_implications_concluding(proof, conclusion),
         antecedents <- list_antecedents(implication_lines),
         disjunction <- find_disjunction_including(proof, antecedents) do
      {disjunction_line, {{:or, disjuncts}, _just}} = disjunction
      # we first filter implication_lines by the ones in the disjunction
      relevant_implication_lines =
        implication_lines
        |> Enum.filter(fn implication_line ->
          {_line, {{:if, [antecedent, _consequent]}, _just}} = implication_line
          antecedent in disjuncts
        end)
        |> Enum.map(&elem(&1, 0))

      {:ok,
       conclude(
         proof,
         conclusion,
         :disjunction_elimination,
         relevant_implication_lines ++ [disjunction_line]
       )}
    else
      _ -> nil
    end
  end

  defp list_antecedents(implication_lines) do
    Enum.map(implication_lines, fn {_line_num, {{:if, [antecedent, _conclusion]}, _just}} ->
      antecedent
    end)
  end

  defp find_disjunction_including(proof, statements) do
    Enum.find(proof.steps, fn {_line_num, {statement, _just}} ->
      case statement do
        {:or, [left, right]} ->
          left in statements and right in statements

        _ ->
          nil
      end
    end)
  end

  @spec try_implication_elimination(t(), any()) :: {:ok, t()} | nil
  defp try_implication_elimination(proof, conclusion) do
    case find_implication_concluding(proof, conclusion) do
      {line_implying_conclusion, {implication, _just}} ->
        {:if, [antecedent, ^conclusion]} = implication

        case prove(proof, antecedent) do
          {:ok, proof} ->
            {line, _} = evidence_for(proof, antecedent)

            {:ok,
             conclude(proof, conclusion, :implication_elimination, [
               line,
               line_implying_conclusion
             ])}

          @failure ->
            nil
        end

      nil ->
        nil
    end
  end

  @spec try_biconditional_elimination(t(), any()) :: {:ok, t()} | nil
  defp try_biconditional_elimination(proof, conclusion) do
    case find_biconditional_including(proof, conclusion) do
      {line_implying_conclusion, {biconditional_implying_conclusion, _just}} ->
        needed =
          case biconditional_implying_conclusion do
            {:iff, [left, ^conclusion]} -> left
            {:iff, [^conclusion, right]} -> right
          end

        case prove(proof, needed) do
          {:ok, proof} ->
            {line, _} = evidence_for(proof, needed)

            {:ok,
             conclude(proof, conclusion, :biconditional_elimination, [
               line,
               line_implying_conclusion
             ])}

          @failure ->
            nil
        end

      nil ->
        nil
    end
  end

  defp find_biconditional_including(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _just}} ->
      case statement do
        {:iff, [_left, ^conclusion]} -> true
        {:iff, [^conclusion, _right]} -> true
        _ -> false
      end
    end)
  end

  defp evidence_for(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {result, _just}} ->
      result == conclusion
    end)
  end

  defp find_implication_concluding(proof, conclusion) do
    case find_implications_concluding(proof, conclusion) do
      [] -> nil
      [first | _] -> first
    end
  end

  defp find_implications_concluding(proof, conclusion) do
    Enum.filter(proof.steps, fn {_line, {statement, _just}} ->
      case statement do
        {:if, [_antecedent, ^conclusion]} -> true
        _ -> false
      end
    end)
  end

  defp conclude(proof, conclusion, rule, justifications) do
    proof
    |> Map.put(:next_step, proof.next_step + 1)
    |> Map.update!(:steps, fn steps ->
      Map.put(steps, proof.next_step, {conclusion, {rule, Enum.sort(justifications)}})
    end)
  end
end

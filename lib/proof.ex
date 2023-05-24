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

  def new(premises, conclusion) do
    initialize_steps(%__MODULE__{
      premises: premises,
      conclusion: conclusion,
      steps: [],
      next_step: 0
    })
  end

  def prove(proof), do: prove(proof, proof.conclusion)

  def prove(proof, conclusion) do
    case conclusion do
      sentence when is_binary(sentence) -> prove_by_elimination(proof, sentence)
      {:and, _} -> prove_conjunction(proof, conclusion)
      {:or, _} -> prove_disjunction(proof, conclusion)
      _ -> @failure
    end
  end

  def format(proof) do
    Map.new(proof.steps, fn {step, {statement, reason}} ->
      {step, {Parser.print!(statement), reason}}
    end)
  end

  defp initialize_steps(proof) do
    steps =
      proof.premises
      |> Enum.with_index(1)
      |> Map.new(fn {premise, index} -> {index, {premise, :premise}} end)

    Map.merge(proof, %{steps: steps, next_step: map_size(steps) + 1})
  end

  defp prove_conjunction(proof, {:and, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    if line_proving_left && line_proving_right do
      {:ok,
       add_line(
         proof,
         {conclusion,
          {:conjunction_introduction, [elem(line_proving_left, 0), elem(line_proving_right, 0)]}}
       )}
    else
      @failure
    end
  end

  defp prove_disjunction(proof, {:or, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    case line_proving_left || line_proving_right do
      nil ->
        @failure

      {line, _} ->
        {:ok, add_line(proof, {conclusion, {:disjunction_introduction, [line]}})}
    end
  end

  defp prove_by_elimination(proof, conclusion) when is_binary(conclusion) do
    # TRY:
    # Negation Elimination
    # ✅ Implication Elimination
    # ✅ Disjunction Elimination
    # ✅ Conjunction Elimination
    # ✅ Biconditional Elimination
    try_conjunction_elimination(proof, conclusion) ||
      try_disjunction_elimination(proof, conclusion) ||
      try_implication_elimination(proof, conclusion) ||
      try_biconditional_elimination(proof, conclusion) ||
      @failure
  end

  defp try_conjunction_elimination(proof, conclusion) do
    case find_conjunction_including(proof, conclusion) do
      {line, _conjunction} ->
        {:ok, add_line(proof, {conclusion, {:conjunction_elimination, [line]}})}

      nil ->
        nil
    end
  end

  defp find_conjunction_including(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      case statement do
        {:and, [^conclusion, _right]} -> true
        {:and, [_left, ^conclusion]} -> true
        _ -> false
      end
    end)
  end

  defp try_disjunction_elimination(proof, conclusion) do
    case find_implications_concluding(proof, conclusion) do
      implication_lines when is_list(implication_lines) and length(implication_lines) > 1 ->
        antecedents =
          Enum.map(implication_lines, fn {_line_num, {{:if, [antecedent, _conclusion]}, _reason}} ->
            antecedent
          end)

        case find_disjunction_including(proof, antecedents) do
          nil ->
            nil

          {disjunction_line, {{:or, disjuncts}, _reason}} ->
            # need to filter implication_lines by the ones in the disjunction
            relevant_implication_lines =
              implication_lines
              |> Enum.filter(fn implication_line ->
                {_line, {{:if, [antecedent, _consequent]}, _reason}} = implication_line
                antecedent in disjuncts
              end)
              |> Enum.map(&elem(&1, 0))

            reasons = Enum.sort(relevant_implication_lines ++ [disjunction_line])

            {:ok, add_line(proof, {conclusion, {:disjunction_elimination, reasons}})}
        end

      _ ->
        nil
    end
  end

  defp find_disjunction_including(proof, statements) do
    Enum.find(proof.steps, fn {_line_num, {statement, _reason}} ->
      case statement do
        {:or, [left, right]} ->
          left in statements and right in statements

        _ ->
          nil
      end
    end)
  end

  defp try_implication_elimination(proof, conclusion) do
    case find_implication_concluding(proof, conclusion) do
      {line_implying_conclusion, {implication, _reason}} ->
        {:if, [antecedent, ^conclusion]} = implication

        case evidence_for(proof, antecedent) do
          nil ->
            nil

          {line, _} ->
            {:ok,
             add_line(
               proof,
               {conclusion, {:implication_elimination, [line, line_implying_conclusion]}}
             )}
        end

      nil ->
        nil
    end
  end

  defp try_biconditional_elimination(proof, conclusion) do
    case find_biconditional_including(proof, conclusion) do
      {line_implying_conclusion, {biconditional_implying_conclusion, _reason}} ->
        needed =
          case biconditional_implying_conclusion do
            {:iff, [left, ^conclusion]} -> left
            {:iff, [^conclusion, right]} -> right
          end

        case evidence_for(proof, needed) do
          nil ->
            nil

          {line, _} ->
            {:ok,
             add_line(
               proof,
               {conclusion, {:biconditional_elimination, [line, line_implying_conclusion]}}
             )}
        end

      nil ->
        nil
    end
  end

  defp find_biconditional_including(proof, conclusion) do
    Enum.find(proof.steps, fn {_line, {statement, _reason}} ->
      case statement do
        {:iff, [_left, ^conclusion]} -> true
        {:iff, [^conclusion, _right]} -> true
        _ -> false
      end
    end)
  end

  # Returns the step in the proof that resulted in the given expression, if present.
  defp evidence_for(proof, conclusion) do
    # Find the line supporting the conclusion if it exists...
    Enum.find(proof.steps, fn {_line, {result, _reason}} ->
      result == conclusion
    end)

    # ...or else prove it
  end

  defp find_implication_concluding(proof, conclusion) do
    case find_implications_concluding(proof, conclusion) do
      [] -> nil
      [first | _] -> first
    end
  end

  defp find_implications_concluding(proof, conclusion) do
    Enum.filter(proof.steps, fn {_line, {statement, _reason}} ->
      case statement do
        {:if, [_antecedent, ^conclusion]} -> true
        _ -> false
      end
    end)
  end

  defp add_line(proof, step) do
    next_step = proof.next_step

    proof
    |> Map.put(:next_step, next_step + 1)
    |> Map.update!(:steps, fn steps ->
      Map.put(steps, next_step, step)
    end)
  end
end

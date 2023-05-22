defmodule Quine do
  @moduledoc """
  Documentation for `Quine`.
  """

  alias Quine.Parser
  alias Quine.Evaluator

  @failure {:error, :proof_failed}

  @doc "Determines the truth value of an expression given a model of its sentences"
  def evaluate(expression, truth_values) do
    expression
    |> parse()
    |> Evaluator.evaluate(truth_values)
  end

  def tautology?(expression) do
    variables = variables(expression)
    parsed_expression = parse(expression)
    truth_values = generate_truth_values(variables)

    length(truth_values) > 0 and
      Enum.all?(truth_values, &Evaluator.evaluate(parsed_expression, &1))
  end

  def contradiction?(expression) do
    variables = variables(expression)
    parsed_expression = parse(expression)
    truth_values = generate_truth_values(variables)

    length(truth_values) > 0 and
      Enum.all?(truth_values, &(not Evaluator.evaluate(parsed_expression, &1)))
  end

  def satisfiable?(expression) do
    not contradiction?(expression)
  end

  def contingent?(expression) do
    satisfiable?(expression) and not tautology?(expression)
  end

  defp variables(expression) when is_binary(expression) do
    ~r|[A-Z]|
    |> Regex.scan(expression)
    |> List.flatten()
    |> Enum.uniq()
  end

  def generate_truth_values(variables) do
    possible_values = for i <- variables, val <- [true, false], do: %{i => val}

    possible_values =
      for a <- possible_values, b <- possible_values, uniq: true, do: Map.merge(a, b)

    Enum.filter(possible_values, &(map_size(&1) == length(variables)))
  end

  def equivalent?(expression1, expression2) do
    tautology?("(#{expression1})<->(#{expression2})")
  end

  @doc """
  Given a list of premises and a conclusion to prove, returns a list of valid steps to prove the
  conclusion, or an error if it cannot be proven.

  ## Examples

      iex> Quine.prove(["A", "A->B"], "B")
      %{
        1 => {"A", :premise},
        2 => {"A->B", :premise},
        3 => {"B", {:implication_elimination, [1, 2]}}
      }

      iex> Quine.prove(["A"], "B")
      {:error, :proof_failed}

  """
  def prove(premises, conclusion) do
    parsed_premises = Enum.map(premises, &parse/1)
    parsed_conclusion = parse(conclusion)
    proof = initialize_proof_with_premises(parsed_premises)

    case parsed_conclusion do
      sentence when is_binary(sentence) -> prove_by_elimination(proof, parsed_conclusion)
      {:and, _} -> prove_conjunction(proof, parsed_conclusion)
      {:or, _} -> prove_disjunction(proof, parsed_conclusion)
      _ -> @failure
    end
  end

  defp initialize_proof_with_premises(premises) do
    premises
    |> Enum.with_index(1)
    |> Map.new(fn {premise, index} ->
      {index, {Parser.print!(premise), :premise}}
    end)
  end

  defp prove_by_elimination(proof, conclusion) when is_binary(conclusion) do
    # TRY:
    # Negation Elimination
    # ✅ Implication Elimination
    # Disjunction Elimination
    # ✅ Conjunction Elimination
    # ✅ Biconditional Elimination
    try_conjunction_elimination(proof, conclusion) ||
      try_implication_elimination(proof, conclusion) ||
      try_biconditional_elimination(proof, conclusion) ||
      try_disjunction_elimination(proof, conclusion) ||
      @failure
  end

  # Once we start proving more than just sentences...
  # defp prove_by_elimination(_proof, _conclusion), do: @failure

  defp try_conjunction_elimination(proof, conclusion) do
    case find_conjunction_including(proof, conclusion) do
      {line, _conjunction} ->
        step = {Parser.print!(conclusion), {:conjunction_elimination, [line]}}
        add_line_to_proof(proof, step)

      nil ->
        nil
    end
  end

  defp find_conjunction_including(proof, conclusion) do
    Enum.find(proof, fn {_line, {statement, _reason}} ->
      case parse(statement) do
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
          Enum.map(implication_lines, fn {_line_num, {implication, _reason}} ->
            {:if, [antecedent, _conclusion]} = parse(implication)
            antecedent
          end)

        case find_disjunction_including(proof, antecedents) do
          nil ->
            nil

          disjunction_line ->
            # need to filter implication_lines by the ones in the disjunction
            {:or, disjuncts} = parse(elem(elem(disjunction_line, 1), 0))

            relevant_implication_lines =
              implication_lines
              |> Enum.filter(fn {_line, {implication, _reason}} ->
                {:if, [antecedent, _consequent]} = parse(implication)
                antecedent in disjuncts
              end)

            reasons =
              (relevant_implication_lines ++ [disjunction_line])
              |> Enum.map(&elem(&1, 0))
              |> Enum.sort()

            step = {Parser.print!(conclusion), {:disjunction_elimination, reasons}}

            add_line_to_proof(proof, step)
        end

      _ ->
        nil
    end
  end

  defp find_disjunction_including(proof, statements) do
    Enum.find(proof, fn {_line_num, {statement, _reason}} ->
      case parse(statement) do
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
        {:if, [antecedent, ^conclusion]} = parse(implication)

        case evidence_for(proof, antecedent) do
          nil ->
            nil

          line ->
            step =
              {Parser.print!(conclusion),
               {:implication_elimination, [line, line_implying_conclusion]}}

            add_line_to_proof(proof, step)
        end

      nil ->
        nil
    end
  end

  defp find_implication_concluding(proof, conclusion) do
    case find_implications_concluding(proof, conclusion) do
      [] -> nil
      [first | _] -> first
    end
  end

  defp find_implications_concluding(proof, conclusion) do
    Enum.filter(proof, fn {_line, {statement, _reason}} ->
      case parse(statement) do
        {:if, [_antecedent, ^conclusion]} -> true
        _ -> false
      end
    end)
  end

  defp try_biconditional_elimination(proof, conclusion) do
    case find_biconditional_including(proof, conclusion) do
      {line_implying_conclusion, _biconditional} ->
        biconditional_implying_conclusion =
          proof
          |> Map.get(line_implying_conclusion)
          |> elem(0)
          |> parse()

        needed =
          case biconditional_implying_conclusion do
            {:iff, [left, ^conclusion]} -> left
            {:iff, [^conclusion, right]} -> right
          end

        case evidence_for(proof, needed) do
          nil ->
            nil

          line ->
            step =
              {Parser.print!(conclusion),
               {:biconditional_elimination, [line, line_implying_conclusion]}}

            add_line_to_proof(proof, step)
        end

      nil ->
        nil
    end
  end

  defp find_biconditional_including(proof, conclusion) do
    Enum.find(proof, fn {_line, {statement, _reason}} ->
      case parse(statement) do
        {:iff, [_left, ^conclusion]} -> true
        {:iff, [^conclusion, _right]} -> true
        _ -> false
      end
    end)
  end

  defp prove_conjunction(proof, {:and, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    if line_proving_left && line_proving_right do
      step =
        {Parser.print!(conclusion),
         {:conjunction_introduction, [line_proving_left, line_proving_right]}}

      add_line_to_proof(proof, step)
    else
      @failure
    end
  end

  defp prove_disjunction(proof, {:or, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    if line_proving_left || line_proving_right do
      step =
        {Parser.print!(conclusion),
         {:disjunction_introduction, [line_proving_left || line_proving_right]}}

      add_line_to_proof(proof, step)
    else
      @failure
    end
  end

  defp evidence_for(proof, conclusion) do
    Enum.find_value(proof, fn {line, {statement, _reason}} ->
      if statement == conclusion, do: line
    end)
  end

  defp add_line_to_proof(proof, step) do
    Map.put(proof, next_line_number(proof), step)
  end

  defp next_line_number(proof) do
    proof
    |> Map.keys()
    |> Enum.max()
    |> Kernel.+(1)
  end

  defp parse(string) do
    {:ok, parsed} = Parser.parse(string)
    parsed
  end
end

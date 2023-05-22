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
        3 => {"B", :implication_elimination, [1, 2]}
      }

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
    # Conjunction Elimination
    # ✅ Biconditional Elimination
    try_implication_elimination(proof, conclusion) ||
      try_biconditional_elimination(proof, conclusion) ||
      @failure
  end

  # Once we start proving more than just sentences...
  # defp prove_by_elimination(_proof, _conclusion), do: @failure

  defp try_implication_elimination(proof, conclusion) do
    line_implying_conclusion =
      Enum.find_value(proof, fn {line, {statement, _reason}} ->
        case parse(statement) do
          {:if, [_left, ^conclusion]} -> line
          _ -> nil
        end
      end)

    if line_implying_conclusion do
      {:if, [left, _conclusion]} =
        proof
        |> Map.get(line_implying_conclusion)
        |> elem(0)
        |> parse()

      case evidence_for(proof, left) do
        nil ->
          nil

        line ->
          step =
            {Parser.print!(conclusion), :implication_elimination,
             [line, line_implying_conclusion]}

          Map.put(proof, next_line(proof), step)
      end
    else
      nil
    end
  end

  defp try_biconditional_elimination(proof, conclusion) do
    line_implying_conclusion =
      Enum.find_value(proof, fn {line, {statement, _reason}} ->
        case parse(statement) do
          {:iff, [_left, ^conclusion]} -> line
          {:iff, [^conclusion, _right]} -> line
          _ -> nil
        end
      end)

    if line_implying_conclusion do
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
            {Parser.print!(conclusion), :biconditional_elimination,
             [line, line_implying_conclusion]}

          Map.put(proof, next_line(proof), step)
      end
    else
      nil
    end
  end

  defp prove_conjunction(proof, {:and, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    if line_proving_left && line_proving_right do
      step =
        {Parser.print!(conclusion), :conjunction_introduction,
         [line_proving_left, line_proving_right]}

      Map.put(proof, next_line(proof), step)
    else
      @failure
    end
  end

  defp prove_disjunction(proof, {:or, [left, right]} = conclusion) do
    line_proving_left = evidence_for(proof, left)
    line_proving_right = evidence_for(proof, right)

    if line_proving_left || line_proving_right do
      step =
        {Parser.print!(conclusion), :disjunction_introduction,
         [line_proving_left || line_proving_right]}

      Map.put(proof, next_line(proof), step)
    else
      @failure
    end
  end

  defp evidence_for(proof, conclusion) do
    Enum.find_value(proof, fn {line, {statement, _reason}} ->
      if statement == conclusion, do: line
    end)
  end

  defp next_line(proof) do
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

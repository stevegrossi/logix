defmodule Quine do
  @moduledoc """
  Documentation for `Quine`.
  """

  alias Quine.Parser
  alias Quine.Evaluator

  @doc "Determines the truth value of an expression given a model of its sentences"
  def evaluate(expression, truth_values) do
    # TODO: error if not all variables present or any values are not boolean
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
        2 => {"A->B", :premise}
      }
      # Soon:
      # 3 => {"B", {:implication_elimination, [1, 2]}}

  """
  def prove(premises, conclusion) do
    parsed_premises = Enum.map(premises, &parse/1)
    _parsed_conclusion = parse(conclusion)

    _steps =
      parsed_premises
      |> Enum.with_index(1)
      |> Map.new(fn {premise, index} ->
        {index, {Parser.print!(premise), :premise}}
      end)
  end

  defp parse(string) do
    {:ok, parsed} = Parser.parse(string)
    parsed
  end
end

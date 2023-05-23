defmodule Quine do
  @moduledoc """
  Documentation for `Quine`.
  """

  alias Quine.Evaluator
  alias Quine.Parser
  alias Quine.Proof

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
      {:ok, %{
        1 => {"A", :premise},
        2 => {"A->B", :premise},
        3 => {"B", {:implication_elimination, [1, 2]}}
      }}

      iex> Quine.prove(["A"], "B")
      {:error, :proof_failed}

  """
  def prove(premises, conclusion) do
    result =
      premises
      |> Enum.map(&parse/1)
      |> Proof.new(parse(conclusion))
      |> Proof.prove()

    case result do
      {:ok, successful_proof} -> {:ok, Proof.format(successful_proof)}
      error -> error
    end
  end

  defp parse(string) do
    {:ok, parsed} = Parser.parse(string)
    parsed
  end
end

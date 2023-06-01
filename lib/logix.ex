defmodule Logix do
  @moduledoc """
  Documentation for `Logix`.
  """

  alias Logix.Evaluator
  alias Logix.Parser
  alias Logix.Proof

  @type sentence :: String.t()
  @type model :: %{sentence() => boolean()}

  @doc "Determines the truth value of an expression given a model of its sentences"
  @spec evaluate(String.t(), model()) :: boolean()
  def evaluate(input, model) do
    input
    |> parse()
    |> Evaluator.evaluate(model)
  end

  @spec tautology?(String.t()) :: boolean()
  def tautology?(input) do
    variables = variables(input)
    parsed_statement = parse(input)
    models = generate_models(variables)

    length(models) > 0 and Enum.all?(models, &Evaluator.evaluate(parsed_statement, &1))
  end

  @spec contradiction?(String.t()) :: boolean()
  def contradiction?(input) do
    variables = variables(input)
    parsed_statement = parse(input)
    models = generate_models(variables)

    length(models) > 0 and Enum.all?(models, &(not Evaluator.evaluate(parsed_statement, &1)))
  end

  @spec satisfiable?(String.t()) :: boolean()
  def satisfiable?(input) do
    not contradiction?(input)
  end

  @spec contingent?(String.t()) :: boolean()
  def contingent?(input) do
    satisfiable?(input) and not tautology?(input)
  end

  @spec variables(String.t()) :: [sentence()]
  defp variables(input) when is_binary(input) do
    ~r|[A-Z]|
    |> Regex.scan(input)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec generate_models([sentence()]) :: [model()]
  defp generate_models(variables) do
    possible_values = for i <- variables, val <- [true, false], do: %{i => val}

    possible_values =
      for a <- possible_values, b <- possible_values, uniq: true, do: Map.merge(a, b)

    Enum.filter(possible_values, &(map_size(&1) == length(variables)))
  end

  @spec equivalent?(String.t(), String.t()) :: boolean()
  def equivalent?(expression1, expression2) do
    tautology?("(#{expression1})<->(#{expression2})")
  end

  @doc """
  Given a list of premises and a conclusion to prove, returns a list of valid steps to prove the
  conclusion, or an error if it cannot be proven.

  ## Examples

      iex> Logix.prove(["A", "BvC", "B->D", "C->D"], "A^D")
      {:ok,
        %{
          1 => {"A", :premise},
          2 => {"BvC", :premise},
          3 => {"B->D", :premise},
          4 => {"C->D", :premise},
          5 => {"D", {:disjunction_elimination, [2, 3, 4]}},
          6 => {"A^D", {:conjunction_introduction, [1, 5]}}
        }}

      iex> Logix.prove(["A"], "B")
      {:error, :proof_failed}

  """
  @spec prove([String.t()], String.t()) :: Parser.error() | Proof.result()
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

  @spec parse(String.t()) :: Proof.statement()
  defp parse(string) do
    {:ok, parsed} = Parser.parse(string)
    parsed
  end
end

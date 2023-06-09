defmodule Logix.Parser do
  @moduledoc """
  A parser for simple propositional logic statements
  """

  import NimbleParsec
  alias Logix.Proof

  @type error :: {:error, :parse_error}

  # e.g. "A", "B", etc.
  sentence = ascii_string([?A..?Z], 1)

  statement =
    choice([
      ignore(string("("))
      |> concat(parsec(:expression))
      |> ignore(string(")")),
      parsec(:negation),
      sentence
    ])

  # e.g. "AvB", "Av(BvC)"
  disjunction =
    empty()
    |> concat(statement)
    |> ignore(string("v"))
    |> concat(statement)
    |> tag(:or)

  # e.g. "A^B", "A^(BvC)"
  conjunction =
    empty()
    |> concat(statement)
    |> ignore(string("^"))
    |> concat(statement)
    |> tag(:and)

  # e.g. "A->B", "(A^B)->C"
  implication =
    empty()
    |> concat(statement)
    |> ignore(string("->"))
    |> concat(statement)
    |> tag(:if)

  # e.g. "A<->B", "(A^B)<->(B^A)"
  biconditional =
    empty()
    |> concat(statement)
    |> ignore(string("<->"))
    |> concat(statement)
    |> tag(:iff)

  # e.g. "~A", ~(AvB)
  defcombinatorp(
    :negation,
    ignore(string("~"))
    |> concat(statement)
    |> tag(:not)
  )

  defcombinatorp(
    :expression,
    choice([
      implication,
      biconditional,
      disjunction,
      conjunction,
      parsec(:negation),
      statement
    ])
  )

  defparsec(:parse_expression, parsec(:expression))

  @spec parse(String.t()) :: {:ok, Proof.statement()} | error()
  def parse(string) do
    case parse_expression(string) do
      {:ok, [parsed], "", _, _, _} -> {:ok, parsed}
      _ -> {:error, :parse_error}
    end
  end

  @doc "Converts a parsed expression back into a string"
  @spec print!(Proof.statement()) :: String.t()
  def print!(sentence) when is_binary(sentence), do: sentence
  def print!({:not, [expression]}), do: "~" <> maybe_group(expression)
  def print!({:or, [left, right]}), do: maybe_group(left) <> "v" <> maybe_group(right)
  def print!({:and, [left, right]}), do: maybe_group(left) <> "^" <> maybe_group(right)
  def print!({:if, [left, right]}), do: maybe_group(left) <> "->" <> maybe_group(right)
  def print!({:iff, [left, right]}), do: maybe_group(left) <> "<->" <> maybe_group(right)

  # Bit of a hack relying on the fact that the expressions we need to group within parens all have
  # more characters than the ones we don't (1-character sentences and 2-character negations)
  @spec maybe_group(Proof.statement()) :: String.t()
  defp maybe_group(expression) do
    case print!(expression) do
      <<sentence::bytes-size(1)>> -> sentence
      <<negation::bytes-size(2)>> -> negation
      expression -> "(" <> expression <> ")"
    end
  end
end

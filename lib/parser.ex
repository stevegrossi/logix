defmodule Quine.Parser do
  @moduledoc """
  A parser for simple propositional logic statements
  """

  import NimbleParsec

  sentence = ascii_string([?A..?Z], 1)

  statement =
    choice([
      ignore(string("("))
      |> concat(parsec(:expression))
      |> ignore(string(")")),
      parsec(:negation),
      sentence
    ])

  disjunction =
    empty()
    |> concat(statement)
    |> ignore(string("v"))
    |> concat(statement)
    |> tag(:or)

  conjunction =
    empty()
    |> concat(statement)
    |> ignore(string("^"))
    |> concat(statement)
    |> tag(:and)

  implication =
    empty()
    |> concat(statement)
    |> ignore(string("->"))
    |> concat(statement)
    |> tag(:if)

  biconditional =
    empty()
    |> concat(statement)
    |> ignore(string("<->"))
    |> concat(statement)
    |> tag(:iff)

  defcombinatorp(
    :negation,
    ignore(string("~"))
    |> concat(statement)
    |> unwrap_and_tag(:not)
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

  def parse(string) do
    case parse_expression(string) do
      {:ok, [parsed], "", _, _, _} -> {:ok, parsed}
      _ -> {:error, :parse_error}
    end
  end

  @doc "Converts a parsed expression back into a string"
  def print!(sentence) when is_binary(sentence), do: sentence
  def print!({:not, expression}), do: "~" <> maybe_group(expression)
  def print!({:or, [left, right]}), do: maybe_group(left) <> "v" <> maybe_group(right)
  def print!({:and, [left, right]}), do: maybe_group(left) <> "^" <> maybe_group(right)
  def print!({:if, [left, right]}), do: maybe_group(left) <> "->" <> maybe_group(right)
  def print!({:iff, [left, right]}), do: maybe_group(left) <> "<->" <> maybe_group(right)

  # Bit of a hack relying on the fact that the expressions we need to group within parens all have
  # more characters than the ones we don't (1-character sentences and 2-character negations)
  defp maybe_group(expression) do
    case print!(expression) do
      <<sentence::bytes-size(1)>> -> sentence
      <<negation::bytes-size(2)>> -> negation
      expression -> "(" <> expression <> ")"
    end
  end
end

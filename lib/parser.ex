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
end

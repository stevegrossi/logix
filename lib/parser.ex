defmodule Quine.Parser do
  @moduledoc """
  A parser for simple propositional logic statements

  sentence  := A | B | C ...
  negation  := ~ sentence

  """

  import NimbleParsec

  sentence = ascii_string([?A..?Z], 1)

  negation =
    empty()
    |> ignore(string("~"))
    |> concat(sentence)
    |> unwrap_and_tag(:not)

  disjunction =
    empty()
    |> concat(sentence)
    |> ignore(string("v"))
    |> concat(sentence)
    |> tag(:or)

  conjunction =
    empty()
    |> concat(sentence)
    |> ignore(string("^"))
    |> concat(sentence)
    |> tag(:and)

  implication =
    empty()
    |> concat(sentence)
    |> ignore(string("->"))
    |> concat(sentence)
    |> tag(:if)

  biconditional =
    empty()
    |> concat(sentence)
    |> ignore(string("<->"))
    |> concat(sentence)
    |> tag(:iff)

  expression =
    empty()
    |> choice([
      disjunction,
      conjunction,
      implication,
      biconditional,
      negation,
      sentence
    ])

  defparsec(:parse, expression)
end

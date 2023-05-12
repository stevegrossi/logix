defmodule Quine do
  @moduledoc """
  Documentation for `Quine`.
  """

  alias Quine.Parser

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

defmodule Quine.Evaluator do
  @moduledoc """
  Calculates the truth value of expressions given maps of truth values of its sentences
  """

  def evaluate(sentence, truth_values) when is_binary(sentence) do
    Map.get(truth_values, sentence)
  end

  def evaluate({:not, expression}, truth_values) do
    not evaluate(expression, truth_values)
  end

  def evaluate({:or, [left, right]}, truth_values) do
    evaluate(left, truth_values) or evaluate(right, truth_values)
  end

  def evaluate({:and, [left, right]}, truth_values) do
    evaluate(left, truth_values) and evaluate(right, truth_values)
  end

  def evaluate({:if, [left, right]}, truth_values) do
    not (evaluate(left, truth_values) and not evaluate(right, truth_values))
  end

  def evaluate({:iff, [left, right]}, truth_values) do
    evaluate(left, truth_values) == evaluate(right, truth_values)
  end
end

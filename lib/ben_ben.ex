defmodule BenBen do
  # Define recursive type macro that handles ~field annotation
  defmacro deftype(name, do: {:__block__, _, variants}) do
    variants = Enum.map(variants, fn variant ->
      case variant do
        {variant_name, _, fields} ->
          recursive_fields = extract_recursive_fields(fields)
          quote do
            def unquote(variant_name)(unquote_splicing(fields)) do
              %{__type__: unquote(name), variant: unquote(variant_name), unquote_splicing(fields)}
            end
          end
      end
    end)

    quote do
      unquote_splicing(variants)
    end
  end

  # Fold macro implementation
  defmacro fold(expr, [do: {:case, _, patterns}]) do
    quote do
      case unquote(expr) do
        unquote(expand_patterns(patterns))
      end
    end
  end

  # Fold macro with state
  defmacro fold(expr, [with: state, do: {:case, _, patterns}]) do
    quote do
      case unquote(expr) do
        unquote(expand_patterns_with_state(patterns, state))
      end
    end
  end

  # Bend macro implementation
  defmacro bend(var, [do: {:when, _, [condition, then_block, else_block]}]) do
    quote do
      bend_loop(unquote(var), fn val ->
        if unquote(condition) do
          {:cont, unquote(then_block)}
        else
          {:halt, unquote(else_block)}
        end
      end)
    end
  end

  # Helper functions
  def bend_loop(val, fun) do
    case fun.(val) do
      {:cont, new_val} -> bend_loop(new_val, fun)
      {:halt, result} -> result
    end
  end

  defp extract_recursive_fields(fields) do
    Enum.filter(fields, fn
      {field, _, [:%{}, _, [recursive: true]]} -> true
      _ -> false
    end)
  end

  defp expand_patterns(patterns) do
    Enum.map(patterns, fn {:->, _, [[pattern], body]} ->
      quote do
        unquote(pattern) -> unquote(expand_recursive_calls(body))
      end
    end)
  end

  defp expand_patterns_with_state(patterns, state) do
    Enum.map(patterns, fn {:->, _, [[pattern], body]} ->
      quote do
        unquote(pattern) -> unquote(expand_recursive_calls_with_state(body, state))
      end
    end)
  end

  defp expand_recursive_calls(ast) do
    Macro.prewalk(ast, fn
      {:., _, [{:~, _, [expr]}, _]} ->
        quote do: fold(unquote(expr))
      other -> other
    end)
  end

  defp expand_recursive_calls_with_state(ast, state) do
    Macro.prewalk(ast, fn
      {:., _, [{:~, _, [expr]}, _]} ->
        quote do: fold(unquote(expr), with: unquote(state))
      other -> other
    end)
  end
end

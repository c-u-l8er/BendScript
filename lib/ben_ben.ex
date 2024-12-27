defmodule BenBen do
  require Logger

  defmacro deftype(name, do: block) do
    Logger.debug("Defining type #{inspect(name)} with block: #{inspect(block)}")
    variants = extract_variants(block)
    Logger.debug("Extracted variants: #{inspect(variants)}")

    quote do
      defmodule unquote(name) do
        (unquote_splicing(generate_constructors(variants)))
      end
    end
  end

  defp extract_variants({:__block__, _, variants}), do: variants
  defp extract_variants(variant), do: [variant]

  defp generate_constructors(variants) do
    Logger.debug("Generating constructors for variants: #{inspect(variants)}")

    Enum.map(variants, fn variant ->
      Logger.debug("Processing variant: #{inspect(variant)}")

      case variant do
        {name, meta, args} ->
          Logger.debug(
            "Constructor: #{inspect(name)}, meta: #{inspect(meta)}, args: #{inspect(args)}"
          )

          if args == nil do
            # Nullary constructor
            Logger.debug("Generating nullary constructor for #{inspect(name)}")

            quote do
              def unquote(name)() do
                %{variant: unquote(name)}
              end
            end
          else
            # Constructor with arguments
            {arg_names, _arg_types} = extract_constructor_args(args)
            Logger.debug("Extracted arg_names: #{inspect(arg_names)}")

            # Create variables for the function parameters
            arg_vars = Enum.map(arg_names, fn name -> Macro.var(name, nil) end)
            Logger.debug("Generated arg vars: #{inspect(arg_vars)}")

            field_pairs =
              Enum.map(Enum.zip(arg_names, arg_vars), fn {name, var} ->
                {name, var}
              end)

            Logger.debug("Field pairs: #{inspect(field_pairs)}")

            quote do
              def unquote(name)(unquote_splicing(arg_vars)) do
                Map.new([{:variant, unquote(name)} | unquote(field_pairs)])
              end
            end
          end
      end
    end)
  end

  defp extract_constructor_args(args) do
    Logger.debug("Extracting constructor args from: #{inspect(args)}")

    args
    |> List.wrap()
    |> Enum.map(fn
      {:@, _, [{name, _, _}]} ->
        Logger.debug("Found recursive arg: #{inspect(name)}")
        {name, :recursive}

      {name, _, _} ->
        Logger.debug("Found value arg: #{inspect(name)}")
        {name, :value}

      name when is_atom(name) ->
        Logger.debug("Found atom arg: #{inspect(name)}")
        {name, :value}
    end)
    |> Enum.unzip()
  end

  defmacro fold(expr, opts \\ [], do: cases) do
    Logger.debug(
      "Fold expression: #{inspect(expr)}, opts: #{inspect(opts)}, cases: #{inspect(cases)}"
    )

    state = Keyword.get(opts, :with)
    fold_cases = extract_cases(cases)
    Logger.debug("Extracted fold cases: #{inspect(fold_cases)}")

    generated_cases = generate_fold_cases(fold_cases, state)
    Logger.debug("Generated fold cases: #{inspect(generated_cases)}")

    quote do
      do_fold(unquote(expr), unquote(state), fn var, state ->
        case var do
          (unquote_splicing(generated_cases))
        end
      end)
    end
  end

  defp extract_cases({:__block__, _, clauses}) do
    Logger.debug("Extracting multiple cases from block: #{inspect(clauses)}")
    clauses
  end

  defp extract_cases(clauses) when is_list(clauses) do
    Logger.debug("Extracting cases from list: #{inspect(clauses)}")
    clauses
  end

  defp extract_cases(clause) do
    Logger.debug("Extracting single case: #{inspect(clause)}")
    [clause]
  end

  defp generate_fold_cases(cases, state) do
    Logger.debug("Generating fold cases: #{inspect(cases)}")

    Enum.map(List.wrap(cases), fn
      {:->, meta, [[{:case, _, [pattern]}], body]} ->
        Logger.debug(
          "Processing case with pattern: #{inspect(pattern)} and body: #{inspect(body)}"
        )

        {pattern_match, bindings} = generate_pattern_match(pattern)

        Logger.debug(
          "Generated pattern match: #{inspect(pattern_match)} with bindings: #{inspect(bindings)}"
        )

        quote do
          %{unquote_splicing(pattern_match)} ->
            unquote(transform_recursive_refs(body, bindings, state))
        end
    end)
  end

  defp generate_pattern_match({name, _, args}) when is_list(args) do
    Logger.debug("Generating pattern match for #{inspect(name)} with args: #{inspect(args)}")
    bindings = extract_bindings(args)
    pattern = [{:variant, name} | bindings]
    {pattern, bindings}
  end

  defp extract_bindings(args) do
    Logger.debug("Extracting bindings from args: #{inspect(args)}")

    Enum.map(args, fn
      {:@, _, [{name, _, _}]} -> {name, Macro.var(name, nil)}
      {name, _, _} -> {name, Macro.var(name, nil)}
      name when is_atom(name) -> {name, Macro.var(name, nil)}
    end)
  end

  defp transform_recursive_refs(body, bindings, state) do
    Logger.debug(
      "Transforming recursive refs in body: #{inspect(body)} with bindings: #{inspect(bindings)}, state: #{inspect(state)}"
    )

    {transformed, _} =
      Macro.prewalk(body, %{}, fn
        {:@, _, [{name, _, _}]} = node, acc ->
          if Keyword.has_key?(bindings, name) do
            var = Macro.var(name, nil)

            transformed =
              if state == nil do
                quote do: do_fold(unquote(var), nil, var!(__FOLD_FUN__))
              else
                quote do: elem(do_fold(unquote(var), var!(state), var!(__FOLD_FUN__)), 0)
              end

            {transformed, acc}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    transformed
  end

  def do_fold(%{variant: _} = data, state, fun) do
    Logger.debug("do_fold called with data: #{inspect(data)}, state: #{inspect(state)}")
    processed = process_recursive_fields(data, state, fun)
    result = fun.(processed, state)
    Logger.debug("do_fold result: #{inspect(result)}")
    result
  end

  defp process_recursive_fields(data, state, fun) do
    Logger.debug("Processing recursive fields of: #{inspect(data)}")

    Enum.reduce(Map.keys(data), data, fn
      :variant, acc ->
        acc

      key, acc ->
        case Map.get(data, key) do
          %{variant: _} = value ->
            Map.put(acc, key, do_fold(value, state, fun))

          value ->
            Map.put(acc, key, value)
        end
    end)
  end

  defmacro bend({:=, _, [var, initial]}, do: block) do
    Logger.debug("Bend operation with var: #{inspect(var)}, initial: #{inspect(initial)}")

    quote do
      do_bend(unquote(var), unquote(initial), fn var ->
        unquote(block)
      end)
    end
  end

  defmacro fork(expr) do
    Logger.debug("Fork operation with expression: #{inspect(expr)}")

    quote do
      do_bend(var, unquote(expr), fn var ->
        var
      end)
    end
  end

  def do_bend(_var_name, initial, fun) do
    Logger.debug("Executing bend with initial: #{inspect(initial)}")
    fun.(initial)
  end
end

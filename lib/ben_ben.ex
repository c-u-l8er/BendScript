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
      {:recu, _, [{name, _, _}]} ->
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
    Logger.debug("Generated fold cases after transformation: #{inspect(generated_cases)}")

    quoted =
      quote do
        do_fold(unquote(expr), unquote(state), fn var!(value), var!(state) ->
          case var!(value) do
            unquote(generated_cases)
          end
        end)
      end

    Logger.debug("Final quoted expression: #{inspect(quoted)}")
    quoted
  end

  defp extract_cases({:__block__, _, clauses}) do
    Logger.debug("Extracting multiple cases from block: #{inspect(clauses)}")
    clauses
  end

  defp extract_cases({:case, _, _} = clause) do
    Logger.debug("Extracting single case: #{inspect(clause)}")
    [clause]
  end

  defp extract_cases(clauses) when is_list(clauses) do
    Logger.debug("Extracting cases from list: #{inspect(clauses)}")
    clauses
  end

  defp generate_fold_cases(cases, state) do
    Logger.debug("Generating fold cases: #{inspect(cases)}")

    # Create case clauses for pattern matching
    case_clauses =
      Enum.map(cases, fn
        {:->, meta, [[{:case, _, [{variant_name, _, variant_args}]}], body]} ->
          {pattern_match, bindings} =
            generate_pattern_match({variant_name, [], variant_args || []})

          transformed_body = transform_recursive_refs(body, bindings, state)

          # Pattern match map form
          pattern = quote do: %{unquote_splicing(pattern_match)}

          {:->, meta, [[pattern], transformed_body]}
      end)

    # Return list of case clauses
    case_clauses
  end

  # Update transform_recursive_refs to handle both stateful and stateless cases
  defp transform_recursive_refs(body, bindings, state) do
    Logger.debug(
      "Transforming recursive refs in body: #{inspect(body)} with bindings: #{inspect(bindings)}, state: #{inspect(state)}"
    )

    {transformed, _} =
      Macro.prewalk(body, %{}, fn
        {:recu, _, [{name, _, _}]} = node, acc ->
          Logger.debug("Processing recursive reference: #{inspect(node)}")

          if Keyword.has_key?(bindings, name) do
            var = Macro.var(name, nil)

            transformed =
              if state != nil do
                # For stateful operations
                quote do
                  do_fold(unquote(var), var!(state), var!(value))
                end
              else
                # For stateless operations
                quote do
                  do_fold(unquote(var), nil, var!(value))
                end
              end

            Logger.debug("Transformed recursive reference to: #{inspect(transformed)}")
            {transformed, acc}
          else
            {node, acc}
          end

        # Handle all other nodes
        node, acc when is_map(acc) ->
          {node, acc}
      end)

    # For state operations, use the transformed expression directly
    # since it's already returning the proper tuple form
    transformed
  end

  defp generate_pattern_match({name, _, args}) when is_list(args) do
    Logger.debug("Generating pattern match for #{inspect(name)} with args: #{inspect(args)}")
    bindings = extract_bindings(args)
    pattern = [{:variant, name} | bindings]
    {pattern, bindings}
  end

  defp generate_pattern_match({name, _, _}) do
    Logger.debug("Generating pattern match for nullary constructor #{inspect(name)}")
    {[variant: name], []}
  end

  defp extract_bindings(args) do
    Logger.debug("Extracting bindings from args: #{inspect(args)}")

    Enum.map(args, fn
      {:recu, _, [{name, _, _}]} -> {name, Macro.var(name, nil)}
      {name, _, _} -> {name, Macro.var(name, nil)}
      name when is_atom(name) -> {name, Macro.var(name, nil)}
    end)
  end

  def do_fold(%{variant: _variant} = data, state, fun) do
    Logger.debug("do_fold called with data: #{inspect(data)}, state: #{inspect(state)}")

    # First check if it's a terminal case (leaf/null)
    case Map.keys(data) do
      [:variant] ->
        # Terminal case - apply function directly
        result = fun.(data, state)
        Logger.debug("Terminal case result: #{inspect(result)}")
        result

      _ ->
        # Process recursive fields first
        {processed, intermediate_state} = process_recursive_fields(data, state, fun)

        Logger.debug(
          "After processing fields - processed: #{inspect(processed)}, intermediate_state: #{inspect(intermediate_state)}"
        )

        # Apply fun with the intermediate state to get {result, new_state}
        result = fun.(processed, intermediate_state)

        Logger.debug(
          "Final result after fun: #{inspect(result)} with intermediate_state: #{inspect(intermediate_state)}"
        )

        # Return both result and final state
        result
    end
  end

  # Handle non-variant values
  def do_fold(data, state, _fun) do
    Logger.debug("do_fold called with non-variant data: #{inspect(data)}")
    # Always return a tuple with state
    {data, state}
  end

  # Update process_recursive_fields to properly accumulate state
  defp process_recursive_fields(data, state, fun) do
    Logger.debug("Processing recursive fields of: #{inspect(data)}")

    Enum.reduce(Map.keys(data), {data, state}, fn
      :variant, acc ->
        acc

      key, {acc_data, acc_state} ->
        value = Map.get(acc_data, key)

        case value do
          %{variant: _} = variant_value ->
            # Process recursive value and update state
            {processed_value, new_state} = do_fold(variant_value, acc_state, fun)

            Logger.debug(
              "Recursive field result for #{key}: #{inspect({processed_value, new_state})}"
            )

            {Map.put(acc_data, key, processed_value), new_state}

          _ ->
            # For non-variant values, preserve state
            {result, new_state} = do_fold(value, acc_state, fun)
            Logger.debug("Non-variant field #{key} result: #{inspect({result, new_state})}")
            {Map.put(acc_data, key, result), new_state}
        end
    end)
  end

  defmacro bend({:=, _, [{var_name, _, _}, initial]}, do: block) do
    Logger.debug("Bend operation with var: #{inspect(var_name)}, initial: #{inspect(initial)}")

    var = Macro.var(var_name, nil)

    quote do
      unquote(var) = unquote(initial)

      do_bend(unquote(var), fn value ->
        unquote(var) = value
        unquote(block)
      end)
    end
  end

  defmacro fork(expr) do
    Logger.debug("Fork operation with expression: #{inspect(expr)}")

    quote do
      do_bend(unquote(expr), fn value -> value end)
    end
  end

  def do_bend(initial, fun) do
    Logger.debug("Executing bend with initial: #{inspect(initial)}")
    fun.(initial)
  end
end

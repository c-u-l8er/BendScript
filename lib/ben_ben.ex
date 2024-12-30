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

    Enum.map(cases, fn
      {:->, meta, [[{:case, _, [{variant_name, _, variant_args}]}], body]} ->
        # Extract the field names and create variables based on the constructor args
        {field_names, _field_vars} = extract_field_info(variant_args || [])

        # Create pattern that exactly matches the constructor-generated structure
        pattern =
          {:%{}, [],
           [variant: variant_name] ++
             Enum.map(field_names, fn name -> {name, Macro.var(name, nil)} end)}

        Logger.debug(
          "Generated pattern: #{inspect(pattern)} for variant: #{inspect(variant_name)}"
        )

        # Create bindings for recursive references
        bindings = Enum.zip(field_names, List.duplicate(true, length(field_names)))
        transformed_body = transform_recursive_refs(body, bindings, state)

        {:->, meta, [[pattern], transformed_body]}
    end)
  end

  defp extract_field_info(args) do
    field_info =
      Enum.map(args, fn
        {:recu, _, [{name, _, _}]} -> {name, Macro.var(name, nil)}
        {name, _, _} -> {name, Macro.var(name, nil)}
        name when is_atom(name) -> {name, Macro.var(name, nil)}
      end)

    Enum.unzip(field_info)
  end

  defp generate_fold_cases({:__block__, _meta, cases}, state) do
    generate_fold_cases(cases, state)
  end

  defp generate_fold_cases(single_case, state) when not is_list(single_case) do
    generate_fold_cases([single_case], state)
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

    # Extract field names and create bindings
    {field_names, field_vars} =
      args
      |> Enum.map(fn
        {:recu, _, [{field_name, _, _}]} -> {field_name, Macro.var(field_name, nil)}
        {field_name, _, _} -> {field_name, Macro.var(field_name, nil)}
        field_name when is_atom(field_name) -> {field_name, Macro.var(field_name, nil)}
      end)
      |> Enum.unzip()

    # Create the pattern match with the correct field names
    pattern = [variant: name] ++ Enum.zip(field_names, field_vars)
    bindings = Enum.zip(field_names, field_vars)

    {pattern, bindings}
  end

  defp generate_pattern_match({name, _, _}) do
    Logger.debug("Generating pattern match for nullary constructor #{inspect(name)}")
    {[variant: name], []}
  end

  defp extract_bindings(args) do
    Logger.debug("Extracting bindings from args: #{inspect(args)}")

    Enum.map(args, fn
      {:recu, _, [{name, _, _}]} ->
        Logger.debug("Found recursive arg: #{inspect(name)}")
        {name, Macro.var(name, nil)}

      {name, _, _} ->
        Logger.debug("Found value arg: #{inspect(name)}")
        {name, Macro.var(name, nil)}

      name when is_atom(name) ->
        Logger.debug("Found atom arg: #{inspect(name)}")
        {name, Macro.var(name, nil)}
    end)
  end

  def do_fold(%{variant: variant_type} = data, state, fun) do
    Logger.debug(
      "do_fold called with data: #{inspect(data)}, variant_type: #{inspect(variant_type)}, state: #{inspect(state)}"
    )

    # Process recursive fields first
    {processed, new_state} = process_recursive_fields(data, state, fun)

    # Apply fun to processed data, maintaining the full structure
    fun.(processed, new_state)
  end

  # Handle non-variant values by wrapping them in a structure
  def do_fold(data, state, _fun) do
    Logger.debug("do_fold called with non-variant data: #{inspect(data)}")

    # Just pass through the value directly without wrapping
    if state == nil do
      data
    else
      {data, state}
    end
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
            result = do_fold(variant_value, acc_state, fun)

            Logger.debug("Recursive field result for #{key}: #{inspect(result)}")

            if acc_state == nil do
              # For stateless operations, just use the value
              {Map.put(acc_data, key, result), nil}
            else
              # For stateful operations, update state
              {value, new_state} = result
              {Map.put(acc_data, key, value), new_state}
            end

          other ->
            # Handle non-variant values directly
            {Map.put(acc_data, key, other), acc_state}
        end
    end)
  end

  def do_bend(initial, fun) do
    Logger.debug("Executing bend with initial: #{inspect(initial)}")

    result =
      case initial do
        # If we receive a fork tuple, extract the value and continue recursion
        {:fork, next_value} ->
          Logger.debug("Processing fork with next value: #{inspect(next_value)}")
          # Recursively process the forked value
          do_bend(next_value, fun)

        # For normal values, execute the function and process result
        value ->
          Logger.debug("Executing fun with value: #{inspect(value)}")
          result = fun.(value)
          Logger.debug("Fun returned result: #{inspect(result)}")

          case result do
            # If it's a map with a variant key, it's a constructor result - return as is
            %{variant: _} = constructed ->
              # Process any recursive fork operations in the constructed value
              process_constructed(constructed, fun)

            # For any other value, return as is
            other ->
              Logger.debug("Returning other value: #{inspect(other)}")
              other
          end
      end

    Logger.debug("do_bend final result: #{inspect(result)}")
    result
  end

  # Add this helper function to process constructed values and their forks
  defp process_constructed(%{variant: _} = value, fun) do
    Logger.debug("Processing constructed value: #{inspect(value)}")

    Enum.reduce(Map.keys(value), value, fn
      :variant, acc ->
        acc

      key, acc ->
        case Map.get(acc, key) do
          {:fork, next_value} ->
            # Recursively process the forked value
            result = do_bend(next_value, fun)
            Map.put(acc, key, result)

          other ->
            acc
        end
    end)
  end

  defmacro fork(expr) do
    Logger.debug("Fork operation with expression: #{inspect(expr)}")

    quote do
      {:fork, unquote(expr)}
    end
  end

  defmacro bend({:=, _, [{var_name, _, _}, initial]}, do: block) do
    Logger.debug("Bend operation with var: #{inspect(var_name)}, initial: #{inspect(initial)}")

    var = Macro.var(var_name, nil)

    quote do
      # Add this to make Logger available in the expanded code
      require Logger

      unquote(var) = unquote(initial)
      Logger.debug("Bend initial value: #{inspect(unquote(var))}")

      result =
        do_bend(unquote(var), fn value ->
          unquote(var) = value
          Logger.debug("Evaluating bend block with value: #{inspect(value)}")
          block_result = unquote(block)
          Logger.debug("Block returned: #{inspect(block_result)}")
          block_result
        end)

      Logger.debug("Final bend result: #{inspect(result)}")
      result
    end
  end
end

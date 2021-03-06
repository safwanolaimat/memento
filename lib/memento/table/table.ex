defmodule Memento.Table do
  require Memento.Mnesia
  require Memento.Error


  @moduledoc """
  Defines a Memento Table schema for Mnesia

  ## Usage

  You can define an Mnesia Table by calling `use Memento.Table` with a few
  options in your module.

  ```
  defmodule Blog.Post do
    use Memento.Table, attributes: [:id, :title, :content]
  end
  ```

  Each table then must be created before you can interact with it. You can do
  that by calling `create/2`. It's usually a good idea to call this while
  your application is being started:

  ```
  Memento.Table.create(Blog.Post)
  ```

  ## Options

  The table definition and the `create/2` function both accept a keyword list
  specifying the options for the table:

  - `attributes` - A required list of atoms representing the attribute names
    of the records of the table. Must have at least two attributes, where the
    first one is the primary key.

  - `type` - One of `:set`, `:ordered_set`, or `:bag`. Default is `:set`. In
    a `:set`, all records have unique keys. In a `:bag`, several records can
    have the same key, but the record content is unique. If a non-unique
    record is stored, the old conflicting records are overwritten.

  - `index` - List of fields to index.

  The only required option is `attributes`. See `:mnesia.create_table/2` for
  a full list of options. See the following example that uses more options:


  ```
  defmodule Blog.Post do
    use Memento.Table,
      attributes: [:id, :title, :content, :status, :author_id],
      index: [:status, :author_id],
      type: :ordered_set


    # You can also define other methods
    # or helper functions in the module
  end
  ```
  """





  # Type Definitions
  # ----------------


  @typedoc "A Memento.Table module"
  @type name :: module()

  @typedoc "A Memento.Table record data struct"
  @type record :: struct()





  # Callbacks
  # ---------


  @doc """
  Returns Table definition information.

  Every defined `Memento.Table` via the `use` macro, will export this
  method, returning information about its attributes, structure, options
  and other details.
  """
  @callback __info__() :: map()





  # Use Macro
  # ---------


  @doc false
  defmacro __using__(opts) do
    validate_options!(opts)

    quote do
      opts = unquote(opts)

      @table_attrs Keyword.get(opts, :attributes)
      @table_type  Keyword.get(opts, :type, :set)
      @table_opts  Keyword.drop(opts, [:attributes])

      @query_map  Memento.Table.Definition.build_map(@table_attrs)
      @query_base Memento.Table.Definition.build_base(__MODULE__, @table_attrs)

      @info %{
        meta: Memento.Table,
        attributes: @table_attrs,
        table_type: @table_type,
        table_opts: @table_opts,
        query_base: @query_base,
        query_map: @query_map,
        size: length(@table_attrs),
      }

      defstruct Memento.Table.Definition.struct_fields(@table_attrs)
      def __info__, do: @info
    end
  end





  # Public API
  # ----------


  @doc """
  Creates a Memento Table for Mnesia.

  This must be called before you can interact with the table in any way.
  Uses the attributes specified in the table definition. Returns `:ok` on
  success or `{:error, reason}` on failure. Will raise an error if the
  passed module isn't a Memento Table.

  You can optionally pass a set of options keyword, which will override
  all options specified in the definition except `:attributes`.  See
  `:mnesia.create_table/2` for all available options.
  """
  @spec create(name, Keyword.t) :: :ok | {:error, any}
  def create(table, opts \\ []) do
    validate_table!(table)

    info = table.__info__()
    main = [attributes: info.attributes]
    opts =
      info.table_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(main)

    :create_table
    |> Memento.Mnesia.call([table, opts])
    |> Memento.Mnesia.handle_result
  end



  @doc """
  Deletes a Memento Table for Mnesia.

  Returns `:ok` on success and `{:error, reason}` on failure.
  """
  @spec delete(name) :: :ok | {:error, any}
  def delete(table) do
    validate_table!(table)

    :delete_table
    |> Memento.Mnesia.call([table])
    |> Memento.Mnesia.handle_result
  end



  @doc """
  Returns all table information.

  Optionally accepts an extra atom argument `key` which returns result
  for only that key. Will throw an exception if the key is invalid. See
  `:mnesia.table_info/2` for a full list of allowed keys.
  """
  @spec info(name, atom) :: any
  def info(table, key \\ :all) do
    validate_table!(table)

    Memento.Mnesia.call(:table_info, [table, key])
  end



  @doc """
  Deletes all entries in the given Memento Table.

  Returns `:ok` on success and `{:error, reason}` on failure.
  """
  @spec clear(name) :: :ok | {:error, any}
  def clear(table) do
    validate_table!(table)

    :clear_table
    |> Memento.Mnesia.call([table])
    |> Memento.Mnesia.handle_result
  end







  # Private Helpers
  # ---------------


  @allowed_types [:set, :ordered_set, :bag]


  # Validate options given to __using__
  defp validate_options!(opts) do
    error = cond do
      !Keyword.keyword?(opts) ->
        "Invalid options specified"

      true ->
        attrs = Keyword.get(opts, :attributes)
        type  = Keyword.get(opts, :type, :set)
        index = Keyword.get(opts, :index, [])

        cond do
          attrs == nil ->
            "Table attributes not specified"

          !is_list(attrs) ->
            "Invalid attributes specified"

          !Enum.all?(attrs, &is_atom/1) ->
            "Invalid attributes specified"

          !is_list(index) ->
            "Invalid index list specified"

          !Enum.all?(index, &is_atom/1) ->
            "Invalid index list specified"

          !Enum.member?(@allowed_types, type) ->
            "Invalid table type specified"

          true ->
            nil
      end
    end

    case error do
      nil   -> :ok
      error -> Memento.Error.raise(error)
    end
  end


  # Validate if a module is a Memento Table
  defp validate_table!(module) do
    Memento.Table = module.__info__.meta
    :ok
  rescue
    _ ->
      Memento.Error.raise("#{inspect(module)} is not a Memento Table")
  end

end


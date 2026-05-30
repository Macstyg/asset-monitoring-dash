defmodule AssetMonitoringDashWeb.UI.Table do
  @moduledoc """
  Operational data table wrapper for dense dashboard lists.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :grid_class, :string, required: true
  attr :min_width_class, :string, default: "min-w-[760px]"
  attr :row_class, :string, default: ""
  attr :row_click, :string, default: nil
  attr :load_more_target_id, :string, default: nil
  attr :rows_class, :string, default: ""
  attr :rows, :any, required: true
  attr :selected_row_id, :string, default: nil
  attr :sort_direction, :atom, values: [:asc, :desc], default: :desc
  attr :sort_event, :string, default: nil
  attr :sort_field, :atom, default: nil
  attr :viewport_bottom, :string, default: nil
  attr :rest, :global

  slot :col, required: true do
    attr :align, :atom, values: [:left, :right]
    attr :sort_key, :string
  end

  slot :empty, required: true
  slot :row, required: true

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      aria-label={@label}
      class={[
        "max-w-full overflow-x-auto rounded-app border border-app-border",
        @class
      ]}
      {@rest}
    >
      <div class={[
        "hidden gap-4 border-b border-app-border bg-app-surface-2 px-4 py-3 font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted lg:grid",
        @min_width_class,
        @grid_class
      ]}>
        <.header_cell
          :for={col <- @col}
          col={col}
          table_id={@id}
          sort_direction={@sort_direction}
          sort_event={@sort_event}
          sort_field={@sort_field}
        />
      </div>

      <div
        id={"#{@id}-rows"}
        class={["min-w-0", @rows_class]}
        data-load-more-event={@viewport_bottom}
        data-load-more-target={@load_more_target_id}
        phx-hook={@viewport_bottom && "ScrollableLoadMore"}
        phx-update="stream"
      >
        <div
          id={"#{@id}-empty"}
          class="hidden only:block px-4 py-8 text-center text-sm text-app-muted"
        >
          {render_slot(@empty)}
        </div>

        <div
          :for={{row_id, row} <- @rows}
          id={row_id}
          phx-click={@row_click}
          phx-value-id={row.id}
          class={[
            "grid gap-4 border-b border-app-border px-4 py-4 last:border-b-0",
            @row_click && "cursor-pointer transition hover:bg-app-surface-2/60",
            row.id == @selected_row_id && "bg-app-accent/5 ring-1 ring-inset ring-app-accent/20",
            @row_class
          ]}
        >
          {render_slot(@row, row)}
        </div>
      </div>
    </div>
    """
  end

  attr :col, :map, required: true
  attr :sort_direction, :atom, values: [:asc, :desc], required: true
  attr :sort_event, :string, default: nil
  attr :sort_field, :atom, default: nil
  attr :table_id, :string, required: true

  defp header_cell(%{col: %{sort_key: sort_key}, sort_event: sort_event} = assigns)
       when is_binary(sort_key) and is_binary(sort_event) do
    assigns = assign(assigns, :active?, active_sort?(sort_key, assigns.sort_field))

    ~H"""
    <button
      id={"#{@table_id}-sort-#{@col[:sort_key]}"}
      type="button"
      phx-click={@sort_event}
      phx-value-field={@col[:sort_key]}
      class={[
        "inline-flex min-w-0 items-center gap-1.5 rounded-sm text-left transition hover:text-app-fg focus:outline-none focus:ring-2 focus:ring-app-accent/20",
        @col[:align] == :right && "w-full justify-end text-right",
        @active? && "text-app-fg"
      ]}
    >
      <span class="truncate">{render_slot(@col)}</span>
      <.icon
        :if={@active?}
        name="hero-chevron-down"
        class={[
          "size-3.5 shrink-0 text-app-accent transition",
          @sort_direction == :asc && "rotate-180"
        ]}
      />
    </button>
    """
  end

  defp header_cell(assigns) do
    ~H"""
    <span class={@col[:align] == :right && "text-right"}>
      {render_slot(@col)}
    </span>
    """
  end

  attr :align, :atom, values: [:left, :right], default: :left
  attr :class, :string, default: ""
  attr :content_class, :string, default: ""
  attr :label, :string, required: true

  slot :inner_block, required: true

  def cell(assigns) do
    ~H"""
    <div class={[
      "flex min-w-0 items-center justify-between gap-3 lg:block",
      @align == :right && "lg:text-right",
      @class
    ]}>
      <span class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted lg:hidden">
        {@label}
      </span>
      <div class={["min-w-0", @content_class]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp active_sort?(sort_key, sort_field), do: sort_key == Atom.to_string(sort_field)
end

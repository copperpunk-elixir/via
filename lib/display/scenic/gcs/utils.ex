defmodule Display.Scenic.Gcs.Utils do
  require Logger
  import Scenic.Primitives
  import Scenic.Components

  @rect_border 6

  def add_columns_to_graph(graph, config) do
    offset_x = config.offset_x
    offset_y = config.offset_y
    width = config.width
    height = config.height
    labels = config.labels
    font_size = config.font_size
    # ids = Map.get(config, :ids, {:x,:y, :z})
    ids = config.ids
    col = width / 2
    row = height / length(labels)
    v_spacing = 1
    h_spacing = 3

    graph =
      Enum.reduce(Enum.with_index(labels), graph, fn {label, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> button(
              label,
              width: col - 2 * h_spacing,
              height: row - 2 * v_spacing,
              theme: :secondary,
              translate: {0, index * (row + v_spacing)}
            )
          end,
          translate: {offset_x + h_spacing, offset_y},
          button_font_size: font_size
        )
      end)

    graph =
      Enum.reduce(Enum.with_index(ids), graph, fn {id, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> text(
              "",
              text_align: :center_middle,
              font_size: font_size,
              id: id,
              translate: {0, index * row}
            )
          end,
          translate: {offset_x + 1.5 * col + h_spacing, offset_y + row / 2},
          button_font_size: font_size
        )
      end)

    {graph, offset_x, offset_y + height + config.spacer_y}
  end

  def add_rows_to_graph(graph, config) do
    id = config.id
    offset_x = config.offset_x
    offset_y = config.offset_y
    width = config.width
    height = config.height
    labels = config.labels
    font_size = config.font_size
    # ids = Map.get(config, :ids, {:x,:y, :z})
    ids = config.ids
    col = width / length(labels)
    row = height / 2
    v_spacing = 1
    h_spacing = 3

    graph =
      Enum.reduce(Enum.with_index(ids), graph, fn {id, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> text(
              "",
              text_align: :center_middle,
              font_size: font_size,
              id: id,
              translate: {index * (col + h_spacing), 0}
            )
          end,
          translate: {offset_x + 0.5 * col + h_spacing, offset_y + row / 2},
          button_font_size: font_size
        )
      end)

    graph =
      Enum.reduce(Enum.with_index(labels), graph, fn {label, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> button(
              label,
              width: col - 2 * h_spacing,
              height: row - 2 * v_spacing,
              theme: :primary,
              translate: {index * (col + h_spacing), row}
            )
          end,
          translate: {offset_x + h_spacing, offset_y},
          button_font_size: font_size
        )
      end)

    graph =
      rect(
        graph,
        {width + 2 * h_spacing, height},
        id: id,
        translate: {offset_x, offset_y},
        stroke: {@rect_border, :white}
      )

    {graph, offset_x + width + 2*h_spacing, offset_y + height + config.spacer_y}
  end

  def add_button_to_graph(graph, config) do
    Logger.debug(inspect(config))

    graph =
      button(
        graph,
        config.text,
        id: config.id,
        width: config.width,
        height: config.height,
        theme: config.theme,
        button_font_size: config.font_size,
        translate: {config.offset_x, config.offset_y}
      )

    {graph, config.offset_x, config.offset_y + config.height}
  end

  def add_rectangle_to_graph(graph, config) do
    graph =
      rect(
        graph,
        {config.width, config.height},
        id: config.id,
        translate: {config.offset_x, config.offset_y},
        fill: config.fill
      )

    {graph, config.offset_x, config.offset_y}
  end

  def add_save_log_to_graph(graph, config) do
    graph =
      button(
        graph,
        "Save Log",
        id: config.button_id,
        width: config.button_width,
        height: config.button_height,
        theme: :primary,
        button_font_size: config.font_size,
        translate: {config.offset_x, config.offset_y}
      )
      |> text_field(
        "",
        id: config.text_id,
        translate: {config.offset_x + config.button_width + 10, config.offset_y},
        font_size: config.font_size,
        text_align: :left,
        width: config.text_width
      )

    {graph, config.offset_x, config.offset_y + config.button_height}
  end

  def add_peripheral_control_to_graph(graph, config) do
    graph =
      button(
        graph,
        "Allow PeriCtrl",
        id: config.allow_id,
        width: config.button_width,
        height: config.button_height,
        theme: %{text: :white, background: :green, border: :green, active: :grey},
        button_font_size: config.font_size,
        translate: {config.offset_x, config.offset_y}
      )
      |> button(
        "Deny PeriCtrl",
        id: config.deny_id,
        width: config.button_width,
        height: config.button_height,
        theme: %{text: :white, background: :red, border: :red, active: :grey},
        button_font_size: config.font_size,
        translate: {config.offset_x + config.button_width + 10, config.offset_y}
      )

    {graph, config.offset_x, config.offset_y}
  end

  # = :math.pi/2 + :math.atan(ratio)
  @interior_angle 2.677945
  @ratio_sq 4
  @spec draw_arrow(map(), float(), float(), float(), float(), atom(), boolean(), atom()) ::
          Scenic.Graph.t()
  def draw_arrow(graph, x, y, heading, size, id, is_new \\ false, fill \\ :yellow) do
    # Center of triangle at X/Y
    tail_size = :math.sqrt(size * size * (1 + @ratio_sq))
    head = {x + size * :math.sin(heading), y - size * :math.cos(heading)}

    tail_1 =
      {x + tail_size * :math.sin(heading + @interior_angle),
       y - tail_size * :math.cos(heading + @interior_angle)}

    tail_2 =
      {x + tail_size * :math.sin(heading - @interior_angle),
       y - tail_size * :math.cos(heading - @interior_angle)}

    if is_new do
      triangle(graph, {head, tail_1, tail_2}, fill: fill, id: id)
    else
      Scenic.Graph.modify(graph, id, fn p ->
        triangle(p, {head, tail_1, tail_2}, fill: fill, id: id)
      end)
    end
  end
end

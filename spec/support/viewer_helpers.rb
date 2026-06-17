# Shared, argument-taking helpers for the viewer specs, kept here so the specs
# themselves define no methods (values use `let`).
module ViewerHelpers
  def key(k) = TuiTui::KeyEvent.new(key: k)

  def tick = TuiTui::TickEvent.new

  def mouse(action, col, row, button: :left)
    TuiTui::MouseEvent.new(action: action, button: button, col: col, row: row)
  end

  def render_context(size, chrome = TuiTui::BoxChrome::ASCII)
    TuiTui::RenderContext.new(size: size, chrome: chrome)
  end

  # Render every row of `app.view(context)` into one string. Defaults to the
  # group's `ctx` let.
  def screen(app, context = ctx)
    (1..context.size.rows).map { |r| app.view(context).render_row(r, enabled: false) }.join("\n")
  end
end

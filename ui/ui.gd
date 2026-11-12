extends RefCounted
## Shared look for menus and overlays: flat, square, dark, one warm accent.

const BG := Color("#0f0e15")
const PANEL := Color("#191822")
const EDGE := Color("#4a4660")
const TEXT := Color("#e8e0d0")
const DIM := Color("#9a94a8")
const ACCENT := Color("#e0a050")


static func box(bg: Color, border: Color, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_content_margin_all(margin)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", box(Color("#23212e"), EDGE))
	t.set_stylebox("hover", "Button", box(Color("#2c2a3a"), EDGE))
	t.set_stylebox("pressed", "Button", box(Color("#3a3144"), ACCENT))
	t.set_stylebox("disabled", "Button", box(Color("#1a1922"), Color("#2c2a38")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color("#5c586a"))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.96), EDGE, 14))
	t.set_stylebox("normal", "LineEdit", box(Color("#23212e"), EDGE))
	t.set_stylebox("focus", "LineEdit", box(Color("#23212e"), ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	return t


static func label(text: String, font_size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_height := 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


## A full-screen page: dark background, margins, and a column to fill.
static func page(host: Control) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	return column

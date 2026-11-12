extends Control
## The bottom-of-screen dialogue box: a speaker, a line that types itself out,
## and choice buttons. Tapping anywhere finishes the line, then moves on.

signal advance_requested
signal choice_made(index: int)

const UI := preload("res://ui/ui.gd")
const CHARS_PER_SECOND := 55.0

var _name: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _tween: Tween
var _has_choices := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	# A bottom-aligned stack, so the box is always exactly as tall as its text.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(stack)
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_PASS
	panel.custom_minimum_size.y = 190
	stack.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_name = UI.label("", 17, UI.ACCENT)
	column.add_child(_name)
	_text = UI.label("", 20)
	_text.custom_minimum_size.y = 84
	_text.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)
	_hint = UI.label("tap to continue", 14, UI.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)
	hide()


func show_line(speaker: String, color: Color, text: String, narration := false) -> void:
	show()
	_clear_choices()
	_name.text = speaker
	_name.visible = speaker != ""
	_name.add_theme_color_override("font_color", color)
	_text.text = text
	_text.add_theme_color_override("font_color", UI.DIM if narration else UI.TEXT)
	_text.visible_ratio = 0.0
	_hint.show()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / CHARS_PER_SECOND, 0.05))


func show_choices(texts: Array) -> void:
	show()
	_finish_typing()
	_clear_choices()
	_has_choices = true
	_hint.hide()
	for i in texts.size():
		var b := UI.button(str(texts[i]), 48)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_choice.bind(i))
		_choices.add_child(b)


func _on_choice(index: int) -> void:
	_clear_choices()
	choice_made.emit(index)


func _clear_choices() -> void:
	_has_choices = false
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _finish_typing() -> bool:
	if _tween and _tween.is_running():
		_tween.kill()
		_text.visible_ratio = 1.0
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		if _finish_typing() or _has_choices:
			return
		advance_requested.emit()

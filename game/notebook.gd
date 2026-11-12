extends Control
## The detective's notebook.
##   Clues    - evidence so far; pick two and "Connect" to try a deduction
##   History  - what this detective has done that the world will remember
##   Facts    - every stored value, editable. A testing tool for branches.
## In "present" mode it becomes an evidence picker for interrogations.

signal connect_requested(a: String, b: String)
signal presented(clue_id: String)
signal closed

const UI := preload("res://ui/ui.gd")

var mode := "browse"
var tab := "clues"

var _selected: Array = []
var _buttons: Dictionary = {}
var _title: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _action: Button
var _close: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var column := UI.page(self)
	# UI.page gives a scrolling column; here only the list should scroll,
	# so rebuild the layout around a fixed header and footer.
	var scroll: ScrollContainer = column.get_parent().get_parent()
	var margin: MarginContainer = column.get_parent()
	scroll.remove_child(margin)
	scroll.queue_free()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(margin)

	_title = UI.label("Notebook", 26, UI.ACCENT)
	column.add_child(_title)
	_tabs = HBoxContainer.new()
	column.add_child(_tabs)
	for t in ["clues", "history", "facts"]:
		var b := UI.button(t.capitalize(), 44)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.set_meta("tab", t)
		b.pressed.connect(_set_tab.bind(t))
		_tabs.add_child(b)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	list_scroll.add_child(_list)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_action = UI.button("Connect")
	_action.size_flags_horizontal = SIZE_EXPAND_FILL
	_action.pressed.connect(_on_action)
	footer.add_child(_action)
	_close = UI.button("Close")
	_close.size_flags_horizontal = SIZE_EXPAND_FILL
	_close.pressed.connect(_on_close)
	footer.add_child(_close)
	hide()


func open(p_mode := "browse", prompt := "") -> void:
	mode = p_mode
	tab = "clues"
	_selected.clear()
	_title.text = prompt if mode == "present" else "Notebook"
	_tabs.visible = mode == "browse"
	_close.text = "Never mind" if mode == "present" else "Close"
	show()
	_rebuild()


func _set_tab(t: String) -> void:
	tab = t
	_selected.clear()
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_buttons.clear()
	for b in _tabs.get_children():
		b.button_pressed = b.get_meta("tab") == tab
	match tab:
		"clues":
			_build_clues()
		"history":
			_build_history()
		"facts":
			_build_facts()
	_update_action()


func _build_clues() -> void:
	var ids: Array = GameState.case_clues()
	if ids.is_empty():
		_list.add_child(UI.label("Nothing yet. The room isn't going to search itself.", 18, UI.DIM))
		return
	if mode == "browse":
		_list.add_child(UI.label("Pick two clues that explain each other, then Connect.", 15, UI.DIM))
	for id in ids:
		var info: Dictionary = Cases.clue_info(GameState.current_case, id)
		var b := UI.button("%s%s\n%s" % ["» " if info.get("deduction", false) else "", info.get("title", id), GameState.fmt(str(info.get("text", "")))])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_toggle.bind(id))
		_buttons[id] = b
		_list.add_child(b)


func _build_history() -> void:
	var any := false
	for entry in GameState.ledger:
		if entry.get("kind", "") != "note":
			continue
		any = true
		_list.add_child(UI.label("- " + str(entry.get("text", "")), 18))
	if not any:
		_list.add_child(UI.label("Nothing on your record yet. Give it time.", 18, UI.DIM))


func _build_facts() -> void:
	_list.add_child(UI.label("Every value the story has stored for this detective. Change one to test a branch.", 15, UI.DIM))
	var keys: Array = GameState.facts.keys()
	keys.sort()
	for key in keys:
		var value: Variant = GameState.facts[key]
		var row := HBoxContainer.new()
		var l := UI.label("%s = %s" % [key, value], 15)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(l)
		if value is bool:
			row.add_child(_fact_button("flip", key, not value))
		elif value is int or value is float:
			row.add_child(_fact_button("-", key, value - 1))
			row.add_child(_fact_button("+", key, value + 1))
		_list.add_child(row)


func _fact_button(text: String, key: String, value: Variant) -> Button:
	var b := UI.button(text, 36)
	b.custom_minimum_size.x = 44
	b.pressed.connect(func() -> void:
		GameState.facts[key] = value
		GameState.changed.emit()
		_rebuild())
	return b


func _toggle(id: String) -> void:
	if id in _selected:
		_selected.erase(id)
	else:
		_selected.append(id)
		var limit := 1 if mode == "present" else 2
		while _selected.size() > limit:
			var dropped: String = _selected.pop_front()
			_buttons[dropped].button_pressed = false
	_update_action()


func _update_action() -> void:
	_action.visible = tab == "clues"
	if mode == "present":
		_action.text = "Show this"
		_action.disabled = _selected.size() != 1
	else:
		_action.text = "Connect (%d/2)" % _selected.size()
		_action.disabled = _selected.size() != 2


func _on_action() -> void:
	hide()
	if mode == "present":
		presented.emit(_selected[0])
	else:
		connect_requested.emit(_selected[0], _selected[1])


func _on_close() -> void:
	hide()
	if mode == "present":
		presented.emit("")
	else:
		closed.emit()

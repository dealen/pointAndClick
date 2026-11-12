extends Control
## Menus: title -> create a detective -> case files -> play.

const UI := preload("res://ui/ui.gd")
const Game := preload("res://game/game.gd")

const COATS := [["Charcoal", "#3d3d48"], ["Camel", "#b08850"], ["Navy", "#2c3a5e"], ["Oxblood", "#6e2a2e"]]
const PRONOUNS := [["He", "he"], ["She", "she"], ["They", "they"]]
## What people whisper about the suspension. Each sets a starting leaning.
const RUMOURS := [
	["That you got too close to a witness.", "close", "empathy"],
	["That you were right, loudly, at the wrong person.", "loud", "cynicism"],
	["That you filed the report nobody wanted filed.", "report", "bythebook"],
]

var _screen: Control
var _retire_armed := false


func _ready() -> void:
	theme = UI.make_theme()
	_show_title()


func _new_screen() -> VBoxContainer:
	if _screen:
		_screen.queue_free()
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_screen)
	return UI.page(_screen)


func _show_title() -> void:
	var column := _new_screen()
	column.add_child(UI.label("NIGHT DESK", 46, UI.ACCENT))
	column.add_child(UI.label("A detective serial. The city doesn't sleep; it just stops answering.", 18, UI.DIM))
	column.add_child(Control.new())
	var detectives: Array = GameState.list_detectives()
	if not detectives.is_empty():
		column.add_child(UI.label("On the roster", 16, UI.DIM))
	for d in detectives:
		var closed := int(d["closed"])
		var b := UI.button("Det. %s\n%s" % [d["name"], "No cases closed" if closed == 0 else "%d case%s closed" % [closed, "" if closed == 1 else "s"]], 72)
		b.pressed.connect(func() -> void:
			if GameState.load_detective(str(d["id"])):
				_show_cases())
		column.add_child(b)
	var create := UI.button("New detective")
	create.pressed.connect(_show_create)
	column.add_child(create)
	for e in Cases.errors:
		column.add_child(UI.label(str(e), 14, Color("#d06060")))


func _show_create() -> void:
	var column := _new_screen()
	column.add_child(UI.label("New detective", 32, UI.ACCENT))
	column.add_child(UI.label("Every choice this detective makes stays made, in every case they work.", 16, UI.DIM))

	column.add_child(UI.label("Surname", 16, UI.DIM))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Voss"
	name_edit.max_length = 16
	name_edit.custom_minimum_size.y = 52
	column.add_child(name_edit)

	column.add_child(UI.label("Addressed as", 16, UI.DIM))
	var pronoun := _options(column, PRONOUNS, true)
	column.add_child(UI.label("Coat", 16, UI.DIM))
	var coat := _options(column, COATS, true)
	column.add_child(UI.label("You're just back from a suspension nobody will explain. What do they whisper?", 16, UI.DIM))
	var rumour := _options(column, RUMOURS, false)

	var begin := UI.button("Report for duty")
	begin.pressed.connect(func() -> void:
		GameState.new_detective(name_edit.text, str(_picked(pronoun)[1]), str(_picked(coat)[1]))
		var r: Array = _picked(rumour)
		GameState.set_fact("world.rumour", r[1], "creation")
		GameState.add_fact("trait." + str(r[2]), 1, "creation")
		GameState.save()
		_show_cases())
	column.add_child(begin)
	var back := UI.button("Back")
	back.pressed.connect(_show_title)
	column.add_child(back)


## A set of buttons where exactly one is chosen.
func _options(column: VBoxContainer, items: Array, in_row: bool) -> ButtonGroup:
	var group := ButtonGroup.new()
	var holder: BoxContainer = HBoxContainer.new() if in_row else VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	column.add_child(holder)
	for i in items.size():
		var b := UI.button(str(items[i][0]), 48)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.set_meta("item", items[i])
		if not in_row:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		holder.add_child(b)
	return group


func _picked(group: ButtonGroup) -> Array:
	return group.get_pressed_button().get_meta("item")


func _show_cases() -> void:
	_retire_armed = false
	GameState.current_case = ""
	var column := _new_screen()
	column.add_child(UI.label("Det. %s" % GameState.detective.get("name", ""), 32, UI.ACCENT))
	column.add_child(UI.label("Case files", 16, UI.DIM))
	for c in Cases.list():
		var id := str(c["id"])
		var status := str(GameState.get_fact(id + ".status"))
		var available: bool = GameState.check(c.get("requires"))
		var line := "Open" if status == "open" else "New"
		if status == "closed":
			line = "Closed - " + str(c.get("outcomes", {}).get(str(GameState.get_fact(id + ".outcome")), ""))
		elif not available:
			line = "Not yet."
		var b := UI.button("%s\n%s\n[%s]" % [c.get("title", id), c.get("blurb", ""), line], 110)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not available
		b.pressed.connect(_play.bind(id))
		column.add_child(b)
	column.add_child(Control.new())
	var back := UI.button("Back")
	back.pressed.connect(func() -> void:
		GameState.save()
		_show_title())
	column.add_child(back)
	var retire := UI.button("Retire this detective", 44)
	retire.pressed.connect(func() -> void:
		if not _retire_armed:
			_retire_armed = true
			retire.text = "Tap again to erase Det. %s for good" % GameState.detective.get("name", "")
			return
		GameState.delete_detective(str(GameState.detective.get("id", "")))
		_show_title())
	column.add_child(retire)


func _play(case_id: String) -> void:
	if _screen:
		_screen.queue_free()
	var game := Game.new()
	_screen = game
	add_child(game)
	game.exit_requested.connect(_show_cases)
	game.start(case_id)

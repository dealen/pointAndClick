extends Control
## The play screen: a low-resolution 3D room shown as pixel art, with the
## touch controls, dialogue box and notebook on top.
##
## Tap = examine. Swipe sideways (or the arrows) = turn to the next wall.

signal exit_requested

const RoomScript := preload("res://core/room.gd")
const Runner := preload("res://core/dialogue_runner.gd")
const NotebookScript := preload("res://game/notebook.gd")
const PanelScript := preload("res://game/dialogue_panel.gd")
const UI := preload("res://ui/ui.gd")

## The room is rendered at 1/SHRINK of the screen size, then scaled up.
const SHRINK := 2
const PITCH := -35.0
const TAP_MARGIN := 10.0

var case_data: Dictionary = {}
var room: Node3D
var view := 0

var _viewport: SubViewport
var _environment: Environment
var _pivot: Node3D
var _camera: Camera3D
var _markers: Control
var _title: Label
var _toast: Label
var _toast_tween: Tween
var _hud: Control
var _panel: Control
var _notebook: Control
var _epilogue: Control
var _runner := Runner.new()
var _down := Vector2.ZERO
var _yaw := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_viewport()
	_build_hud()

	_panel = PanelScript.new()
	add_child(_panel)
	_panel.advance_requested.connect(_runner.advance)
	_panel.choice_made.connect(_runner.choose)

	_notebook = NotebookScript.new()
	add_child(_notebook)
	_notebook.presented.connect(_runner.show_evidence)
	_notebook.connect_requested.connect(_try_deduction)

	_runner.line_shown.connect(_on_line)
	_runner.choices_shown.connect(_panel.show_choices)
	_runner.evidence_requested.connect(func(prompt: String) -> void: _notebook.open("present", prompt))
	_runner.finished.connect(_on_dialogue_finished)
	GameState.clue_added.connect(_on_clue_added)
	GameState.note_added.connect(func(_text: String) -> void: _show_toast("Noted in your history."))


func start(case_id: String) -> void:
	case_data = Cases.get_case(case_id)
	GameState.current_case = case_id
	var room_id := str(GameState.get_fact("room", case_data.get("start_room", "")))
	_load_room(room_id)
	if str(GameState.get_fact("status")) == "closed":
		_show_epilogue()
	elif not GameState.get_fact("started"):
		GameState.set_fact("started", true)
		GameState.set_fact("status", "open")
		_run(str(case_data.get("intro", "")))


# ------------------------------------------------------------------ building

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = SHRINK
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/pixel_post.gdshader")
	container.material = post
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(_viewport)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = _environment
	_viewport.add_child(world)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var tilt := Node3D.new()
	tilt.rotation_degrees.x = PITCH
	_pivot.add_child(tilt)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.position.z = 14.0
	_camera.far = 40.0
	tilt.add_child(_camera)
	_camera.current = true

	var touch := Control.new()
	touch.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	touch.gui_input.connect(_on_touch)
	add_child(touch)

	_markers = Control.new()
	_markers.mouse_filter = MOUSE_FILTER_IGNORE
	_markers.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_markers)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = MOUSE_FILTER_IGNORE
	_hud.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_hud)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 36
	_hud.add_child(top)
	_title = UI.label("", 18, UI.DIM)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_title)
	var menu := UI.button("Leave", 44)
	menu.autowrap_mode = TextServer.AUTOWRAP_OFF
	menu.custom_minimum_size.x = 84
	menu.size_flags_vertical = SIZE_SHRINK_BEGIN
	menu.pressed.connect(_leave)
	top.add_child(menu)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = GROW_DIRECTION_BEGIN
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -20
	bottom.add_theme_constant_override("separation", 8)
	_hud.add_child(bottom)
	var left := UI.button("<", 60)
	left.custom_minimum_size.x = 60
	left.pressed.connect(_rotate.bind(-1))
	bottom.add_child(left)
	var scan := UI.button("Look around", 60)
	scan.size_flags_horizontal = SIZE_EXPAND_FILL
	scan.pressed.connect(_show_markers)
	bottom.add_child(scan)
	var notes := UI.button("Notebook", 60)
	notes.size_flags_horizontal = SIZE_EXPAND_FILL
	notes.pressed.connect(func() -> void: _notebook.open())
	bottom.add_child(notes)
	var right := UI.button(">", 60)
	right.custom_minimum_size.x = 60
	right.pressed.connect(_rotate.bind(1))
	bottom.add_child(right)

	_toast = UI.label("", 18, UI.ACCENT)
	_toast.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_toast.offset_top = 112
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)


func _load_room(room_id: String) -> void:
	var data: Dictionary = case_data.get("rooms", {}).get(room_id, {})
	if data.is_empty():
		push_error("Room not found: %s" % room_id)
		return
	if room:
		room.queue_free()
	room = RoomScript.new()
	_viewport.add_child(room)
	room.build(data, GameState.detective)
	GameState.set_fact("room", room_id, "", true)
	view = 0
	_yaw = 0.0
	_pivot.rotation_degrees.y = 0.0
	_pivot.position = Vector3(0, room.size.y * 0.5, 0)
	_camera.size = maxf(room.size.x, room.size.z) + 0.7
	# Slide the picture up a little so the dialogue box doesn't cover the floor.
	_camera.v_offset = -float(data.get("camera_drop", 0.9))
	_environment.background_color = Color.html(str(data.get("background", "#0b0a11")))
	_environment.ambient_light_color = Color.html(str(data.get("ambient", "#6070a0")))
	_environment.ambient_light_energy = float(data.get("ambient_energy", 0.5))
	_title.text = "%s\n%s" % [case_data.get("title", ""), data.get("name", "")]


# --------------------------------------------------------------------- input

func _on_touch(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_down = event.position
		return
	var drag: Vector2 = event.position - _down
	if drag.length() < 18.0:
		_tap(event.position)
	elif absf(drag.x) > 50.0 and absf(drag.x) > absf(drag.y):
		_rotate(1 if drag.x < 0.0 else -1)


func _tap(screen_pos: Vector2) -> void:
	if room == null or _runner.active:
		return
	var hit: Node3D = room.pick(_camera, screen_pos / SHRINK, TAP_MARGIN)
	if hit:
		_run(str(hit.get_meta("data")["hotspot"].get("run", "")))


func _rotate(direction: int) -> void:
	if room == null:
		return
	view = posmod(view + direction, 4)
	_yaw -= 90.0 * direction
	room.set_view(view)
	_clear_markers()
	create_tween().tween_property(_pivot, "rotation_degrees:y", _yaw, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Briefly labels everything worth tapping, so nobody has to hunt for pixels.
func _show_markers() -> void:
	_clear_markers()
	if room == null:
		return
	var placed: Array = []
	for n in room.hotspots(_camera):
		var tag := Label.new()
		tag.text = str(n.get_meta("data")["hotspot"].get("name", "?"))
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", UI.BG)
		tag.add_theme_stylebox_override("normal", UI.box(Color(UI.ACCENT, 0.92), UI.BG, 3))
		_markers.add_child(tag)
		var box := Rect2(Vector2.ZERO, tag.get_minimum_size())
		box.position = room.screen_rect(n, _camera).get_center() * SHRINK - box.size / 2
		box.position.x = clampf(box.position.x, 4.0, size.x - box.size.x - 4.0)
		# Nudge labels apart so a crowded desk stays readable.
		var moved := true
		while moved:
			moved = false
			for other in placed:
				if box.intersects(other):
					box.position.y = other.end.y + 1.0
					moved = true
		placed.append(box)
		tag.position = box.position
	var tween := _markers.create_tween()
	_markers.modulate.a = 1.0
	tween.tween_interval(2.2)
	tween.tween_property(_markers, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_clear_markers)


func _clear_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _leave() -> void:
	GameState.save()
	exit_requested.emit()


# ------------------------------------------------------------------ dialogue

func _run(node_id: String) -> void:
	if node_id == "" or _runner.active:
		return
	_clear_markers()
	_hud.hide()
	_runner.start(case_data.get("nodes", {}), node_id)


func _run_steps(steps: Array) -> void:
	if _runner.active:
		return
	_hud.hide()
	_runner.start({"~": steps}, "~")


func _on_line(speaker: String, text: String) -> void:
	if speaker == "":
		_panel.show_line("", UI.DIM, text, true)
		return
	var who: Dictionary = case_data.get("characters", {}).get(speaker, {})
	var display := "Det. " + str(GameState.detective.get("name", "")) if speaker == "me" else str(who.get("name", speaker))
	_panel.show_line(display, Color.html(str(who.get("color", "#e0a050"))), text)


func _on_dialogue_finished() -> void:
	_panel.hide()
	_hud.show()
	if room:
		room.refresh()
	GameState.save()
	if str(GameState.get_fact("status")) == "closed":
		_show_epilogue()
		return
	# Delayed consequences: things that happen once their condition comes true.
	for t in case_data.get("triggers", []):
		var key := "fired." + str(t.get("id", ""))
		if not GameState.get_fact(key) and GameState.check(t.get("if")):
			GameState.set_fact(key, true, "", true)
			_run(str(t.get("run", "")))
			return


func _on_clue_added(clue_id: String) -> void:
	var info: Dictionary = Cases.clue_info(GameState.current_case, clue_id)
	_show_toast("%s: %s" % ["Deduction" if info.get("deduction", false) else "New clue", info.get("title", clue_id)])


func _try_deduction(a: String, b: String) -> void:
	for d in case_data.get("deductions", []):
		var needs: Array = d.get("needs", [])
		if needs.size() == 2 and a in needs and b in needs and a != b:
			if GameState.has_clue(str(d["id"])):
				_run_steps([{"say": "me", "text": "I've already put those two together."}])
				return
			GameState.add_clue(str(d["id"]), "deduction")
			GameState.apply(d.get("do"), "deduction")
			_run_steps([{"say": "me", "text": str(d.get("text", ""))}])
			return
	var quips: Array = case_data.get("no_connection", ["Those two don't add up to anything."])
	_run_steps([{"say": "me", "text": str(quips.pick_random())}])


func _show_epilogue() -> void:
	if _epilogue:
		return
	_hud.hide()
	_epilogue = Control.new()
	_epilogue.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_epilogue)
	var column := UI.page(_epilogue)
	column.add_child(UI.label("CASE CLOSED", 16, UI.DIM))
	column.add_child(UI.label(str(case_data.get("title", "")), 36, UI.ACCENT))
	var outcome := str(GameState.get_fact("outcome"))
	column.add_child(UI.label(str(case_data.get("outcomes", {}).get(outcome, outcome)), 18, UI.DIM))
	for text in Cases.epilogue_lines(str(case_data.get("id", ""))):
		column.add_child(UI.label(text, 19))
	var back := UI.button("Back to case files")
	back.pressed.connect(_leave)
	column.add_child(back)

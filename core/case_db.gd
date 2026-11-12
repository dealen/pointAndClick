extends Node
## Cases (autoload)
##
## Finds and loads case files. A case is a folder of JSON, so new cases can be
## added without touching the engine:
##   res://cases/<id>/          built into the game
##   user://cases/<id>/         dropped in later (DLC as plain files)
##   user://dlc/*.pck or *.zip  DLC packs; each adds folders under res://cases/
##
## Folder layout:
##   case.json          manifest: characters, clues, deductions, epilogue...
##   rooms/*.json       one file per room
##   dialogue/*.json    any number of files, each a dictionary of nodes

const BUILT_IN := "res://cases"
const USER_CASES := "user://cases"
const DLC_DIR := "user://dlc"

var cases: Dictionary = {}
var errors: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	cases = {}
	errors = []
	_load_packs()
	_scan(BUILT_IN)
	_scan(USER_CASES)


func list() -> Array:
	var out: Array = cases.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("order", 99)) < float(b.get("order", 99)))
	return out


func get_case(id: String) -> Dictionary:
	return cases.get(id, {})


## Title and text for a clue or a deduction.
func clue_info(case_id: String, clue_id: String) -> Dictionary:
	var c := get_case(case_id)
	var info: Variant = c.get("clues", {}).get(clue_id)
	if info is Dictionary:
		return info
	for d in c.get("deductions", []):
		if d.get("id", "") == clue_id:
			return {"title": d.get("title", clue_id), "text": d.get("text", ""), "deduction": true}
	return {"title": clue_id, "text": ""}


## The epilogue lines that apply to the current detective.
func epilogue_lines(case_id: String) -> Array:
	var previous: String = GameState.current_case
	GameState.current_case = case_id
	var out: Array = []
	for entry in get_case(case_id).get("epilogue", []):
		if GameState.check(entry.get("if")):
			out.append(GameState.fmt(str(entry.get("text", ""))))
	GameState.current_case = previous
	return out


func _load_packs() -> void:
	var dir := DirAccess.open(DLC_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".pck") or file.ends_with(".zip"):
			if not ProjectSettings.load_resource_pack(DLC_DIR.path_join(file)):
				errors.append("Could not load pack %s" % file)


func _scan(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	for folder in dir.get_directories():
		var path := root.path_join(folder)
		if FileAccess.file_exists(path.path_join("case.json")):
			_load_case(path)


func _load_case(path: String) -> void:
	var manifest: Variant = read_json(path.path_join("case.json"))
	if not (manifest is Dictionary) or str(manifest.get("id", "")) == "":
		errors.append("%s: case.json is missing or has no id" % path)
		return
	var c: Dictionary = manifest
	var id := str(c["id"])
	c["path"] = path
	c["nodes"] = {}
	c["rooms"] = {}
	for file in _json_files(path.path_join("dialogue")):
		var nodes: Variant = read_json(file)
		if nodes is Dictionary:
			c["nodes"].merge(nodes, true)
	for file in _json_files(path.path_join("rooms")):
		var room: Variant = read_json(file)
		if room is Dictionary and room.has("id"):
			c["rooms"][str(room["id"])] = room
			c["nodes"].merge(room.get("nodes", {}), true)
	cases[id] = c
	if not (id in GameState.known_spaces):
		GameState.known_spaces.append(id)
	var defaults: Dictionary = {"status": "new", "outcome": ""}
	defaults.merge(c.get("defaults", {}), true)
	for key in defaults:
		GameState.defaults[id + "." + str(key)] = defaults[key]


func _json_files(folder: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder)
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".json"):
				out.append(folder.path_join(file))
	out.sort()
	return out


func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		push_error(errors[-1])
		return null
	return json.data

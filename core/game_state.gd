extends Node
## GameState (autoload)
##
## Everything a detective has done lives here, in one saveable blob:
##   facts   - named values written by choices ("dead_air.marla_admitted": true)
##   clues   - evidence collected, per case
##   ledger  - a log of every change, with the player-facing notes
##
## One detective = one version of the world. Facts are never reset between
## cases, so a later case can test what happened in an earlier one.
##
## Fact names:
##   world.x  / trait.x      shared by all cases
##   <case_id>.x             belongs to a case
##   x                       shorthand for <current case>.x

signal changed
signal clue_added(clue_id: String)
signal note_added(text: String)
signal case_finished(case_id: String, outcome: String)

const SAVE_DIR := "user://detectives"
const KEYWORDS := ["and", "or", "not", "true", "false", "null", "in"]
const PRONOUNS := {
	"he": {"he": "he", "him": "him", "his": "his", "sir": "sir", "is": "is", "has": "has"},
	"she": {"he": "she", "him": "her", "his": "her", "sir": "ma'am", "is": "is", "has": "has"},
	"they": {"he": "they", "him": "them", "his": "their", "sir": "Detective", "is": "are", "has": "have"},
}

var detective: Dictionary = {}
var facts: Dictionary = {}
var clues: Dictionary = {}
var ledger: Array = []
var current_case := ""

## Filled in by Cases when case files are loaded.
var known_spaces: Array = ["world", "trait"]
var defaults: Dictionary = {}

var _expr_cache: Dictionary = {}
var _ident_re := RegEx.new()


func _ready() -> void:
	_ident_re.compile("\"[^\"]*\"|'[^']*'|[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save()


# ---------------------------------------------------------------- detectives

func new_detective(surname: String, pronoun: String, coat: String) -> void:
	surname = surname.strip_edges()
	if surname == "":
		surname = "Voss"
	detective = {
		"id": "%s_%d" % [surname.to_lower().validate_filename().replace(" ", "_"), int(Time.get_unix_time_from_system())],
		"name": surname,
		"pronoun": pronoun if PRONOUNS.has(pronoun) else "they",
		"coat": coat,
	}
	facts = {}
	clues = {}
	ledger = []
	current_case = ""
	save()


func list_detectives() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR.path_join(file)))
		if data is Dictionary and data.get("detective") is Dictionary:
			var closed := 0
			var f: Dictionary = data.get("facts", {})
			for key in f:
				if str(key).ends_with(".status") and str(f[key]) == "closed":
					closed += 1
			out.append({"id": data["detective"].get("id", ""), "name": data["detective"].get("name", "?"), "closed": closed})
	return out


func load_detective(id: String) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(id)))
	if not (data is Dictionary):
		return false
	detective = data.get("detective", {})
	facts = data.get("facts", {})
	clues = data.get("clues", {})
	ledger = data.get("ledger", [])
	for key in facts:
		facts[key] = _tidy(facts[key])
	current_case = ""
	return true


func delete_detective(id: String) -> void:
	DirAccess.remove_absolute(_path(id))
	if detective.get("id", "") == id:
		detective = {}


func save() -> void:
	if detective.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_path(str(detective["id"])), FileAccess.WRITE)
	if file == null:
		push_error("Could not save detective: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"detective": detective, "facts": facts, "clues": clues, "ledger": ledger}, "\t"))


func _path(id: String) -> String:
	return SAVE_DIR.path_join(id + ".json")


# --------------------------------------------------------------------- facts

## Turns a short fact name into its full name.
func resolve(key: String) -> String:
	if current_case == "" or key.get_slice(".", 0) in known_spaces:
		return key
	return current_case + "." + key


func get_fact(key: String, fallback: Variant = 0) -> Variant:
	var full := resolve(key)
	if facts.has(full):
		return facts[full]
	return defaults.get(full, fallback)


## Used by condition expressions.
func f(key: String) -> Variant:
	return get_fact(key)


func set_fact(key: String, value: Variant, source := "", silent := false) -> void:
	var full := resolve(key)
	value = _tidy(value)
	if facts.has(full) and typeof(facts[full]) == typeof(value) and facts[full] == value:
		return
	facts[full] = value
	if not silent:
		_log("fact", "%s = %s" % [full, value], source)
	changed.emit()


func add_fact(key: String, amount: Variant, source := "", silent := false) -> void:
	var current: Variant = get_fact(key)
	if not (current is int or current is float):
		current = 0
	set_fact(key, current + amount, source, silent)


func _tidy(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	return value


# --------------------------------------------------------------------- clues

func case_clues(case_id := "") -> Array:
	return clues.get(case_id if case_id != "" else current_case, [])


func has_clue(id: String) -> bool:
	return id in case_clues()


func add_clue(id: String, source := "") -> void:
	if has_clue(id):
		return
	if not clues.has(current_case):
		clues[current_case] = []
	clues[current_case].append(id)
	set_fact("clue." + id, true, source, true)
	_log("clue", id, source)
	clue_added.emit(id)


## A note the player can read back in their history.
func remember(text: String, source := "") -> void:
	text = fmt(text)
	_log("note", text, source)
	note_added.emit(text)


func finish_case(outcome: String) -> void:
	set_fact("outcome", outcome, "finish")
	set_fact("status", "closed", "finish")
	save()
	case_finished.emit(current_case, outcome)


func _log(kind: String, text: String, source: String) -> void:
	ledger.append({
		"t": int(Time.get_unix_time_from_system()),
		"case": current_case,
		"kind": kind,
		"text": text,
		"src": source,
	})


# ---------------------------------------------------------------- conditions

## True if the condition holds. Empty conditions are always true.
## Example: "marla_trust >= 1 and not world.lied_to_marla"
func check(cond: Variant) -> bool:
	if cond == null:
		return true
	if cond is bool:
		return cond
	var text := str(cond).strip_edges()
	if text == "":
		return true
	var expr: Variant = _expr_cache.get(text)
	if expr == null:
		expr = Expression.new()
		if expr.parse(_rewrite(text)) != OK:
			push_error("Bad condition '%s': %s" % [text, expr.get_error_text()])
			expr = false
		_expr_cache[text] = expr
	if expr is bool:
		return false
	var result: Variant = expr.execute([], self, false)
	if expr.has_execute_failed():
		push_error("Condition failed '%s': %s" % [text, expr.get_error_text()])
		return false
	return true if result else false


## True if the condition can be parsed. Used by the validator.
func condition_parses(cond: Variant) -> bool:
	if cond == null or cond is bool or str(cond).strip_edges() == "":
		return true
	var expr := Expression.new()
	return expr.parse(_rewrite(str(cond))) == OK


func _rewrite(text: String) -> String:
	var out := ""
	var last := 0
	for m in _ident_re.search_all(text):
		out += text.substr(last, m.get_start() - last)
		var word := m.get_string()
		if word.begins_with("\"") or word.begins_with("'") or word in KEYWORDS:
			out += word
		else:
			out += "f(\"%s\")" % word
		last = m.get_end()
	return out + text.substr(last)


# ------------------------------------------------------------------- effects

## Runs a list of effect lines:
##   set <fact> <value>     add <fact> <number>     clue <id>
##   remember <text>        finish <outcome>
func apply(effects: Variant, source := "") -> void:
	if effects == null:
		return
	if effects is String:
		effects = [effects]
	for raw in effects:
		var line := str(raw).strip_edges()
		var verb := line.get_slice(" ", 0)
		var rest := line.substr(verb.length()).strip_edges()
		var key := rest.get_slice(" ", 0)
		var value := rest.substr(key.length()).strip_edges()
		match verb:
			"set":
				set_fact(key, parse_value(value), source)
			"add":
				add_fact(key, parse_value(value), source)
			"clue":
				add_clue(rest, source)
			"remember":
				remember(rest, source)
			"finish":
				finish_case(rest)
			_:
				push_error("Unknown effect '%s' (from %s)" % [line, source])


func parse_value(text: String) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


# ---------------------------------------------------------------------- text

## Fills in {name}, {sir}, {he}, {him}, {his}, {is}, {has} (and {He} etc.).
func fmt(text: String) -> String:
	if not text.contains("{"):
		return text
	var tokens := {"name": str(detective.get("name", "Voss"))}
	var words: Dictionary = PRONOUNS.get(str(detective.get("pronoun", "they")), PRONOUNS["they"])
	for key in words:
		tokens[key] = words[key]
		tokens[str(key).capitalize()] = str(words[key]).capitalize()
	return text.format(tokens)

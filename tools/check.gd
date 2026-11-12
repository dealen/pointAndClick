extends Node
## Checks every case file for mistakes, then plays "Dead Air" through by script.
## Run from the project folder:
##   godot --headless res://tools/check.tscn

const Runner := preload("res://core/dialogue_runner.gd")
const STEP_KEYS := ["if", "do", "say", "text", "choice", "present", "else", "cancel", "prompt", "goto", "end"]
const VERBS := ["set", "add", "clue", "remember", "finish"]

var problems: Array = []
var _pending := ""
var _texts: Array = []
var _lines := 0


func _ready() -> void:
	for e in Cases.errors:
		problems.append(str(e))
	for c in Cases.list():
		_validate(c)
	if Cases.get_case("dead_air").size() > 0:
		_play_dead_air()
	for p in problems:
		print("PROBLEM: ", p)
	print("%d problem(s)." % problems.size())
	get_tree().quit(1 if problems.size() > 0 else 0)


# ---------------------------------------------------------------- validation

func _validate(c: Dictionary) -> void:
	var id := str(c["id"])
	GameState.current_case = id
	var nodes: Dictionary = c["nodes"]
	var known: Array = c.get("clues", {}).keys()
	for d in c.get("deductions", []):
		known.append(d.get("id", ""))
		for need in d.get("needs", []):
			if not c.get("clues", {}).has(need) :
				problems.append("%s: deduction '%s' needs unknown clue '%s'" % [id, d.get("id"), need])
		_effects(id, "deduction " + str(d.get("id")), d.get("do"), known)
	if not c["rooms"].has(str(c.get("start_room", ""))):
		problems.append("%s: start_room not found" % id)
	_target(id, "intro", str(c.get("intro", "end")), nodes)
	for t in c.get("triggers", []):
		_target(id, "trigger", str(t.get("run", "")), nodes)
		_cond(id, "trigger", t.get("if"))
	for e in c.get("epilogue", []):
		_cond(id, "epilogue", e.get("if"))
	_cond(id, "requires", c.get("requires"))
	for room_id in c["rooms"]:
		for p in c["rooms"][room_id].get("props", []):
			_cond(id, "prop " + str(p.get("id")), p.get("if"))
			for part in p.get("parts", []):
				_cond(id, "prop " + str(p.get("id")), part.get("if"))
			if p.has("hotspot"):
				_target(id, "hotspot " + str(p.get("id")), str(p["hotspot"].get("run", "")), nodes)
				_cond(id, "hotspot " + str(p.get("id")), p["hotspot"].get("if"))
	for node_id in nodes:
		var where := "%s/%s" % [id, node_id]
		if not (nodes[node_id] is Array):
			problems.append("%s: node is not a list of steps" % where)
			continue
		for step in nodes[node_id]:
			for key in step:
				if not (key in STEP_KEYS):
					problems.append("%s: unknown step key '%s'" % [where, key])
			_cond(id, where, step.get("if"))
			_effects(id, where, step.get("do"), known)
			if step.has("say") and not (str(step["say"]) in ["", "me"]) and not c.get("characters", {}).has(step["say"]):
				problems.append("%s: unknown speaker '%s'" % [where, step["say"]])
			if step.has("goto"):
				_target(id, where, str(step["goto"]), nodes)
			for opt in step.get("choice", []):
				_cond(id, where, opt.get("if"))
				_effects(id, where, opt.get("do"), known)
				if opt.has("goto"):
					_target(id, where, str(opt["goto"]), nodes)
			if step.has("present"):
				for clue in step["present"]:
					if not (clue in known):
						problems.append("%s: present lists unknown clue '%s'" % [where, clue])
					_target(id, where, str(step["present"][clue]), nodes)
				for key in ["else", "cancel"]:
					if step.has(key):
						_target(id, where, str(step[key]), nodes)
	GameState.current_case = ""


func _target(id: String, where: String, target: String, nodes: Dictionary) -> void:
	if target != "end" and not nodes.has(target):
		problems.append("%s %s: no such node '%s'" % [id, where, target])


func _cond(id: String, where: String, cond: Variant) -> void:
	if not GameState.condition_parses(cond):
		problems.append("%s %s: condition does not parse: %s" % [id, where, cond])


func _effects(_id: String, where: String, effects: Variant, known: Array) -> void:
	if effects == null:
		return
	for line in (effects if effects is Array else [effects]):
		var verb := str(line).get_slice(" ", 0)
		if not (verb in VERBS):
			problems.append("%s: unknown effect '%s'" % [where, line])
		if verb == "clue" and not (str(line).substr(5).strip_edges() in known):
			problems.append("%s: unknown clue in '%s'" % [where, line])


# ------------------------------------------------------------------ playtest

func _play_dead_air() -> void:
	var c := Cases.get_case("dead_air")
	var runner := Runner.new()
	runner.line_shown.connect(func(_who: String, _text: String) -> void:
		_pending = "line"
		_lines += 1)
	runner.choices_shown.connect(func(texts: Array) -> void:
		_pending = "choice"
		_texts = texts)
	runner.evidence_requested.connect(func(_prompt: String) -> void: _pending = "present")

	# 1. A careful, kind detective: should end with the solid outcome.
	_fresh("Test")
	_play(runner, c, "intro", ["narrow"])
	for n in ["body", "mic", "clipboard", "cabinet", "on_air", "clock", "poster"]:
		_play(runner, c, n, [])
	_play(runner, c, "mug", ["Put it down"])
	_play(runner, c, "phone", ["Pick up", "city police", "Thank you"])
	_play(runner, c, "bin", ["Unfold"])
	_play(runner, c, "trophy", ["Check the base"])
	_play(runner, c, "reel", ["threaded"])
	_deduce(c, "tod", "reel_tape", "tape_alibi")
	_deduce(c, "reel_threading", "cabinet", "amateur")
	_deduce(c, "call_sheet", "iris_statement", "empty_chair")
	_play(runner, c, "pike", ["What do you make", "Carry on"])
	_play(runner, c, "marla", ["Walk me", "Show her", "@call_sheet", "Take your time", "Show her", "@letter", "doesn't mention", "That's all"])
	_expect(GameState.has_clue("gordon_car"), "kind detective should learn about Gordon's car")
	_play(runner, c, "gordon", ["Where were", "Show him", "@tape_alibi", "Show him", "@letter", "Show him", "@amateur", "Show him", "@gordon_car", "That's all"])
	_expect(GameState.get_fact("gordon_cracks") == 4, "four contradictions expected, got %s" % GameState.get_fact("gordon_cracks"))
	_expect(GameState.check("gordon_cracks >= 2 and not fired.pike_nudge"), "trigger condition should hold")
	_play(runner, c, "pike", ["ready to name", "Gordon Hale"])
	_expect(str(GameState.get_fact("outcome")) == "gordon_solid", "expected gordon_solid, got '%s'" % GameState.get_fact("outcome"))
	_expect(str(GameState.get_fact("status")) == "closed", "case should be closed")
	print("--- solid ending (%d lines read) ---" % _lines)
	for line in Cases.epilogue_lines("dead_air"):
		print("  ", line)
	var id := str(GameState.detective["id"])
	GameState.save()
	_expect(GameState.load_detective(id), "saved detective should load")
	_expect(str(GameState.get_fact("dead_air.outcome")) == "gordon_solid", "outcome should survive save and load")
	GameState.delete_detective(id)

	# 2. A careless one: lies to Marla, lingers on the drink, charges the wrong person.
	_fresh("Wrong")
	_play(runner, c, "intro", ["And?"])
	_play(runner, c, "mug", ["Smell it"])
	_play(runner, c, "bin", ["Unfold"])
	_play(runner, c, "marla", ["Show her", "@letter", "Lie", "That's all"])
	_play(runner, c, "gordon", ["That's all"])
	_play(runner, c, "pike", ["ready to name", "Gordon Hale"])
	_expect(str(GameState.get_fact("status")) != "closed", "accusing Gordon with nothing should not close the case")
	_play(runner, c, "pike", ["ready to name", "Marla Quint", "Arrest her"])
	_expect(str(GameState.get_fact("outcome")) == "marla_wrong", "expected marla_wrong")
	_expect(GameState.check("world.lied_to_marla and world.lingered_on_drink"), "world facts should be set")
	print("--- wrong ending ---")
	for line in Cases.epilogue_lines("dead_air"):
		print("  ", line)
	GameState.delete_detective(str(GameState.detective["id"]))


func _fresh(surname: String) -> void:
	GameState.new_detective(surname, "she", "#3d3d48")
	GameState.current_case = "dead_air"


## Plays one node. picks are parts of choice texts, or "@clue_id" to present.
func _play(runner: Runner, c: Dictionary, node: String, picks: Array) -> void:
	_pending = ""
	runner.start(c["nodes"], node)
	var guard := 0
	while runner.active and guard < 500:
		guard += 1
		var what := _pending
		_pending = ""
		match what:
			"line":
				runner.advance()
			"choice":
				if picks.is_empty():
					problems.append("playtest %s: ran out of picks at %s" % [node, _texts])
					return
				var want: String = picks.pop_front()
				var index := -1
				for i in _texts.size():
					if str(_texts[i]).contains(want):
						index = i
				if index < 0:
					problems.append("playtest %s: no choice containing '%s' in %s" % [node, want, _texts])
					return
				runner.choose(index)
			"present":
				var clue: String = picks.pop_front() if not picks.is_empty() else "@"
				runner.show_evidence(clue.trim_prefix("@"))
			_:
				problems.append("playtest %s: runner stalled" % node)
				return
	if not picks.is_empty():
		problems.append("playtest %s: unused picks %s" % [node, picks])


func _deduce(c: Dictionary, a: String, b: String, expected: String) -> void:
	_expect(GameState.has_clue(a) and GameState.has_clue(b), "missing clues for deduction %s" % expected)
	for d in c["deductions"]:
		if a in d["needs"] and b in d["needs"]:
			GameState.add_clue(str(d["id"]))
	_expect(GameState.has_clue(expected), "deduction %s not made" % expected)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		problems.append("playtest: " + message)

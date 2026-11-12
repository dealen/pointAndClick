extends RefCounted
## Runs dialogue nodes. No UI in here: it emits signals and waits to be told
## to carry on, so the same runner drives the game and the automated tests.
##
## A node is a list of steps, run top to bottom. A step may have:
##   "if": "condition"                   skip the step unless true
##   "do": ["effect", ...]               change facts, add clues
##   "say": "who", "text": "..."         show a line ("me" = detective, "" = narration)
##   "choice": [ {text, if, do, goto, once} ]
##   "present": {clue_id: node}, "else": node, "cancel": node, "prompt": "..."
##   "goto": "node"                      ("end" stops the dialogue)
##   "end": true

signal line_shown(speaker: String, text: String)
signal choices_shown(texts: Array)
signal evidence_requested(prompt: String)
signal finished

var nodes: Dictionary = {}
var active := false

var _node := ""
var _index := 0
var _step: Dictionary = {}
var _options: Array = []
var _waiting := ""


func start(p_nodes: Dictionary, node_id: String) -> void:
	nodes = p_nodes
	active = true
	_enter(node_id)
	_run()


func advance() -> void:
	if active and _waiting == "line":
		_waiting = ""
		_run()


func choose(index: int) -> void:
	if not active or _waiting != "choice" or index < 0 or index >= _options.size():
		return
	_waiting = ""
	var opt: Dictionary = _options[index]
	if opt.get("once", false):
		GameState.set_fact(opt["_seen"], true, "", true)
	GameState.apply(opt.get("do"), _node)
	if opt.has("goto"):
		_enter(str(opt["goto"]))
	_run()


## Answer to evidence_requested. An empty id means the player backed out.
func show_evidence(clue_id: String) -> void:
	if not active or _waiting != "present":
		return
	_waiting = ""
	var target := ""
	if clue_id == "":
		target = str(_step.get("cancel", ""))
	else:
		target = str(_step["present"].get(clue_id, _step.get("else", "")))
	if target != "":
		_enter(target)
	_run()


func _enter(id: String) -> void:
	if id == "end":
		_node = ""
		return
	if not nodes.has(id):
		push_error("Dialogue node not found: %s" % id)
		_node = ""
		return
	_node = id
	_index = 0
	GameState.add_fact("visits." + id, 1, "", true)


func _run() -> void:
	while active:
		if _node == "" or _index >= nodes[_node].size():
			_finish()
			return
		var step: Dictionary = nodes[_node][_index]
		var step_index := _index
		_index += 1
		if not GameState.check(step.get("if")):
			continue
		if step.has("do"):
			GameState.apply(step["do"], _node)
		if step.has("say"):
			_waiting = "line"
			line_shown.emit(str(step["say"]), GameState.fmt(str(step.get("text", ""))))
			return
		if step.has("choice"):
			_options = []
			var texts: Array = []
			var raw: Array = step["choice"]
			for i in raw.size():
				var opt: Dictionary = raw[i].duplicate()
				opt["_seen"] = "seen.%s.%d.%d" % [_node, step_index, i]
				if not GameState.check(opt.get("if")):
					continue
				if opt.get("once", false) and GameState.get_fact(opt["_seen"]):
					continue
				_options.append(opt)
				texts.append(GameState.fmt(str(opt.get("text", "..."))))
			if _options.is_empty():
				continue
			_waiting = "choice"
			choices_shown.emit(texts)
			return
		if step.has("present"):
			_step = step
			_waiting = "present"
			evidence_requested.emit(GameState.fmt(str(step.get("prompt", "Show what?"))))
			return
		if step.has("goto"):
			_enter(str(step["goto"]))
			continue
		if step.get("end", false):
			_finish()
			return


func _finish() -> void:
	active = false
	_waiting = ""
	finished.emit()

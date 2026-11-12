extends RefCounted
## Builds blocky low-poly people out of the same "parts" that rooms use.
## A person faces +Z; turn the prop with "rot" to face them elsewhere.
##
## "person": {"coat": "#..", "pants": "#..", "skin": "#..", "hair": "#..",
##            "hat": "#..", "long_hair": true, "pose": "stand" | "slump",
##            "detective": true}   <- uses the player's coat colour


static func parts(p: Dictionary, detective: Dictionary) -> Array:
	var coat := str(p.get("coat", "#5a5a6a"))
	if p.get("detective", false):
		coat = str(detective.get("coat", coat))
	var pants := str(p.get("pants", "#22212b"))
	var skin := str(p.get("skin", "#d9a886"))
	var hair := str(p.get("hair", "#2b2320"))
	if str(p.get("pose", "stand")) == "slump":
		return _slump(coat, pants, skin, hair, str(p.get("chair", "#3b3948")))
	var out: Array = [
		{"box": [0.34, 0.8, 0.22], "at": [0, 0.4, 0], "color": pants},
		{"box": [0.46, 0.7, 0.28], "at": [0, 1.13, 0], "color": coat},
		{"box": [0.12, 0.62, 0.14], "at": [0.29, 1.15, 0], "color": coat},
		{"box": [0.12, 0.62, 0.14], "at": [-0.29, 1.15, 0], "color": coat},
		{"box": [0.1, 0.1, 0.1], "at": [0.29, 0.79, 0], "color": skin},
		{"box": [0.1, 0.1, 0.1], "at": [-0.29, 0.79, 0], "color": skin},
		{"box": [0.26, 0.28, 0.26], "at": [0, 1.62, 0], "color": skin},
		{"box": [0.05, 0.05, 0.02], "at": [0.07, 1.65, 0.131], "color": "#1a1820"},
		{"box": [0.05, 0.05, 0.02], "at": [-0.07, 1.65, 0.131], "color": "#1a1820"},
	]
	if p.has("hat"):
		out.append({"box": [0.46, 0.04, 0.46], "at": [0, 1.77, 0], "color": p["hat"]})
		out.append({"box": [0.29, 0.15, 0.29], "at": [0, 1.86, 0], "color": p["hat"]})
	else:
		out.append({"box": [0.29, 0.1, 0.29], "at": [0, 1.79, 0], "color": hair})
		out.append({"box": [0.29, 0.14, 0.06], "at": [0, 1.7, -0.13], "color": hair})
	if p.get("long_hair", false):
		out.append({"box": [0.32, 0.34, 0.08], "at": [0, 1.56, -0.15], "color": hair})
	return out


# Seated, slumped forward onto a desk whose top is about 0.8 high
# and whose edge is about 0.45 in front of the chair.
static func _slump(coat: String, pants: String, skin: String, hair: String, chair: String) -> Array:
	return [
		{"cyl": [0.06, 0.45], "at": [0, 0.22, 0], "color": chair},
		{"box": [0.5, 0.08, 0.5], "at": [0, 0.47, 0], "color": chair},
		{"box": [0.46, 0.36, 0.06], "at": [0, 0.7, -0.27], "color": chair},
		{"box": [0.36, 0.16, 0.5], "at": [0, 0.58, 0.2], "color": pants},
		{"box": [0.36, 0.5, 0.16], "at": [0, 0.27, 0.42], "color": pants},
		{"box": [0.46, 0.7, 0.28], "at": [0, 0.83, 0.32], "rot": [60, 0, 0], "color": coat},
		{"box": [0.12, 0.14, 0.6], "at": [0.3, 0.87, 0.72], "color": coat},
		{"box": [0.12, 0.14, 0.6], "at": [-0.3, 0.87, 0.72], "color": coat},
		{"box": [0.1, 0.1, 0.1], "at": [0.3, 0.86, 1.06], "color": skin},
		{"box": [0.1, 0.1, 0.1], "at": [-0.3, 0.86, 1.06], "color": skin},
		{"box": [0.26, 0.26, 0.28], "at": [0, 0.93, 0.78], "color": skin},
		{"box": [0.28, 0.1, 0.3], "at": [0, 1.07, 0.78], "color": hair},
		{"box": [0.12, 0.03, 0.12], "at": [0.03, 1.125, 0.74], "color": "#7a1414"},
	]

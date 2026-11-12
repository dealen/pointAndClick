# Writing a case

A case is a folder. Put it in `cases/` to ship it with the game, or in the device's
`user://cases/` folder to add it later. Packed add-ons (`.pck` or `.zip` in
`user://dlc/`) work too, as long as they contain `cases/<id>/`.

```
cases/my_case/
  case.json          the manifest
  rooms/*.json       one file per room
  dialogue/*.json    as many files as you like
```

Run `godot --headless res://tools/check.tscn` after every change.

## Facts

| You write | It means |
|---|---|
| `met_owner` | a fact of this case (`my_case.met_owner`) |
| `dead_air.outcome` | a fact of another case |
| `world.lied_to_marla` | a fact shared by all cases |
| `trait.empathy` | a leaning of the detective |
| `clue.letter` | true once this case's clue `letter` is held |
| `visits.bin` | how many times node `bin` has been entered |

A fact nobody has set counts as `0`. List a starting value under `"defaults"` in
`case.json` for any fact you compare with text.

## Conditions

Ordinary expressions: `and`, `or`, `not`, `==`, `!=`, `<`, `>=`, brackets.

```
"if": "marla_trust >= 1 and not clue.gordon_car"
"if": "dead_air.outcome == \"marla_wrong\""
```

Test true/false facts with `x` or `not x`, not `x == true`.

## Effects

```
"do": ["set marla_admitted true", "add trait.empathy 1", "clue letter",
       "remember You lied to Marla.", "finish gordon_solid"]
```

`remember` writes a line the player can read in their History. `finish` closes the
case with the named outcome.

## Dialogue

Each dialogue file is a set of named nodes. A node is a list of steps, run in order.

```json
"bin": [
  {"if": "clue.letter", "say": "me", "text": "Just menus now."},
  {"if": "clue.letter", "end": true},
  {"say": "me", "text": "A balled-up letter."},
  {"choice": [
    {"text": "[Unfold it.]", "goto": "bin_letter"},
    {"text": "[Leave it.]", "goto": "end"}
  ]}
]
```

| Step | Does |
|---|---|
| `"say": "pike", "text": "..."` | A line. `"me"` is the detective, `""` is narration |
| `"choice": [...]` | Options. Each may have `if`, `do`, `goto`, and `"once": true` |
| `"present": {"clue": "node"}` | Opens the evidence picker. Add `"else"` and `"cancel"` |
| `"goto": "node"` | Jump. `"end"` stops the dialogue |
| `"do": [...]` | Effects. May share a step with `say`, `choice` or `goto` |
| `"if": "..."` | Skip this step unless true |

In text, `{name}` is the detective's surname and `{sir}` is how they are addressed.
`{he}`, `{him}`, `{his}`, `{is}` and `{has}` follow the chosen form of address.

## The manifest

`case.json` holds `id`, `title`, `blurb`, `order`, `start_room`, `intro` (a node), and:

- `"requires"`: a condition; the case is locked until it is true
- `"characters"`: name and text colour for each speaker
- `"clues"`: `id` to `{title, text}`
- `"deductions"`: `{id, needs: [clue, clue], title, text}`; made in the notebook
- `"no_connection"`: lines for when two clues don't connect
- `"triggers"`: `{id, if, run}`; plays node `run` once when `if` comes true
- `"outcomes"`: outcome id to a short label
- `"epilogue"`: `{if, text}` lines shown when the case closes

## Rooms

A room is a box. Walls are numbered 0 back, 1 right, 2 front, 3 left. Positions are
in metres from the centre of the floor; y is up.

```json
{"id": "mug", "pos": [-0.25, 0.8, 0.12],
 "parts": [{"cyl": [0.07, 0.15], "at": [0, 0.075, 0], "color": "#d8d0c0"}],
 "hotspot": {"name": "Mug", "run": "mug"}}
```

- **Parts**: `"box": [x, y, z]`, `"cyl": [radius, height]` (a third number tapers
  the top), or `"sphere": radius`. Options: `at`, `rot`, `color`, `glow`, `alpha`,
  `blink`, `if`, and `nohit` to leave it out of the tap area.
- **People**: `"person": {"coat": "#..", "hair": "#..", "hat": "#..", "pose": "slump"}`.
  `"detective": true` wears the player's coat.
- **`"wall": n`**: the prop hangs on that wall and hides when the camera is behind it.
- **`"if"`** on a prop or part shows it only while the condition holds.
- **`"hotspot"`**: makes the prop tappable and names the node to run.
- **Lights**: `{"type": "omni", "pos", "color", "energy", "range"}` or
  `{"type": "sun", "rot", "color", "energy", "shadow"}`.

Make small things chunky. A real-size mug is four pixels wide.

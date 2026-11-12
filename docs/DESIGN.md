# Design notes

## The game

A detective serial for phones, held upright. Each case is a crime scene you search,
a few people you question, and a name you put forward at the end. The tone is dark
but restrained: there are bodies and there is blood, but no violence on screen and
no gore. The humour is dry and comes from character, never from a punchline.

## Decisions so far

| Topic | Decision |
|---|---|
| Engine | Godot 4.7, GDScript, Compatibility renderer |
| Platform | Android first, portrait only |
| Look | Low-poly 3D, drawn at half resolution with a limited-colour dither |
| Language | English; text lives in data files so it can be translated later |
| Structure | Episodic. One case built; more can be added as data |
| Detective | Created by the player: surname, form of address, coat, and a rumour |
| Choices | Permanent per detective, and visible to every later case |
| Wrong answers | Allowed. The case closes and the world carries the mistake |
| Pace | Unhurried exploration. Timed sequences are planned, not built |

## How consequences work

Everything the detective does is stored as a **fact**: a name and a value.

- `dead_air.marla_admitted = true` belongs to one case.
- `world.lied_to_marla = true` belongs to the world, for any case to read.
- `trait.empathy = 2` is a slow-moving leaning, nudged by how you speak.

Any piece of content can carry a **condition** on those facts: a line of dialogue,
a choice, an object in the room, a whole case. Content with a false condition is
simply not there. A choice in one case changes another by setting a `world.` fact
that the later case tests.

A **trigger** is a scene that plays once, as soon as its condition becomes true.
That is how a consequence can arrive late.

The notebook's **History** tab shows the player what has been noted against them.
Its **Facts** tab lists every stored value and lets you change it, to test a branch
without replaying.

## Case 1: Dead Air (spoilers)

Dez Calloway, host of a late-night call-in show, is found dead in his booth. He died
around 1:30, but the show ran until 2:40.

- **What happened:** Gordon Hale, the station manager, learned Dez was leaving. With
  Dez gone the station fails; with Dez dead there is an insurance payout. He hit him
  with his own award, started the producer's emergency tape, and went to a bar to be
  seen listening to it.
- **Red herring:** Marla Quint, the producer, made the tape, has a key, lied about
  being at her desk, and was known on air as "the Boss".
- **What breaks Gordon:** the tape's length (his alibi is a recording), his note on a
  letter typed after he "went home", the clumsy tape threading, and his car, which
  Marla only mentions if you were decent to her.
- **Endings:** Gordon with three or more contradictions; Gordon with fewer; Marla.

## Not built yet

- Close-up views of single objects you can turn over
- Moving between several rooms in a case
- Timed sequences
- Sound and music
- Zooming the room
- A second case

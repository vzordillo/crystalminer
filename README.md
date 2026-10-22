<p align="center">
  <img src="menu/header.png" alt="crystalminer: Symmetry and crystals, block by block, in a colourful pixel font" width="800">
</p>

# crystalminer

A free, open-source [Luanti](https://www.luanti.org) game for learning symmetry, the foundation
of crystallography. Every region of the world has a symmetry group. Whatever a student builds in a
region is copied by every operation of that group: build half a butterfly in Mirror Plaza and the
mirror finishes it; place one block in the Kaleidoscope and it becomes 48. Students move up
through five tiers, from "what is a symmetry operation?" to screw axes, glide planes and
identifying a hidden point group. Prism, an AI tutor at the museum's information desk, chats with students using only the reviewed lesson text. Built for the Open Scientific Intelligence (OSI) Hackathon 2026.

[![tests](https://github.com/vzordillo/crystalminer/actions/workflows/tests.yml/badge.svg)](https://github.com/vzordillo/crystalminer/actions/workflows/tests.yml)
[![Code licence: LGPL-2.1-or-later](https://img.shields.io/badge/code-LGPL--2.1--or--later-blue.svg)](LICENSE)
[![Media licence: CC BY-SA 4.0](https://img.shields.io/badge/media-CC%20BY--SA%204.0-lightgrey.svg)](LICENSE.media)

<table>
  <tr>
    <td width="50%"><img src="docs/images/mirror_plaza.jpg" alt="Mirror Plaza seen through its entrance arch: a butterfly whose second half was made by the mirror"></td>
    <td width="50%"><img src="docs/images/kaleidoscope.jpg" alt="The Kaleidoscope world: a 48-fold star built from one seed piece, with symmetry markers and the world's name banner"></td>
  </tr>
  <tr>
    <td>Mirror Plaza: half a butterfly is built, the mirror makes the other half.</td>
    <td>The Kaleidoscope (m-3m): one piece becomes a 48-fold star.</td>
  </tr>
</table>

## Contents

- [Motivation](#motivation)
- [Features](#features)
- [Quick start](#quick-start)
- [How to play](#how-to-play)
- [For teachers](#for-teachers)
- [The AI tutor](#the-ai-tutor)
- [Development](#development)
- [Credits and acknowledgements](#credits-and-acknowledgements)
- [Licence](#licence)

## Motivation

Symmetry is the language of crystallography, but it is hard to picture. Chemistry teachers report
that students cope with the symmetry of single molecules but find space groups hard to imagine,
especially the symmetries that include a translation, such as screw axes and glide planes. They
also point to evidence that tangible 3D objects teach better than the 2D diagrams of textbooks
([Graw & Stalke, 2022](https://doi.org/10.1107/S1600576721012218)). crystalminer is built around
those two observations:

- **Build it, don't just look at it.** Students do not read about a mirror or a screw axis; they
  build next to one and watch it copy their blocks. They predict before they see, place copies by
  hand, and move between the 3D world and the 2D stereogram of textbooks.
- **Worlds to explore, one symmetry each.** 23 worlds, each with its own symmetry: from one
  mirror to the 48 operations of a cube, floor patterns, screw axes and glide planes. Students
  step into each world through the Portal Hall and watch its symmetry act on whatever they build.
- **Learn by playing.** Symmetry becomes something to experience, not only to read about: guess how
  many copies one block will make, then watch them appear; answer quizzes to unlock the next tier;
  hunt for clue crystals among the crystal models; take a guided tour; or work out the hidden
  symmetry of the Mystery Lab.
- **Free for every classroom.** The game runs on [Luanti](https://www.luanti.org), which is free
  and open source and runs on Windows, macOS, Linux and Android. An earlier prototype used
  Minecraft Java Edition; on Luanti the game itself costs nothing to install or play.

## Features

- **Symmetry you can build with.** 23 worlds, each with its own symmetry group. Every block you
  place or dig is copied by the group, so the symmetry does the work.
- **Five tiers**, from the four basic operations to screw axes, glide planes, plane groups and a
  mystery symmetry to identify. Answering every quiz question of a tier unlocks the next.
- **A museum to tour**: a foyer, three galleries (the four kinds of symmetry, a history of
  crystallography, crystal structures one block per atom) and a Portal Hall leading to every world.
- **Help on screen**: a guide window for each place, a "Next: ..." line, a progress board, a
  stereogram, and symmetry markers drawn with the symbols of International Tables.
- **Ways of learning from research**: predict before you see, copies one at a time (`/step`), place
  the copies by hand (`/byhand`), a clue-crystal hunt and a ten-minute visitor tour.
- **For classes**: a teacher view, an optional pre- and post-test with anonymous CSV export, and a
  guide for teachers.
- **Checked science**: tests check the numbers and statements the game makes against the symmetry
  engine and International Tables.
- **An AI tutor to talk to**: Prism, a crystal at the information desk, answers questions in a chat window, remembers the conversation and points to things to try in the game.
- **Free and complete**: its own blocks, textures, lettering, figures and sounds. The AI tutor needs an API key (DeepSeek or Claude) or a free local model.

## Quick start

1. Download **Luanti** from [luanti.org](https://www.luanti.org/downloads/) (Windows, macOS,
   Linux, Android). It is free and open source.
2. Download this repository (green **Code** button → **Download ZIP**, or `git clone`), and put
   the folder, named `crystalminer`, into the `games` folder of Luanti's user data folder.
   The main menu's **About** tab has a button that opens the user data folder.
3. Start Luanti, pick **crystalminer** in the row of game icons, create a new world and play.
   For a classroom, tick **Host Server** and have students join your computer's address.

Nothing else is needed: crystalminer is a complete game with its own blocks and textures. The
first start of a new world builds the museum and all 23 worlds, which takes about half a minute.

## How to play

### Controls

| Key | Action |
|---|---|
| **K** | Fly |
| **J** | Go fast |
| **T** or **/** | Open chat to type a command |
| **I** | Progress board: what is left at your tier, with a button to go to each place |
| Right-click at nothing | While flying, place a block 3 nodes in front of you (for the floating cubes) |
| Left-click (punch) | Use a portal, a lever, a clue crystal |

All blocks in your inventory are free and never run out.

### Live crystal exhibits

The six permanent exhibit portals load a new, randomly selected bulk structure each time a room
is entered; `/exhibit list` shows the current structure in each room for teachers. Add
`crystalminer` to `secure.http_mods` in `minetest.conf` (without it the game may not make web
requests, and each room shows one of three saved samples). The Materials Project key is read from
the `crystalminer.mp_api_key` setting, then the `CRYSTALMINER_MP_API_KEY` environment variable,
then `MP_API` (or `MP_API_KEY`) in the git-ignored `.env` file in the game folder. Luanti's mod
security (on by default) does not let the game read that `.env` file, so on a normal server use the
setting or the environment variable.
The key is never shown or stored in exhibit records. Candidates with the same reduced chemical
formula or the same anonymous reduced stoichiometry (for example, any other ABO3 structure) as an
existing exhibit are rejected. The game chooses a random element symbol, asks for a filtered
structure-name list, then requests only the selected structure ids; no student data is sent.
Each room load permits at most 30 filtered-list requests and 60 structure requests, with a
20-second request timeout, and no new request starts after 60 seconds; at most two room loads run
at once. If the web request fails or nothing suitable is found, the room shows a saved sample.

Some exhibit files are generated, but they are committed, so a fresh clone works as it is: the
baked sample structures, the element colour table, 96 atom textures, the atom mesh and the unit-test
fixtures. Run `sh tools/make_exhibit_assets.sh` (Python 3, standard library only) only after changing
its inputs (`data/mpcontribs/*.json`, `mods/crystalminer/exhibit_elements.lua` or the generator
scripts), and commit the regenerated files.

### The museum

Players start in the foyer of the **Museum of Crystals and Symmetry**, a building with a glass
roof, doors and signs, meant to be toured and read like a real science museum.

<table>
  <tr>
    <td width="50%"><img src="docs/images/foyer.jpg" alt="The museum foyer: a red carpet leads to the welcome board, with a framed picture of the four kinds of symmetry"></td>
    <td width="50%"><img src="docs/images/gallery1.jpg" alt="Gallery 1: the Symmetry Gate displays, each with a plaque"></td>
  </tr>
  <tr>
    <td>The foyer and its welcome board.</td>
    <td>Gallery 1: the four displays of the Symmetry Gate.</td>
  </tr>
  <tr>
    <td><img src="docs/images/gallery3.jpg" alt="Gallery 3: crystal-structure models built one block per atom"></td>
    <td><img src="docs/images/portal_hall.jpg" alt="The Portal Hall: framed portals to the worlds, each with a plaque"></td>
  </tr>
  <tr>
    <td>Gallery 3: crystal structures, one block per atom.</td>
    <td>The Portal Hall: one portal per world.</td>
  </tr>
</table>

- **Foyer**: a welcome board, and a plan of the building at eye level beside the front door; the **Workshop** (the Try-it Pad) to the west and **Visitor information** to the east, with a "words to know" board and the information desk where **Prism, the AI tutor**, floats above its screen, and Prism's pixel billboard high on the wall above it (see [The AI tutor](#the-ai-tutor)).
- **Gallery 1, Four kinds of symmetry**: the four displays A to D of the Symmetry Gate, each with a
  plaque, and an introduction board.
- **Gallery 2, A history of crystallography**: a timeline of twelve panels from Steno (1669) to the
  International Year of Crystallography (2014), and Haüy's stepped octahedron built from cubes.
- **Gallery 3, Crystals at the atomic scale**: six crystal-structure models (copper, iron, rock
  salt, caesium chloride, strontium titanate (perovskite) and diamond), each with a panel, a
  picture of one unit cell and a gold clue crystal that asks a question about it (`/hunt`).
- **Portal Hall**: one portal per world, ordered by tier, each framed with a plaque giving the
  world's name, symmetry and idea. Punching a portal takes you there. Six more portals, three on the
  west wall and three on the east wall, lead to the [live crystal exhibits](#live-crystal-exhibits).

Each history panel has a diagram of its idea (simplified ones are labelled "schematic"). There are
no portraits: the game only draws what can be drawn from the science. The rooms have carpets,
benches, plants, an information desk, mineral sculptures (fluorite, pyrite, halite) and two
symmetry puzzles in Gallery 1.

Museum NPCs: a blue information-desk character in Visitor information answers common questions and
can pass a typed question to the tutor (when the tutor is set up; the same limits as `/ask` apply),
and eight orange visitors stroll around the foyer, the Workshop, Visitor information and the
galleries and give a tip when right-clicked.

### The worlds

Each symmetry region is a **world of its own**: an island far from the museum with a landscape, an
arrival plaza with two information boards (what the world teaches; what to do there), an entrance
arch with its name and a portal back to the Portal Hall. Build spaces are large (for example
25 × 16 × 25 for the floors and 21 × 21 × 21 for the cubes) so the copies have room to be seen.
Each world is built to look like its name: a paved plaza, a fenced yard, a tower with a crown,
colonnaded halls, display-case cubes, brick rooms and hedged gardens. The architecture always stays
outside the build space.

### Tiers

| Tier | Worlds | Idea |
|---|---|---|
| 0 | Symmetry Gate, Try-it Pad | The four basic operations: translation, rotation, reflection, inversion; predicting handedness |
| 1 | Mirror Plaza (m), Twofold Yard (2), Fourfold Tower (4), Inversion Core (-1), Translation Hall (P1) | One operation at a time |
| 2 | Twin Mirrors (mm2), Monoclinic Cube (2/m), Square Court (4mm), Orthorhombic Cube (mmm) | Combining operations creates new ones |
| 3 | Diagonal Cube (3), Rotoinversion Room (-4), Bar-Three Room (-3), Kaleidoscope (m-3m), Impossible Room | 3D, cubic symmetry, the crystallographic restriction |
| 4 | Screw Hall (P2₁), Spiral Tower (P4₁), Glide Hall (Pa), Mystery Lab, Free Lab; Pattern Garden: Mirror Tiles (pmm), Glide Tiles (pgg), Pinwheel Tiles (p4), Weave Tiles (p4g) | Space-group operations, plane groups, identifying symmetry |

Answering every quiz question of a tier unlocks the next. Worlds above a player's tier can be
visited but not built in. Progress is saved with the world. Entering a world shows its explanation
for the player's tier; coming back at a higher tier shows more.

At the **Try-it Pad**, students build any shape, punch a lever (T, R, M, I), predict whether the
result can be moved to match their shape, and then see it. The answer is computed from the shape:
a mirror image matches only if the shape has a mirror plane or inversion centre of its own.

### Help on screen

<table>
  <tr>
    <td width="50%"><img src="docs/images/guide_window.jpg" alt="The Fourfold Tower guide window: a picture, numbered steps and an 'In the real world' line"></td>
    <td width="50%"><img src="docs/images/hud_fourfold_tower.jpg" alt="The Fourfold Tower with a four-bladed windmill and the stereogram of point group 4 in the corner of the screen"></td>
  </tr>
  <tr>
    <td>A guide window: what to do, in numbered steps.</td>
    <td>The Fourfold Tower, with the stereogram in the corner.</td>
  </tr>
</table>

- **Guides.** The first time a player arrives anywhere (Gallery 1, the Try-it Pad, each world), a
  window explains the place in plain words: what it is, numbered steps, what they will see and the
  word for it, with a picture. `/explain` shows it again, and the same steps are on the boards on
  site. Most guides (22 of 25: not the Gate, the Try-it Pad or the Mystery Lab) end with "In the
  real world: ...", linking the symmetry to a molecule, a mineral or a pattern; the sources are in
  [docs/TEACHERS.md](docs/TEACHERS.md). At the start only one window is open at a time: the
  pre-test comes first (if it is due), and guides wait until it is finished.
- **Symmetry markers.** Particles mark the symmetry elements with the symbols of International
  Tables, so they do not rely on colour alone: 2-fold axes as lenses (yellow), 3-fold as triangles
  (green; with a ring for -3), 4-fold as squares (red), -4 as a square with a lens (purple), mirror
  planes as sheets of light blue dots, inversion centres as a white disc. Lattice worlds show the
  unit cells in orange and a floor whose tint alternates cell by cell.
- **Stereogram.** A stereogram in the corner shows the world's point group as International Tables
  draws it: copies of one direction as dots (above) and rings (below), axis symbols and mirror lines.
- **Quiz window.** It sits at the bottom of the screen so the scene stays visible; questions about
  a Gate display turn the player towards it. A wrong option is greyed out and a hint is shown.
- **"Next: ..."** above the hotbar says what to do next, worked out from the player's tier and
  answered questions.
- **Sounds** play when a copy is made, for right and wrong answers, at doors and at portals, and
  softly for footsteps, jumps and placing or removing blocks. It stays daytime, so colours and
  symbols stay readable. Both can be turned off in the settings (`crystalminer.sounds`,
  `crystalminer.always_day`).

### Ways of learning

These follow what research says helps students with symmetry and crystallography: predicting
before seeing, doing the operations by hand rather than watching them, and moving between 3D models
and the 2D diagrams of textbooks. Screw axes and glide planes, which students find hardest (Graw &
Stalke, *J. Appl. Cryst.* 55, 144–148, 2022), get the most help.

- **Predict, then see.** The first block a player places in each world waits for a prediction: how
  many blocks will there be? The count comes from the engine for that exact spot, so a block on a
  symmetry element (fewer copies) is explained correctly. Teachers see the predictions.
- **Slow motion.** `/step` makes copies appear one at a time, each named ("three quarters of a turn
  (270 degrees, anticlockwise seen from above) about the vertical axis", "a screw: ...").
- **By hand.** `/byhand` turns the copying off: the student places every copy and each one is
  checked; `/byhand hint` shows one that is missing.
- **Clue crystals.** A scavenger hunt in Gallery 3: punch a gold clue crystal to answer a question
  about its model.
- **The visitor tour.** `/tour` is a ten-minute guided route for open days and museums, with a short
  panel at each stop; visitors may build at the stops whatever their tier.

### Commands

**Everyone**

| Command | What it does |
|---|---|
| `/guide` | List what you can do |
| `/explain` | Show the guide for this place again |
| `/quiz` | Answer questions to unlock the next tier (where you have none left, a review question that does not change your tier) |
| `/progress` | Show your tier |
| `/regions`, `/goto <region>`, `/spawn` | List the worlds, travel to one, go back to the foyer |
| `/elements <all\|axes\|mirrors\|centres\|cells\|none>` | Choose which symmetry markers to show |
| `/stereogram on\|off` | Show or hide the stereogram |
| `/hint [on\|off]` | Show or hide the "Next:" line |
| `/predict [on\|off]` | Predict again in this world, or turn predictions on or off |
| `/step [on\|off]` | Copies appear one at a time, each named |
| `/byhand [hint\|off]` | Place the copies yourself and have each one checked |
| `/hunt` | Show which clue crystals you have solved |
| `/tour [next\|back\|end]` | The ten-minute guided tour |
| `/pretest`, `/posttest` | The short test before and after playing |
| `/whatsymmetry` | Work out the exact symmetry of your build |
| `/symmetry <description or symbol>` | Give the Free Lab a symmetry, e.g. `/symmetry 4mm` |
| `/challenge`, `/clearlab` | A build challenge for the Free Lab; empty the Free Lab |
| `/ask [question]` | Chat with Prism, the AI tutor (see [The AI tutor](#the-ai-tutor)) |

**Teachers** (the `teacher` privilege; automatic in single player; grant it with
`/grant <name> teacher`)

| Command | What it does |
|---|---|
| `/class` | Every student's tier, scores and predictions |
| `/settier <tier> [player]` | Set a player's tier |
| `/exportdata` | Save answers, predictions and discoveries, without names, as CSV files in the world folder |
| `/showcase [region \| clear]` | Fill the worlds with example builds, or empty them again |

**For a demonstration**, `/showcase` fills 20 worlds with example builds: a butterfly in Mirror
Plaza, a windmill in the Fourfold Tower, a 48-fold star in the Kaleidoscope, a spiral staircase in
the Screw Hall, tiled floors in the Pattern Garden and more. Only one seed piece is placed in each;
the world's symmetry makes every copy, so what visitors see is the engine at work.
`/showcase clear` empties those worlds again (including anything built there since).

## For teachers

[docs/TEACHERS.md](docs/TEACHERS.md) is a guide for running crystalminer in a class: what each tier
teaches, a 45-minute lesson, the commands you need, hosting, the pre- and post-test, known
limitations and the sources of the real-world examples.

**The pre- and post-test.** New players are offered 11 short questions before they start, and the
same ones again when they reach the top tier (`/pretest`, `/posttest`; setting
`crystalminer.pretest`). Each question has an "I don't know" option. Answers are stored with an
anonymous id. `/class` shows each student's scores and the class's mean normalized gain;
`/exportdata` saves the answers, predictions and discoveries as CSV files without names.

**Ethics.** If you publish such data as research, you need your institution's ethics approval and
informed consent; the notice in the game is not a substitute.

## The AI tutor

**Prism** is the museum's AI tutor: a smiling crystal floating above a screen on the information desk in Visitor information, just east of the foyer where everyone starts. Right-click the screen (or Prism), type `/ask` anywhere, or press the **Ask Prism** button on the progress board (**I**) to open the chat window:

- a conversation in bubbles, which Prism remembers (the last six questions and answers go to the model with each new one) until **New chat**;
- three suggested questions for the player's tier (the first about the world they are in), a box to type in (Enter sends), and the player's tier and place, which Prism uses to pitch its answer;
- "Prism is thinking..." while an answer is on its way; if the window was closed meanwhile, a line in the chat says the answer is waiting.

**Prism's billboard.** A 12 × 7 pixel screen high on the wall of Visitor information above Prism's desk shows the latest question anyone asked Prism and Prism's answer, typed out line by line in an LED-style pixel font, with Prism's **bold** words in amber. It never shows who asked. An answer stays up for five minutes; in between, the screen shows a welcome and the words to know, one every 20 seconds. Right-clicking the billboard opens the chat window too.

`/ask <question>` opens the window and asks straight away. `/symmetry` turns a description such as "a fourfold axis with mirrors" into a point group. The tutor runs on DeepSeek, on Claude, or on any OpenAI-compatible model, including free open-source models on your own computer.

**Setup** (Luanti **Settings**, show advanced settings):

1. Set **Mods → HTTP mods** (`secure.http_mods`) to `crystalminer`.
2. Give the model's provider its API key, in the environment variable LiteLLM uses for it (see below) or in **Tutor: API key**. The default model is DeepSeek's, so `DEEPSEEK_API_KEY` is all it needs.
3. To use another model, set **Tutor: model** under **Content: Games → crystalminer**, or the environment variable `CRYSTALMINER_TUTOR_MODEL`.

**Choosing the model.** Models are named as in [LiteLLM](https://docs.litellm.ai/docs/providers), `provider/model`, and each provider's key is read from the variable LiteLLM reads:

| Model | Provider | Key |
|---|---|---|
| `deepseek/deepseek-flash` (default), `deepseek/deepseek-v4-pro` | DeepSeek | `DEEPSEEK_API_KEY` |
| `anthropic/claude-opus-5-5` | Claude (Messages API) | `ANTHROPIC_API_KEY` or **Tutor: Anthropic API key** |
| `openai/<model>` | OpenAI | `OPENAI_API_KEY` |
| `gemini/<model>` | Google Gemini | `GEMINI_API_KEY` |
| `groq/`, `mistral/`, `xai/`, `cerebras/`, `perplexity/` `<model>` | Groq, Mistral, xAI, Cerebras, Perplexity | `GROQ_API_KEY`, `MISTRAL_API_KEY`, `XAI_API_KEY`, `CEREBRAS_API_KEY`, `PERPLEXITYAI_API_KEY` |
| `openrouter/<org>/<model>`, `together_ai/<org>/<model>`, `fireworks_ai/<model>` | OpenRouter, Together AI, Fireworks AI | `OPENROUTER_API_KEY`, `TOGETHERAI_API_KEY`, `FIREWORKS_AI_API_KEY` |
| `ollama/llama3.2`, `lm_studio/<model>`, `hosted_vllm/<model>` | A server on this computer or network | none; the address from `OLLAMA_API_BASE`, `LM_STUDIO_API_BASE`, `HOSTED_VLLM_API_BASE` or **Tutor: base URL** |
| `litellm_proxy/<model>` | Any model a [LiteLLM proxy](https://docs.litellm.ai/docs/simple_proxy) serves: Bedrock, Vertex AI, Azure and the rest | `LITELLM_PROXY_API_KEY`, at `LITELLM_PROXY_API_BASE` (default `http://localhost:4000`) |

Luanti runs only Lua, so the game cannot use LiteLLM itself: it talks to Claude through the Messages API and to every other provider through its OpenAI-compatible Chat Completions API, and reaches anything else through a LiteLLM proxy. **Tutor: provider** `openai_compatible` with **Tutor: base URL** still connects to any other OpenAI-style server, sending the model's name exactly as written. For a free local model, install [Ollama](https://ollama.com), run `ollama pull llama3.2`, and set the model to `ollama/llama3.2`.

**Keeping keys in a `.env` file** (Windows): copy [.env.example](.env.example) to a file named `.env` in the game folder or the folder above it, fill in the key for your provider (and `CRYSTALMINER_TUTOR_MODEL` to change the model), and start Luanti with `tools/luanti_with_env.cmd`. It passes the file's variables to Luanti only, so no key is written into Luanti's settings. The repository ignores `.env` files. On macOS or Linux, `export DEEPSEEK_API_KEY=...` (and so on) before starting Luanti does the same.

A player can ask a question every 20 seconds with Claude (it is paid per request) and every 5 with the other providers; at most three questions wait for an answer at once across the server.

**Keeping it accurate.** The tutor answers only from the reviewed lesson text in
`mods/crystalminer/content.lua` (Prism's chat also has the texts of Galleries 2 and 3, the history
panels and the crystal structures). It does not give away quiz answers or the Mystery Lab's
symmetry. For `/symmetry` it only picks a symbol; the game's symmetry engine
checks the symbol, builds the group and states every fact about it. Anything the model writes is
labelled "Tutor:" or "Tutor's note (may be wrong)", and Prism's window says under every
conversation that it can be wrong. Typing a symbol directly (`/symmetry 4mm`) works without the
tutor.

**Tested.** The open-model path was run on a Luanti server with Qwen2.5-1.5B-Instruct
(llama.cpp): both commands worked, with replies in 10–60 s on two CPU cores. Prism's chat was run
on Luanti 5.17 against DeepSeek's API (`deepseek-flash`): a question and a follow-up that built on
it, each answered in a few seconds. The other providers' settings (addresses, key variables, model names) are unit-tested but have not been run against their live APIs; neither has the Claude path.

## Development

### Requirements

- `luajit` (or `lua5.1`) for the unit tests. The symmetry engine is pure Lua with no Luanti calls.
- A Luanti server binary (`luantiserver`, or `minetestserver` for older versions) for the
  in-server self-test.
- Only to regenerate assets with the scripts in `tools/`: Python 3 with Pillow (figures, glyphs,
  furniture, menu art, Prism's art in `make_tutor_art.py`, the billboard's pixel font in `make_pixel_font.py`; `make_textures.py` needs only the
  standard library), NumPy and either the
  `soundfile` module or `ffmpeg` with libvorbis (sounds), and `luajit` for `tools/figure_data.lua`.

### Running the tests

```bash
tests/run_all.sh [path-to-luanti-binary]
```

This runs the unit tests (it skips them if no Lua is installed), then starts a real server with
`crystalminer.selftest = true`. The unit tests are:

| File | Checks |
|---|---|
| `test_symmetry.lua` | The engine: operations, groups, the point and plane groups |
| `test_science.lua` | The science statements listed above |
| `test_content.lua` | Every region's symmetry, quiz answers and group orders; regions do not overlap |
| `test_elements.lua` | Where symmetry markers are drawn |
| `test_decor.lua` | Architecture stays out of the build spaces; worlds do not touch |
| `test_showcase.lua` | The `/showcase` builds have their world's symmetry |
| `test_assess.lua` | Pre- and post-test items, normalized gain, anonymous export |
| `test_museum.lua` | The crystal models, clue answers and stereograms |
| `test_signs.lua` | The text of every sign fits it and has glyphs |
| `test_guides.lua` | Every guide's numbers match the engine |
| `test_next_hint.lua` | The "Next:" line |
| `test_billboard.lua` | The billboard's lines, typing, overflow and texture size; every glyph exists |
| `test_lessons.lua` | Review questions for `/quiz`: none above the player's tier, cycling |
| `test_tutor.lua` | Tutor request building and response handling, the DeepSeek preset, chat history |

The self-test (`mods/crystalminer/selftest.lua`) places and digs blocks through the registered
callbacks and runs about 95 checks: locking, quizzes, saving, the Gate, the Try-it Pad, the floor
tilings, the architecture, predictions, step mode, the museum and its clues, the teleporters, the
tour, the data export, the teacher view, the Free Lab, the museum's signs, doors and doorways, the
Portal Hall and every world's plaza, arch and portal back, Prism's desk and chat, the symmetry markers and the order of the
pre-test and guide windows. Then it shuts the server down.

GitHub Actions runs the unit tests and the self-test on Ubuntu 22.04 (Minetest 5.4.1) and Ubuntu
24.04 (Minetest 5.6.1).

### Project layout

```
game.conf                     Luanti game definition
settingtypes.txt              the game's settings (shown in Luanti's main menu)
mods/crystalminer/
  init.lua                    blocks, world, events, quizzes, progress board, commands
  symmetry.lua                engine: operations, groups, 32 point groups, 17 plane groups, regions, detection
  gate.lua                    geometry of the Symmetry Gate displays
  decor.lua                   architecture of each region and the landscape of its world
  lobby.lua                   the museum building: rooms, doors, signs, Portal Hall
  worlds.lua                  each world's arrival plaza, boards, arch and portal back
  signs.lua, doors.lua        signs lettered in DejaVu Sans (glyph widths in sign_metrics.lua),
                              and framed pictures; doors
  guides.lua, guide_window.lua  plain-language guides, and the window that shows them
  next_hint.lua               the "Next:" line above the hotbar and /hint
  sounds.lua                  sound effects and node sounds (files in sounds/)
  furniture.lua, sculptures.lua  carpets, benches, plants, desk, plan; the sculptures
  lessons.lua                 tiers, questions, explanations, progress
  learning.lua, assess.lua    pre- and post-test, predictions, class view, data export
  modes.lua                   /step and /byhand
  museum.lua, structures.lua  the Crystal Museum, clue crystals, teleport pads; crystal structure models
  stereo.lua                  the stereogram (International Tables style)
  tour.lua                    the visitor tour
  elements.lua                where to draw axes, mirror planes and centres
  tutor.lua                   AI tutor requests (Claude, DeepSeek or OpenAI-compatible, raw HTTP)
  tutor_window.lua            Prism: the chat window, each player's conversation, the desk
  billboard.lua               Prism's pixel billboard (its font: pixel_font.lua)
  content.lua                 all text players read; edit without touching code
  selftest.lua                in-server checks
  sounds/                     Ogg sound effects
  optional_sounds/            the jump sound, sent to players only when sounds are on
  textures/                   generated textures, glyphs and figures
tests/                        unit tests and test runners
docs/TEACHERS.md              a guide for teachers
docs/images/                  screenshots for this README
menu/                         main-menu icon and header image
tools/                        generators (see below)
```

**Coordinates.** Crystal axes (z up) map to the world as x → east, y → north, z → up.

### Settings

All are in [settingtypes.txt](settingtypes.txt) at the top of the game, so Luanti's main menu shows
them under **Settings → Content: Games → crystalminer**: the tutor settings,
`crystalminer.selftest` (default off), `crystalminer.pretest`, `crystalminer.always_day` and
`crystalminer.sounds` (all three on by default).

## Credits and acknowledgements

- [Luanti](https://www.luanti.org), the free and open-source game engine crystalminer runs on.
- MolCraft (University of Hull, 2015), a Minecraft world of molecules with a central hall of
  teleporters, giant models and hidden quiz chests. The Crystal Museum, the clue crystals and the
  separate world for each region reached through the Portal Hall come from its ideas.
- Graw & Stalke, *J. Appl. Cryst.* 55, 144–148 (2022), on the topics students find hardest.
- International Tables for Crystallography, Vol. A, for point-group orders, plane-group
  multiplicities and symbols.
- [DejaVu fonts](https://dejavu-fonts.github.io/) for the lettering on signs and in figures.
- The [Materials Project](https://materialsproject.org) and its MPContribs platform for the crystal
  structures in the live exhibits (CC BY 4.0; see [LICENSE.media](LICENSE.media)), and the Jmol
  element colours (values from ASE's `jmol_colors`).
- Contributors: [@lvtamayo](https://github.com/lvtamayo) for the live
  crystal exhibits, and Davis Magpantay ([@Dexva](https://github.com/Dexva)) for the museum NPCs.
- [Anthropic](https://www.anthropic.com)'s Claude models. Much of the code, texts, figures and
  tests were written with Claude Opus 5.5 and Claude Sonnet 5.5 through Claude Code, under the
  author's direction and review. The in-game tutor calls Claude Opus 5.5 through the Claude API.

## Licence

- Code: GNU LGPL 2.1 or later ([LICENSE](LICENSE)).
- Textures, pictures, sounds, menu images and texts: CC BY-SA 4.0 ([LICENSE.media](LICENSE.media)).
- Sign lettering is rendered from DejaVu fonts ([LICENSE.fonts](LICENSE.fonts)).
- Crystal structures for the exhibits (`data/mpcontribs/` and the data generated from it): Materials
  Project MPContribs data, CC BY 4.0, credited in [LICENSE.media](LICENSE.media).

Copyright (c) 2026 Viejay Ordillo and contributors.

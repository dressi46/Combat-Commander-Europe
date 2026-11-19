# Combat Commander: Europe

[Español](README.md) · **English**

A digital adaptation of GMT Games’ tactical board game, built with Godot 4.6.3. A fan project for personal use.

## Play in a browser

On Ubuntu, open a terminal in the **Linux release package** directory containing the launcher and run:

```sh
./iniciar-local.sh
```

Keep the terminal open and visit [the local game](http://localhost:8781/) in Brave. You can also open [the mission and card workshop](http://localhost:8781/workshop/?lang=en) on the same computer. On another device, use the HTTPS address of your hosted game. [Server and lobby guide in Spanish](online/README.md).

## Main menu

- **Single player** lets you play against the AI or watch a demonstration.
- **Multiplayer** supports two players on one device and public or private online rooms. Each player can choose their own language.
- **Mission and card workshop** lets you edit and generate scenarios, attach documents and play custom missions against the AI. Import card illustrations by language, deck and card number. For PDF sheets, choose a page and grid cell. Your browser stores the files on your device.
- **Settings** saves your language, action playback speed and sound effects volume. Slow playback gives you more time to read the action log.

## Open or export the project

Open [godot/project.godot](godot/project.godot) in Godot 4.6.3 and press **F5** to play. To build the browser version, install the matching Godot export templates and run these commands from the repository root:

```sh
mkdir -p godot/build
godot --headless --path godot --import
godot --headless --path godot --export-release Web build/index.html
python3 online/prepare-workshop.py godot/build
python3 -m http.server 8781 --bind 127.0.0.1 --directory godot/build
```

Open [localhost:8781](http://localhost:8781/). The last command serves the game and workshop. For online matches, also start the Godot lobby server with `PORT=8791` when testing on this web port. [Lobby instructions in Spanish](online/README.md).

## Translate the game

Spanish, English and Italian are available under **Settings → Language**. Choose **Add a language**, enter a name and select a starting language. Creating it opens **Quick translation**, where you can also search for workshop phrases. Each browser or installation keeps its own languages and edits. Online match messages sent by the server use the starting language.

In **Settings → Quick translation**, search for a phrase in English or the active language, edit it, or restore the original wording. Changes are saved on this device for the selected language.

Copy `godot/assets/i18n/en.json`, name the copy after the new language code and register it in the adjacent `languages.json`. Translate the values and preserve keys, placeholders such as `%s` and `%d`, and formatting tags. Missing entries fall back to English. The workshop has its own catalogs in `online/workshop/`.

To bundle card art, use paths such as `godot/assets/cards_es/german/01.webp`. Godot imports the image when you open the project. When an illustration is missing, the game renders the card from its deck data.

## Repository layout

| Directory | Contents |
|---|---|
| `godot/engine/` | Decision engine (`Flow.gd`), AI (`Bot.gd`), game coordinator (`Game.gd`) and rules for combat, terrain, events and objectives. The AI chooses from the same legal moves as a human player. |
| `godot/assets/` | 24 maps, six 72-card decks, scenarios, unit fronts and backs, translations and the Black Ops One and Barlow Condensed fonts (OFL). |
| `godot/scenes/` | Menus, 2D and 3D maps, hand, help and action log. The visual theme is in `godot/engine/Tema.gd`. |
| `online/` | Web workshop, local launcher and lobby hosting files. |
| `docs/` | [Project status](docs/STATO.md), audits and [historical archive](docs/archivio/), including v0.48 code and graphic experiments. |

## Checks and publishing

From the repository root, run:

```sh
godot --headless --path godot --import
godot --headless --path godot res://tests/RulesCheck.tscn
godot --headless --path godot res://tests/SelfPlay.tscn -- all 1
godot --path godot --resolution 1024x768 res://tests/UiTour.tscn -- /tmp/cc-ui 2 160
python3 tools/controlla_glifi.py
```

These checks cover rules, AI games on all scenarios, screenshots of decisions and font coverage. To publish to GitHub Pages, run `deploy.yml` manually or include `[pubblica]` in a commit message on `main`. [Original project's web edition](https://tannoiser2.github.io/Combat-Commander-Europe/).

*Combat Commander: Europe* is © GMT Games. Original materials belong to their respective rights holders.
